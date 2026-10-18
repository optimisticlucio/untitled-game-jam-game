class_name ToolGrabber
extends Node
## Hold-to-grab and drag for the tools on a tray.
##
## Hold a tool for hold_seconds to pick it up: it lifts toward the camera
## (so it looks bigger), glows, and passes through everything while dragged.
## On release:
## (Where it's released is judged by the pointer, not the tool, since the tool
## floats above a finger.)
## - over the tray's zone: lowered onto the pile and dropped with physics.
## - over hand_off_zone: tool_handed is emitted, and the listener decides.
## - anywhere else: flown back to a random spot in the tray, and the pile
##   gets a small nudge.
## Works with mouse and touch (Godot turns single touches into mouse events).
## It also owns every glow on the tools, including hint() glows, so they
## never fight over a tool's overlay material.

signal tool_grabbed(tool: SurgicalTool)
## Emitted whenever a held tool is let go, wherever it lands (before tool_handed).
signal tool_released(tool: SurgicalTool)
## The listener must call consume() or return_to_tray() on the tool.
## Until then it stays frozen where it was let go.
signal tool_handed(tool: SurgicalTool)

## Instruments' enlarged grab areas (see dev/instruments/README.md).
const PICK_LAYER := 1 << 7
const DROP_ZONE_LAYER := 1 << 8
const RAY_LENGTH := 100.0

@export var camera: Camera3D
## Only the tray's tools can be grabbed. Its zone is where drops land.
@export var tray: Tray
## Drop zones (the tray's and this one) are Area3Ds on the drop_zones layer
## with flat shapes lying on the surface. Tall shapes would catch the camera's
## slanted ray early and steal drops meant for a zone behind them.
## Where tools are handed over. Consumed tools land at the height of its box's
## centre, so centre the box on the surface they should land on.
@export var hand_off_zone: Area3D

@export var hold_seconds := 0.15
## A press that moves further than this before hold_seconds is not a grab.
@export var hold_slop_pixels := 24.0
@export var glow_color := Color(0.7, 1.0, 0.2):
	set(value):
		glow_color = value
		_glow.set_shader_parameter("glow_color", value)
## Glow of tools marked with hint().
@export var hint_color := Color(0.3, 0.8, 1.0):
	set(value):
		hint_color = value
		_hint_glow.set_shader_parameter("glow_color", value)
## Height above the tray's tools the held tool floats at. Higher is closer to the camera.
@export var lift_height := 0.2
## On touch screens the held tool sits this far above the finger, so the finger
## doesn't hide it. Mice get no offset.
@export var finger_offset_pixels := 90.0
## How quickly the held tool catches up with the finger.
@export var follow_sharpness := 16.0
## Height above the tray floor that dropped and returned tools are let go from.
@export var drop_height := 0.06
@export var return_seconds := 0.35
## Speed (m/s) of the random nudge every tray tool gets when a tool is returned.
@export var jumble_speed := 0.25
## How long a consumed tool takes to drop onto the hand-off zone, then to shrink away.
@export var consume_drop_seconds := 0.3
@export var consume_shrink_seconds := 0.2

## When false, presses are ignored and a held tool is let go where it is,
## frozen and intangible. Only for when the tray's tools are about to be
## cleared (reshuffle, level end): a tool let go this way is never dropped.
var enabled := true:
	set(value):
		enabled = value
		if not value:
			_candidate = null
			if _held:
				_set_glow(_held, false)
				_held = null

var _glow := ShaderMaterial.new()
var _hint_glow := ShaderMaterial.new()
var _hinted: Dictionary[SurgicalTool, bool] = {}
var _pointer := Vector2.ZERO
var _press_position := Vector2.ZERO
var _press_time := 0.0
## Whether the current press came from a finger (Godot reports those as emulated mouse events).
var _is_touch := false
var _candidate: SurgicalTool
var _held: SurgicalTool
## Tools mid-flight back to the tray. They can't be grabbed until they land.
var _flying: Dictionary[SurgicalTool, bool] = {}
## Collision layer and mask of each tool made intangible, to restore on drop.
var _saved_layers: Dictionary[SurgicalTool, Vector2i] = {}


func _init() -> void:
	_glow.shader = preload("res://gameplay/held_glow.gdshader")
	_hint_glow.shader = _glow.shader


func _ready() -> void:
	_glow.set_shader_parameter("glow_color", glow_color)
	_hint_glow.set_shader_parameter("glow_color", hint_color)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = event.position
		if event.pressed:
			_is_touch = event.device == InputEvent.DEVICE_ID_EMULATION
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


## Drops a handed-over tool onto the middle of the hand-off zone, shrinks it
## away and frees it. Await the returned signal to act once it's gone.
func consume(tool: SurgicalTool) -> Signal:
	_make_intangible(tool)
	_flying[tool] = true
	var landing := hand_off_zone.global_transform * _first_shape(hand_off_zone).position
	var flat_rotation := Vector3(0.0, tool.global_rotation.y, 0.0)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(tool, "global_position", landing, consume_drop_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(tool, "global_rotation", flat_rotation, consume_drop_seconds)
	tween.chain()
	# Shrink the visuals, not the body: physics bodies don't scale well.
	for child in tool.get_children():
		if child is Node3D and not child is CollisionShape3D:
			tween.tween_property(child, "scale", Vector3.ONE * 0.001, consume_shrink_seconds) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		_flying.erase(tool)
		_saved_layers.erase(tool)
		tool.queue_free())
	return tween.finished


## Flies a tool back to a random spot in the tray, then nudges the pile.
func return_to_tray(tool: SurgicalTool) -> void:
	_make_intangible(tool)
	_set_glow(tool, false)
	_flying[tool] = true
	var spot := tray.random_point() + Vector3.UP * drop_height
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
	for other in tray.tools():
		other.sleeping = false
	tool_grabbed.emit(tool)


func _release() -> void:
	var tool := _held
	_held = null
	tool_released.emit(tool)
	var zone := _zone_under(_pointer)
	if zone == hand_off_zone:
		_set_glow(tool, false)
		tool_handed.emit(tool)
	elif zone == tray.zone:
		_set_glow(tool, false)
		var spot := tool.global_position
		spot.y = tray.floor_height(spot) + drop_height
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
	for tool in tray.tools():
		if tool.freeze:
			continue
		var direction := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
		tool.apply_central_impulse(direction * jumble_speed * tool.mass)


## True while a tool is held, pressed and about to be, or still moving into
## place (flying back, dropping, being consumed).
func is_busy() -> bool:
	return _held != null or _candidate != null or not _flying.is_empty()


## Makes the tool glow in hint_color until clear_hints(). Holding it shows
## the held glow instead; letting go brings the hint back.
func hint(tool: SurgicalTool) -> void:
	_hinted[tool] = true
	if tool != _held:
		_set_glow(tool, false)


func clear_hints() -> void:
	var hinted := _hinted.keys()
	_hinted.clear()
	for tool in hinted:
		if is_instance_valid(tool) and tool != _held:
			_set_glow(tool, false)


## Turns the held glow on, or back to the tool's resting look (its hint glow, if any).
func _set_glow(tool: SurgicalTool, on: bool) -> void:
	var material: Material = null
	if on:
		material = _glow
	elif _hinted.has(tool):
		material = _hint_glow
	for node in tool.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_overlay = material


## Where the held tool should be: under the pointer (minus the finger offset),
## on the plane lift_height above the tools.
func _held_position() -> Vector3:
	var offset := finger_offset_pixels if _is_touch else 0.0
	var screen := _pointer - Vector2(0.0, offset)
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var plane := Plane(Vector3.UP, tray.tools_root.global_position.y + lift_height)
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
	while node and node.get_parent() != tray.tools_root:
		node = node.get_parent()
	var tool := node as SurgicalTool
	if tool == null or _flying.has(tool):
		return null
	return tool


## The drop zone under a screen position, or null.
func _zone_under(screen: Vector2) -> Area3D:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, DROP_ZONE_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Area3D


func _first_shape(zone: Area3D) -> CollisionShape3D:
	return zone.find_children("*", "CollisionShape3D", false, false)[0]
