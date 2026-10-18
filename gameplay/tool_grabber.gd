class_name ToolGrabber
extends Node
## Hold-to-grab and drag for the tools on a tray.
##
## Hold a tool for hold_seconds to pick it up: it lifts toward the camera
## (so it looks bigger), glows, and passes through everything while dragged.
## On release:
## - over tray_zone: lowered onto the pile and dropped with physics.
## - over hand_off_zone: tool_handed is emitted, and the listener decides.
## - anywhere else: flown back to a random spot in the tray, and the pile
##   gets a small nudge.
## Works with mouse and touch (Godot turns single touches into mouse events).

signal tool_grabbed(tool: SurgicalTool)
## The listener must either free the tool or call return_to_tray() on it.
## Until then it stays frozen where it was let go.
signal tool_handed(tool: SurgicalTool)

## Instruments' enlarged grab areas (see assets/instruments/README.md).
const PICK_LAYER := 1 << 7
const DROP_ZONE_LAYER := 1 << 8
const RAY_LENGTH := 100.0

@export var camera: Camera3D
## Only direct children of this node can be grabbed.
@export var tools_root: Node3D
## Drop zones are Area3Ds on the drop_zones layer with a flat box shape lying
## on the surface. Tall boxes would catch the camera's slanted ray early and
## steal drops meant for a zone behind them.
## Tray zone: its box covers the tray, with its bottom at the tray floor.
@export var tray_zone: Area3D
## Where tools are handed over.
@export var hand_off_zone: Area3D

@export var hold_seconds := 0.3
## A press that moves further than this before hold_seconds is not a grab.
@export var hold_slop_pixels := 24.0
@export var glow_color := Color(0.7, 1.0, 0.2):
	set(value):
		glow_color = value
		_glow.set_shader_parameter("glow_color", value)
## Height above tools_root the held tool floats at. Higher is closer to the camera.
@export var lift_height := 0.25
## The held tool sits this far above the finger on screen, so the finger doesn't hide it.
@export var finger_offset_pixels := 90.0
## How quickly the held tool catches up with the finger.
@export var follow_sharpness := 20.0
## Height above the tray floor that dropped and returned tools are let go from.
@export var drop_height := 0.06
@export var return_seconds := 0.35
## Speed (m/s) of the random nudge every tray tool gets when a tool is returned.
@export var jumble_speed := 0.08

var _glow := ShaderMaterial.new()
var _pointer := Vector2.ZERO
var _press_position := Vector2.ZERO
var _press_time := 0.0
var _candidate: SurgicalTool
var _held: SurgicalTool
## Tools mid-flight back to the tray. They can't be grabbed until they land.
var _flying: Dictionary[SurgicalTool, bool] = {}
## Collision layer and mask of each tool made intangible, to restore on drop.
var _saved_layers: Dictionary[SurgicalTool, Vector2i] = {}


func _init() -> void:
	_glow.shader = preload("res://gameplay/held_glow.gdshader")


func _ready() -> void:
	_glow.set_shader_parameter("glow_color", glow_color)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = event.position
		if event.pressed:
			_candidate = _tool_at(event.position)
			_press_position = event.position
			_press_time = 0.0
		elif _held:
			_release()
		else:
			_candidate = null
	elif event is InputEventMouseMotion:
		_pointer = event.position
		if _candidate and _pointer.distance_to(_press_position) > hold_slop_pixels:
			_candidate = null


func _process(delta: float) -> void:
	if _candidate:
		_press_time += delta
		if _press_time >= hold_seconds:
			_grab(_candidate)
			_candidate = null
	if _held:
		var target := _held_position()
		var weight := 1.0 - exp(-follow_sharpness * delta)
		_held.global_position = _held.global_position.lerp(target, weight)


## Flies a tool back to a random spot in the tray, then nudges the pile.
func return_to_tray(tool: SurgicalTool) -> void:
	_make_intangible(tool)
	_set_glow(tool, false)
	_flying[tool] = true
	var spot := _random_tray_spot()
	var flat_rotation := Vector3(0.0, randf() * TAU, 0.0)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(tool, "global_position", spot, return_seconds)
	tween.tween_property(tool, "global_rotation", flat_rotation, return_seconds)
	tween.chain().tween_callback(func() -> void:
		_flying.erase(tool)
		_drop(tool)
		_jumble())


func _grab(tool: SurgicalTool) -> void:
	_held = tool
	_make_intangible(tool)
	_set_glow(tool, true)
	# Tools resting on this one shouldn't hang in the air once it's gone.
	for other in _tools():
		other.sleeping = false
	tool_grabbed.emit(tool)


func _release() -> void:
	var tool := _held
	_held = null
	var zone := _zone_under(tool)
	if zone == hand_off_zone:
		_set_glow(tool, false)
		tool_handed.emit(tool)
	elif zone == tray_zone:
		_set_glow(tool, false)
		var spot := tool.global_position
		spot.y = _tray_floor_y() + drop_height
		_flying[tool] = true
		var tween := create_tween()
		tween.tween_property(tool, "global_position", spot, 0.1)
		tween.tween_callback(func() -> void:
			_flying.erase(tool)
			_drop(tool))
	else:
		return_to_tray(tool)


func _make_intangible(tool: SurgicalTool) -> void:
	if not _saved_layers.has(tool):
		_saved_layers[tool] = Vector2i(tool.collision_layer, tool.collision_mask)
	tool.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	tool.freeze = true
	tool.collision_layer = 0
	tool.collision_mask = 0


func _drop(tool: SurgicalTool) -> void:
	var layers: Vector2i = _saved_layers.get(tool, Vector2i(tool.collision_layer, tool.collision_mask))
	_saved_layers.erase(tool)
	tool.collision_layer = layers.x
	tool.collision_mask = layers.y
	tool.freeze = false
	tool.linear_velocity = Vector3.ZERO
	tool.angular_velocity = Vector3.ZERO


func _jumble() -> void:
	for tool in _tools():
		if tool.freeze:
			continue
		var direction := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
		tool.apply_central_impulse(direction * jumble_speed * tool.mass)


func _set_glow(tool: SurgicalTool, on: bool) -> void:
	for node in tool.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_overlay = _glow if on else null


## Where the held tool should be: under the pointer (minus the finger offset),
## on the plane lift_height above the tools.
func _held_position() -> Vector3:
	var screen := _pointer - Vector2(0.0, finger_offset_pixels)
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var plane := Plane(Vector3.UP, tools_root.global_position.y + lift_height)
	var hit: Variant = plane.intersects_ray(origin, direction)
	return hit if hit != null else _held.global_position


## The grabbable tool under a screen position, or null.
func _tool_at(screen: Vector2) -> SurgicalTool:
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * RAY_LENGTH)
	# Bodies too, so tools without grab areas can still be picked.
	query.collision_mask = PICK_LAYER | 1
	query.collide_with_areas = true
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var node: Node = hit.get("collider")
	while node and node.get_parent() != tools_root:
		node = node.get_parent()
	var tool := node as SurgicalTool
	if tool == null or _flying.has(tool):
		return null
	return tool


## The drop zone the tool is over, as seen from the camera, or null.
func _zone_under(tool: SurgicalTool) -> Area3D:
	var origin := camera.global_position
	var direction := origin.direction_to(tool.global_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, DROP_ZONE_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Area3D


func _random_tray_spot() -> Vector3:
	var box := _tray_box()
	var half := box.size * 0.5 * 0.8
	var local := Vector3(randf_range(-half.x, half.x), 0.0, randf_range(-half.z, half.z))
	var spot := tray_zone.global_transform * (_tray_shape().position + local)
	spot.y = _tray_floor_y() + drop_height
	return spot


func _tray_floor_y() -> float:
	var shape := _tray_shape()
	return (shape.global_transform * Vector3(0.0, -_tray_box().size.y * 0.5, 0.0)).y


func _tray_shape() -> CollisionShape3D:
	return tray_zone.find_children("*", "CollisionShape3D", false, false)[0]


func _tray_box() -> BoxShape3D:
	return _tray_shape().shape as BoxShape3D


func _tools() -> Array[SurgicalTool]:
	var tools: Array[SurgicalTool] = []
	for child in tools_root.get_children():
		if child is SurgicalTool and not child.is_queued_for_deletion():
			tools.append(child)
	return tools
