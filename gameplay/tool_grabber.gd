class_name ToolGrabber
extends Node
## Hold-to-grab and drag for the tools on a tray.
##
## Hold a tool for hold_seconds to pick it up: it lifts toward the camera
## (so it looks bigger), glows, and passes through everything while dragged.
## On release:
## (Where it's released is judged by the pointer, not the tool, since the tool
## floats above a finger.)
## - over the tray's zone: dropped with physics from where it is; the pile
##   gets a small nudge when it lands.
## - over hand_off_zone: tool_handed is emitted, and the listener decides.
## - anywhere else: flown back to the nearest spot on the tray, and the pile
##   gets a small nudge.
## Works with mouse and touch (Godot turns single touches into mouse events).
## It also owns every highlight on the tools (held, hint() and reject()), so
## they never fight over a tool's look. A highlight is a light glow (the
## meshes' overlay material) plus an outline (a child mesh with smoothed
## normals, made the first time a mesh is highlighted).

signal tool_grabbed(tool: SurgicalTool)
## Emitted whenever a held tool is let go, wherever it lands (before tool_handed).
signal tool_released(tool: SurgicalTool)
## The listener must call consume(), reject() or return_to_tray() on the tool.
## Until then it stays frozen where it was let go.
signal tool_handed(tool: SurgicalTool)

## Instruments' enlarged grab areas (see dev/instruments/README.md).
const PICK_LAYER := 1 << 7
const DROP_ZONE_LAYER := 1 << 8
const RAY_LENGTH := 100.0
const OUTLINE_NODE := &"HighlightOutline"
const GLOW_NODE := &"HighlightGlow"

## Outline copies of each mesh, with smoothed normals, made once and shared.
static var _outline_meshes: Dictionary[Mesh, ArrayMesh] = {}

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
## Light glow on the held tool itself. Its outline is a moving rainbow neon with a soft
## glow and twinkles, after Julia's reference video: the materials held_neon_outline.tres and
## held_neon_glow.tres, plus little stars floating off it (HeldSparkles). Tune them all in
## dev/neon_preview/neon_preview.tscn.
@export var glow_color := Color(1.0, 0.99, 0.88):
	set(value):
		glow_color = value
		_glow.set_shader_parameter("glow_color", value)
## Highlight of tools marked with hint().
@export var hint_color := Color(0.3, 0.8, 1.0):
	set(value):
		hint_color = value
		_set_highlight_color(_hint_glow, value)
## Highlight of a tool handed over wrong, while it hovers before going back.
@export var reject_color := Color(1.0, 0.2, 0.15):
	set(value):
		reject_color = value
		_set_highlight_color(_reject_glow, value)
## How long a rejected tool hovers before it flies back to the tray.
@export var reject_seconds := 0.5
## Height above the tray's tools the held tool floats at. Higher is closer to the camera.
@export var lift_height := 0.25
## On touch screens the held tool sits this far above the finger, so the finger
## doesn't hide it. Mice get no offset.
@export var finger_offset_pixels := 90.0
## How quickly the held tool catches up with the finger.
@export var follow_sharpness := 12.0
## Height above the tray floor that returned tools are let go from.
@export var drop_height := 0.16
@export var return_seconds := 0.35
## Returned tools land at least this far inside the tray's edge (on top of
## their own width), so they don't catch the rim.
@export var return_margin := 0.01
## Speed (m/s) of the random nudge the other tray tools get when a dropped
## or returned tool lands.
@export var jumble_speed := 0.1
## How long a consumed tool takes to drop onto the hand-off zone, then to shrink away.
@export var consume_drop_seconds := 0.3
@export var consume_shrink_seconds := 0.2

@export_group("Sounds")
## Played when an instrument is picked up. Silly items play their own drop_sound instead.
@export var grab_sound: AudioStream = preload("res://assets/sounds/gameplay/tool_grab.wav")
## Played when a tool starts flying back to the tray.
@export var return_sound: AudioStream = preload("res://assets/sounds/gameplay/tool_return_whoosh.wav")
## Played when the surgeon takes a correct tool.
@export var receive_sound: AudioStream = preload("res://assets/sounds/gameplay/surgeon_receive.wav")

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

var _glow := _make_highlight()
var _hint_glow := _make_highlight()
var _reject_glow := _make_highlight()
var _hinted: Dictionary[SurgicalTool, bool] = {}
## Tools hovering in reject_color before they go back to the tray.
var _rejecting: Dictionary[SurgicalTool, bool] = {}
var _pointer := Vector2.ZERO
var _press_position := Vector2.ZERO
var _press_time := 0.0
## Whether the current press came from a finger (Godot reports those as emulated mouse events).
var _is_touch := false
var _candidate: SurgicalTool
var _held: SurgicalTool
## Tools mid-flight back to the tray. They can't be grabbed until they land.
var _flying: Dictionary[SurgicalTool, bool] = {}
## Where each released tool appeared to be let go: the point on the table
## under the pointer. A held tool floats near the camera, so its own position
## is far from where it looks to be. Returns aim for this point.
var _released_over: Dictionary[SurgicalTool, Vector3] = {}
## Collision layer and mask of each tool made intangible, to restore on drop.
var _saved_layers: Dictionary[SurgicalTool, Vector2i] = {}


func _ready() -> void:
	_set_highlight_color(_glow, glow_color)
	_set_highlight_color(_hint_glow, hint_color)
	_set_highlight_color(_reject_glow, reject_color)
	# The held tool: the neon outline and glow (their colours are their own), and the tool
	# keeps its own colour.
	_glow.set_meta(&"outline", preload("res://gameplay/held_neon_outline.tres"))
	_glow.set_meta(&"glow", preload("res://gameplay/held_neon_glow.tres"))
	_glow.set_shader_parameter("base_strength", 0.0)
	_glow.set_shader_parameter("rim_strength", 0.15)
	_warm_up_highlights.call_deferred()


## Draws every highlight once, invisibly, so their shaders compile while the level loads.
## Otherwise the first grab froze the game for about a quarter of a second.
func _warm_up_highlights() -> void:
	if camera == null:
		return
	var warm_up := Node3D.new()
	warm_up.position = Vector3(0.0, 0.0, -1.0)
	warm_up.scale = Vector3.ONE * 0.01
	camera.add_child(warm_up)
	for material in [
			_invisible(_glow.get_meta(&"outline"), {"width": 0.0}),
			_invisible(_glow.get_meta(&"glow"), {"strength": 0.0, "sparkle_density": 0.0}),
			_invisible(_hint_glow.get_meta(&"outline"), {"width": 0.0})]:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = QuadMesh.new()
		mesh_instance.material_override = material
		warm_up.add_child(mesh_instance)
	var overlay := MeshInstance3D.new()
	overlay.mesh = QuadMesh.new()
	overlay.material_overlay = _invisible(_glow, {"base_strength": 0.0, "rim_strength": 0.0})
	warm_up.add_child(overlay)
	var sparkles := HeldSparkles.SCENE.instantiate() as CPUParticles3D
	sparkles.material_override = _invisible(sparkles.material_override, {"brightness": 0.0})
	sparkles.emission_points = PackedVector3Array([Vector3.ZERO])
	sparkles.emission_normals = PackedVector3Array([Vector3.UP])
	warm_up.add_child(sparkles)
	# Two frames, so it's surely drawn once.
	for i in 2:
		await get_tree().process_frame
	warm_up.queue_free()


## A copy of the material with these shader parameters, to draw it without it showing.
static func _invisible(material: ShaderMaterial, parameters: Dictionary) -> ShaderMaterial:
	var copy := material.duplicate() as ShaderMaterial
	for parameter in parameters:
		copy.set_shader_parameter(parameter, parameters[parameter])
	return copy


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
	_released_over.erase(tool)
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
	tween.tween_callback(_play.bind(receive_sound))
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


## For a tool handed over wrong: it hovers where it was let go, highlighted
## in reject_color, for reject_seconds, then goes back to the tray.
func reject(tool: SurgicalTool) -> void:
	_make_intangible(tool)
	# Not grabbable while it hovers.
	_flying[tool] = true
	_rejecting[tool] = true
	_set_glow(tool, false)
	get_tree().create_timer(reject_seconds, false).timeout.connect(func() -> void:
		_rejecting.erase(tool)
		_flying.erase(tool)
		if is_instance_valid(tool):
			return_to_tray(tool))


## Flies a tool to the nearest spot on the tray where it fits (turning it
## only if that gets it closer), eases it to a stop drop_height above the
## floor, and lets it fall. The rest of the pile is nudged when it lands.
func return_to_tray(tool: SurgicalTool) -> void:
	_play(return_sound)
	_make_intangible(tool)
	_set_glow(tool, false)
	_flying[tool] = true
	var near: Vector3 = _released_over.get(tool, tool.global_position)
	_released_over.erase(tool)
	var placement := tray.nearest_placement(tool, near, tool.global_rotation.y, return_margin)
	var spot := placement.origin + Vector3.UP * drop_height
	var flat_rotation := Vector3(0.0, placement.basis.get_euler().y, 0.0)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(tool, "global_position", spot, return_seconds)
	tween.tween_property(tool, "global_rotation", flat_rotation, return_seconds)
	tween.chain().tween_callback(func() -> void:
		_flying.erase(tool)
		_drop(tool)
		_on_landing(tool))


func _grab(tool: SurgicalTool) -> void:
	_held = tool
	_make_intangible(tool)
	_set_glow(tool, true)
	# Silly items sound like themselves when picked up too (the duck squeaks); instruments clink.
	if tool.specialities.has(SurgicalTool.Speciality.SILLY):
		_play(tool.drop_sound)
	else:
		_play(grab_sound)
	# Tools resting on this one shouldn't hang in the air once it's gone.
	for other in tray.tools():
		other.sleeping = false
	tool_grabbed.emit(tool)


func _release() -> void:
	var tool := _held
	_held = null
	_released_over[tool] = _table_point_under(_pointer)
	tool_released.emit(tool)
	var zone := _zone_under(_pointer)
	if zone == hand_off_zone:
		_set_glow(tool, false)
		tool_handed.emit(tool)
	elif zone == tray.zone:
		_released_over.erase(tool)
		_set_glow(tool, false)
		_drop(tool)
		_on_landing(tool)
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


## The moment the falling tool first touches something: its drop sound plays
## and the pile is nudged.
func _on_landing(falling: SurgicalTool) -> void:
	falling.contact_monitor = true
	falling.max_contacts_reported = 1
	falling.body_entered.connect(func(_body: Node) -> void:
		falling.set_deferred("contact_monitor", false)
		_play(falling.drop_sound)
		_jumble(falling), CONNECT_ONE_SHOT)


## Plays a one-off sound effect on the SFX bus.
func _play(sound: AudioStream) -> void:
	if sound == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = sound
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Nudges every resting tool except the one that caused it.
func _jumble(except: SurgicalTool) -> void:
	for tool in tray.tools():
		if tool.freeze or tool == except:
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


## Turns the held highlight on, or back to the tool's resting look: its
## reject or hint highlight, if any.
func _set_glow(tool: SurgicalTool, on: bool) -> void:
	var glow: ShaderMaterial = null
	if on:
		glow = _glow
	elif _rejecting.has(tool):
		glow = _reject_glow
	elif _hinted.has(tool):
		glow = _hint_glow
	if on:
		HeldSparkles.start(tool)
	else:
		HeldSparkles.stop(tool)
	for node in tool.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.name in [OUTLINE_NODE, GLOW_NODE] or mesh_instance.mesh == null:
			continue
		_set_outer_glow(mesh_instance, glow.get_meta(&"glow") if glow and glow.has_meta(&"glow") else null)
		mesh_instance.material_overlay = glow
		var outline := mesh_instance.get_node_or_null(NodePath(OUTLINE_NODE)) as MeshInstance3D
		if glow == null:
			if outline:
				outline.hide()
			continue
		if outline == null:
			outline = MeshInstance3D.new()
			outline.name = OUTLINE_NODE
			outline.mesh = _outline_mesh(mesh_instance.mesh)
			outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.add_child(outline)
		outline.material_override = glow.get_meta(&"outline")
		outline.show()


## The soft glow around an outline, for highlights that have one (the held tool's neon).
func _set_outer_glow(mesh_instance: MeshInstance3D, material: Material) -> void:
	var outer := mesh_instance.get_node_or_null(NodePath(GLOW_NODE)) as MeshInstance3D
	if material == null:
		if outer:
			outer.hide()
		return
	if outer == null:
		outer = MeshInstance3D.new()
		outer.name = GLOW_NODE
		outer.mesh = _outline_mesh(mesh_instance.mesh)
		outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.add_child(outer)
	outer.material_override = material
	outer.show()


## The mesh with its normals averaged wherever corners share a position, so
## the outline, pushed out along them, stays one connected band.
static func _outline_mesh(mesh: Mesh) -> ArrayMesh:
	if _outline_meshes.has(mesh):
		return _outline_meshes[mesh]
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var sums := {}
		for i in vertices.size():
			var key := vertices[i].snappedf(0.00001)
			sums[key] = sums.get(key, Vector3.ZERO) + normals[i]
		var smooth := PackedVector3Array()
		smooth.resize(vertices.size())
		for i in vertices.size():
			smooth[i] = (sums[vertices[i].snappedf(0.00001)] as Vector3).normalized()
		var outline_arrays := []
		outline_arrays.resize(Mesh.ARRAY_MAX)
		outline_arrays[Mesh.ARRAY_VERTEX] = vertices
		outline_arrays[Mesh.ARRAY_NORMAL] = smooth
		outline_arrays[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, outline_arrays)
	_outline_meshes[mesh] = result
	return result


## A highlight: the glow material, carrying its outline material as metadata.
static func _make_highlight() -> ShaderMaterial:
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://gameplay/highlight_glow.gdshader")
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://gameplay/highlight_outline.gdshader")
	glow.set_meta(&"outline", outline)
	return glow


static func _set_highlight_color(highlight: ShaderMaterial, color: Color) -> void:
	highlight.set_shader_parameter("glow_color", color)
	(highlight.get_meta(&"outline") as ShaderMaterial).set_shader_parameter("outline_color", color)


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


## The point at tray-floor height under a screen position.
func _table_point_under(screen: Vector2) -> Vector3:
	var plane := Plane(Vector3.UP, tray.tools_root.global_position.y)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	return hit if hit != null else tray.global_position


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
