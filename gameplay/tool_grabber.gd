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
## - over hand_off_zone, or flicked toward it (see the Flick exports):
##   tool_handed is emitted, and the listener decides.
## - anywhere else: flown back to the nearest spot on the tray, and the pile
##   gets a small nudge.
## A loose tool that leaves the tray by itself (see off_tray_margin), or whose
## middle goes off screen (Tray.on_screen), is flown back the same way.
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
## A held tool turns, at the same pace, to lie flat with its long side across the screen, so it
## lands sideways on the surgeon's hand.
@export var turn_held_across := true
## Height above the tray floor that returned tools are let go from.
@export var drop_height := 0.16
@export var return_seconds := 0.35
## Returned tools land at least this far inside the tray's edge (on top of
## their own width), so they don't catch the rim.
@export var return_margin := 0.01
## A loose tool whose middle gets this far past the edge of the tray floor (over the wall, pushed
## by the pile or bouncing out) is returned like one let go off the tray. A little past the edge
## lets a long tool rest propped on the rim.
@export var off_tray_margin := 0.01
## Speed (m/s) of the random nudge the other tray tools get when a dropped
## or returned tool lands.
@export var jumble_speed := 0.1
## How long a consumed tool takes to drop onto the hand-off zone, then to shrink away.
@export var consume_drop_seconds := 0.3
@export var consume_shrink_seconds := 0.2

@export_group("Flick")
## A tool let go short of hand_off_zone still counts as handed when it's flicked at it. Pixels
## are the 720-wide design screen's. The pointer must be moving at least this fast (pixels a
## second) as it lets go, so a slow let-go is judged where it is, as before.
@export var flick_min_speed := 900.0
## How far from the pointer the zone may be, along the flick (pixels to its nearest edge).
@export var flick_reach_pixels := 450.0
## How far the flick's heading may point beside the zone (degrees either way).
@export_range(1.0, 90.0) var flick_angle_degrees := 20.0
## How far back the flick's speed and heading are measured. Short, so a finger that stops before
## it lifts isn't a flick.
@export var flick_window_seconds := 0.1

@export_group("Surgeon")
## The surgeon who takes handed tools, or none. With him, a handed tool drops onto his hand and
## rides on it through what he does with it (Surgeon.take(): the timing is his), and when his
## animation lets go it flies off the way his hand moves: a right one off the screen, a wrong one
## back onto the tray. Without him, consumed tools shrink away on hand_off_zone and rejected ones
## hover for reject_seconds, then fly back.
@export var surgeon: Surgeon
## Where he throws a right tool, from his hand (metres): straight up, off the top of the screen.
@export var toss_away := Vector3(-0.02, 0.09, -0.23)
@export var toss_away_seconds := 0.7
## How much of his hand's speed a right tool sets off with (1 = all of it).
@export var toss_away_follow_hand := 1.0
## A wrong tool thrown back onto the tray: how much of his hand's speed it sets off with, and how
## long it flies.
@export var throw_back_follow_hand := 1.0
@export var throw_back_seconds := 0.55
## Turns a tool thrown away spins in the air.
@export var toss_spin_turns := 1.0
## The slant of a tool lying in his fist, in degrees on screen (rising to the right), like the
## drawn hand. 0 = straight across.
@export_range(-80.0, 80.0, 1.0) var on_hand_angle := 20.0

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
## The heading the held tool turns to (see turn_held_across).
var _held_yaw := 0.0
## The pointer's recent path while a tool is held, for flicks: x and y are its position, z the
## seconds since the grab. Oldest first, reaching just past flick_window_seconds back.
var _pointer_trail := PackedVector3Array()
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
	_set_highlight_color(_reject_glow, reject_color)
	# The held tool: the neon outline and glow (their colours are their own), and the tool
	# keeps its own colour.
	_glow.set_meta(&"outline", preload("res://gameplay/held_neon_outline.tres"))
	_glow.set_meta(&"glow", preload("res://gameplay/held_neon_glow.tres"))
	_glow.set_shader_parameter("base_strength", 0.0)
	_glow.set_shader_parameter("rim_strength", 0.15)
	# Hinted tools: the same neon line, with half the held glow, a quarter of its twinkles
	# and no stars (Julia's call).
	var hint_outline := (_glow.get_meta(&"outline") as ShaderMaterial).duplicate() as ShaderMaterial
	var hint_neon_glow := (_glow.get_meta(&"glow") as ShaderMaterial).duplicate() as ShaderMaterial
	hint_neon_glow.set_shader_parameter("strength", hint_neon_glow.get_shader_parameter("strength") * 0.5)
	hint_neon_glow.set_shader_parameter("sparkle_density", hint_neon_glow.get_shader_parameter("sparkle_density") * 0.25)
	_hint_glow.set_meta(&"outline", hint_outline)
	_hint_glow.set_meta(&"glow", hint_neon_glow)
	_hint_glow.set_shader_parameter("glow_color", glow_color)
	_hint_glow.set_shader_parameter("base_strength", 0.0)
	_hint_glow.set_shader_parameter("rim_strength", 0.04)
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


## Returns loose tools that are leaving the tray. Held and flying tools are frozen or in
## _flying, and a sliding tray's tools don't process, so only ones lying in the pile are checked.
func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	for tool in tray.tools():
		if tool.freeze or _flying.has(tool) or not tool.can_process():
			continue
		# Off screen only past the very edge, so one put back just inside the margin stays put.
		if not tray.contains(tool.global_position, -off_tray_margin) or not tray.on_screen(tool.global_position, 0.0):
			return_to_tray(tool)


func _process(delta: float) -> void:
	if _candidate:
		_press_time += delta
		if _press_time >= hold_seconds:
			_grab(_candidate)
			_candidate = null
	if _held:
		_track_pointer(delta)
		var target := _held_position()
		var weight := 1.0 - exp(-follow_sharpness * delta)
		_held.global_position = _held.global_position.lerp(target, weight)
		if turn_held_across:
			_held.global_basis = _held.global_basis.slerp(Basis(Vector3.UP, _held_yaw), weight)


## Drops a handed-over tool onto the middle of the hand-off zone, shrinks it
## away and frees it. With a surgeon, it drops onto his hand instead, he nods
## and throws it up off the screen. Await the returned signal to act once it's
## gone.
func consume(tool: SurgicalTool) -> Signal:
	_released_over.erase(tool)
	_make_intangible(tool)
	_flying[tool] = true
	var tween := _drop_onto_hand(tool)
	tween.tween_callback(_play.bind(receive_sound))
	if surgeon:
		_ride_hand(tween, tool, true)
		# Where it's thrown from is only known once he lets go.
		var flight := {}
		tween.tween_callback(func() -> void:
			flight.from = tool.global_position
			flight.via = flight.from + surgeon.throw_velocity(true) * toss_away_follow_hand * toss_away_seconds / 2.0
			flight.yaw = tool.global_rotation.y)
		tween.tween_method(func(t: float) -> void:
			tool.global_position = _toss_point(flight.from, flight.via, flight.from + toss_away, t)
			tool.global_rotation.y = flight.yaw - t * toss_spin_turns * TAU, 0.0, 1.0, toss_away_seconds)
	else:
		tween.set_parallel()
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
## in reject_color, for reject_seconds, then goes back to the tray. With a
## surgeon, it drops onto his hand, still highlighted, and he says no and
## throws it back onto the tray.
func reject(tool: SurgicalTool) -> void:
	_make_intangible(tool)
	# Not grabbable while it hovers.
	_flying[tool] = true
	_rejecting[tool] = true
	_set_glow(tool, false)
	if surgeon:
		var tween := _drop_onto_hand(tool)
		_ride_hand(tween, tool, false)
		tween.tween_callback(func() -> void:
			_rejecting.erase(tool)
			# Thrown, so anywhere on the tray rather than near where it was let go.
			_released_over[tool] = tray.random_point()
			return_to_tray(tool, surgeon.throw_velocity(false) * throw_back_follow_hand))
		return
	get_tree().create_timer(reject_seconds, false).timeout.connect(func() -> void:
		_rejecting.erase(tool)
		_flying.erase(tool)
		if is_instance_valid(tool):
			return_to_tray(tool))


## Flies a tool to the nearest spot on the tray where it fits (turning it
## only if that gets it closer), eases it to a stop drop_height above the
## floor, and lets it fall. The rest of the pile is nudged when it lands.
## With a throw_velocity it's thrown instead: it sets off that way and takes
## throw_back_seconds.
func return_to_tray(tool: SurgicalTool, throw_velocity := Vector3.ZERO) -> void:
	_play(return_sound)
	_make_intangible(tool)
	_set_glow(tool, false)
	_flying[tool] = true
	var near: Vector3 = _released_over.get(tool, tool.global_position)
	_released_over.erase(tool)
	var placement := tray.nearest_placement(tool, near, tool.global_rotation.y, return_margin)
	var spot := placement.origin + Vector3.UP * drop_height
	var flat_rotation := Vector3(0.0, placement.basis.get_euler().y, 0.0)
	var seconds := return_seconds
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if throw_velocity == Vector3.ZERO:
		tween.tween_property(tool, "global_position", spot, seconds)
	else:
		seconds = throw_back_seconds
		var from := tool.global_position
		var via := from + throw_velocity * seconds / 2.0
		tween.tween_method(func(t: float) -> void: tool.global_position = _toss_point(from, via, spot, t),
			0.0, 1.0, seconds).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(tool, "global_rotation", flat_rotation, seconds)
	tween.chain().tween_callback(func() -> void:
		_flying.erase(tool)
		_drop(tool)
		_on_landing(tool))


## Starts a tween that drops a handed-over tool, lying flat, onto the
## surgeon's hand or the middle of the hand-off zone. Steps added to it run
## one after another, after the drop.
func _drop_onto_hand(tool: SurgicalTool) -> Tween:
	var landing := surgeon.hand_point() if surgeon \
		else hand_off_zone.global_transform * _first_shape(hand_off_zone).position
	var yaw := tool.global_rotation.y
	if surgeon:
		var slanted := _across_yaw(tool) + _turn_for_slant(landing, on_hand_angle)
		yaw += angle_difference(yaw, slanted)
	var flat_rotation := Vector3(0.0, yaw, 0.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(tool, "global_position", landing, consume_drop_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(tool, "global_rotation", flat_rotation, consume_drop_seconds)
	tween.set_parallel(false)
	return tween


## The turn about the vertical that slants a flat line along world X by
## degrees on screen (rising to the right) where it lies at point.
func _turn_for_slant(point: Vector3, degrees: float) -> float:
	var at := camera.unproject_position(point)
	var best := 0.0
	var best_error := INF
	for whole_degrees in range(-89, 90):
		var turn := deg_to_rad(whole_degrees)
		var along := camera.unproject_position(point + Vector3.RIGHT.rotated(Vector3.UP, turn) * 0.05) - at
		var error := absf(angle_difference(atan2(-along.y, along.x), deg_to_rad(degrees)))
		if error < best_error:
			best = turn
			best_error = error
	return best


## Adds to the tween: the surgeon takes the tool, and it rides on his hand
## until his animation lets go of it.
func _ride_hand(tween: Tween, tool: SurgicalTool, right: bool) -> void:
	tween.tween_callback(surgeon.take.bind(right))
	tween.tween_method(func(_t: float) -> void: tool.global_position = surgeon.hand_point(),
		0.0, 1.0, surgeon.release_delay(right))


## A point on a throw, t from 0 to 1: a curve that sets off towards via (at
## the speed that would reach it halfway through) and ends at to.
static func _toss_point(from: Vector3, via: Vector3, to: Vector3, t: float) -> Vector3:
	return from.lerp(via, t).lerp(via.lerp(to, t), t)


func _grab(tool: SurgicalTool) -> void:
	_held = tool
	_held_yaw = _across_yaw(tool)
	_pointer_trail.clear()
	_track_pointer(0.0)
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


## The heading that lays the tool's long side across the screen (along world
## X), whichever of the two ways round is nearer its heading now.
func _across_yaw(tool: SurgicalTool) -> float:
	var box := AABB()
	for mesh_instance: MeshInstance3D in tool.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null or mesh_instance.name in [OUTLINE_NODE, GLOW_NODE]:
			continue
		var to_tool := tool.global_transform.affine_inverse() * mesh_instance.global_transform
		box = box.merge(to_tool * mesh_instance.get_aabb())
	var across := 0.0 if box.size.x >= box.size.z else PI / 2.0
	var yaw := tool.global_rotation.y
	if absf(angle_difference(yaw, across)) > absf(angle_difference(yaw, across + PI)):
		across += PI
	return across


func _release() -> void:
	var tool := _held
	_held = null
	# The let-go comes in before this frame's _process, about a frame after the last sample.
	_track_pointer(get_process_delta_time())
	_released_over[tool] = _table_point_under(_pointer)
	tool_released.emit(tool)
	var zone := _zone_under(_pointer)
	if zone == hand_off_zone or _flicked_at(hand_off_zone):
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


## Gives the tool a soft version of the held neon until clear_hints(). Holding it shows
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


## The grabbable tool under a screen position, or null. The tool actually under the pointer
## wins: the enlarged grab areas only count when the ray misses every tool's real shape, or
## a thin tool on top (its grab area is at least 2 cm tall) would hide the edge of one beneath.
func _tool_at(screen: Vector2) -> SurgicalTool:
	var tool := _tray_tool_hit(screen, 1, false)
	return tool if tool else _tray_tool_hit(screen, PICK_LAYER, true)


## The tray tool the first thing a ray from the camera hits belongs to, or null.
func _tray_tool_hit(screen: Vector2, mask: int, areas: bool) -> SurgicalTool:
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * RAY_LENGTH, mask)
	query.collide_with_areas = areas
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


## Adds the pointer to _pointer_trail, this many seconds after the last sample.
func _track_pointer(seconds: float) -> void:
	var now := (_pointer_trail[-1].z if not _pointer_trail.is_empty() else 0.0) + seconds
	_pointer_trail.append(Vector3(_pointer.x, _pointer.y, now))
	while _pointer_trail.size() > 2 and now - _pointer_trail[1].z >= flick_window_seconds:
		_pointer_trail.remove_at(0)


## The pointer's velocity (pixels a second) over the last flick_window_seconds of _pointer_trail.
func _pointer_velocity() -> Vector2:
	var first := _pointer_trail[0]
	var last := _pointer_trail[-1]
	# Too short a stretch (a let-go right after the grab) would make a twitch look fast.
	if last.z - first.z < flick_window_seconds / 4.0:
		return Vector2.ZERO
	return Vector2(last.x - first.x, last.y - first.y) / (last.z - first.z)


## Whether the pointer let go flicking at the zone: at least flick_min_speed, with the zone's
## outline on screen inside the fan flick_angle_degrees either side of the flick's heading,
## flick_reach_pixels long.
func _flicked_at(zone: Area3D) -> bool:
	var velocity := _pointer_velocity()
	if velocity.length() < flick_min_speed:
		return false
	var outline := _screen_outline(zone)
	if outline.is_empty():
		return false
	const FAN_STEPS := 8
	var half_angle := deg_to_rad(flick_angle_degrees)
	var fan := PackedVector2Array([_pointer])
	for i in FAN_STEPS + 1:
		var angle := velocity.angle() + lerpf(-half_angle, half_angle, float(i) / FAN_STEPS)
		fan.append(_pointer + Vector2.from_angle(angle) * flick_reach_pixels)
	return not Geometry2D.intersect_polygons(fan, outline).is_empty()


## The outline on screen of the zone's box, or nothing if it's behind the camera.
func _screen_outline(zone: Area3D) -> PackedVector2Array:
	var shape := _first_shape(zone)
	var size := (shape.shape as BoxShape3D).size
	var corners := PackedVector2Array()
	for i in 8:
		var corner := shape.global_transform * AABB(-size / 2.0, size).get_endpoint(i)
		if camera.is_position_behind(corner):
			return PackedVector2Array()
		corners.append(camera.unproject_position(corner))
	var outline := Geometry2D.convex_hull(corners)
	# The hull comes closed, its first point repeated at the end.
	outline.resize(outline.size() - 1)
	return outline


func _first_shape(zone: Area3D) -> CollisionShape3D:
	return zone.find_children("*", "CollisionShape3D", false, false)[0]
