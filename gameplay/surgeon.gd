class_name Surgeon
extends Node3D
## The surgeon behind the tray, who takes the tools. Julia's Spine animation, played as frames
## (assets/surgeon, built by dev/surgeon/build_surgeon_frames.gd). He waits on a loop (idle, or
## impatient finger snaps). take() plays what he does with a handed tool (correct_steps or
## wrong_steps), then he waits again. ToolGrabber (its surgeon export) lands handed tools on
## hand_point(), calls take(), keeps the tool on his hand for release_delay() and then throws it
## with throw_velocity().
##
## He stands in the 3D world, not the UI, so held and handed tools show in front of him and the
## tray hides his lower body. The level turns him to face the camera and puts Target/HandOffZone
## on his hand. He's drawn in two layers that play together: Sprite (all but the fingers) and
## Front (the fingers of his fist), drawn closer to the camera than a tool on his hand, so the
## tool sits inside his fist. Both draw before other see-through things (render_priority -1),
## so the table art in front of him (Table/Art) always covers his lower body.

## Whether he waits impatiently, snapping his fingers, instead of idle. He changes loop only where
## the two meet without a jump: the snapping starts once his breathing is back at rest (the end of
## the idle loop), and stops as soon as a snap is over (snap_quiet_from), never mid-snap.
@export var impatient := false:
	set(value):
		if value == impatient:
			return
		impatient = value
		_waiting_changed()
## How far in front of his drawing a tool on his hand sits, so it shows over the glove.
@export var hand_front := 0.03
## How far in front of his drawing his fingers are drawn: in front of a tool on his hand.
@export var fingers_front := 0.05
## What he does with a right tool, in order: an animation's name, or seconds of idle. The tool
## leaves his hand at correct_release_frame of correct_release_animation (check the frame when
## that animation changes); the steps after it play with his hand empty.
## Julia's timing: the hand gives a little under the tool, a second's wait, the throw, and only
## then his nod and thumbs up (its thumbs-up drawing has no fingers layer to hold a tool in).
@export var correct_steps: Array = [&"catch", 1.0, &"throw", &"correct"]
@export var correct_release_animation := &"throw"
@export var correct_release_frame := 5
## The same for a wrong tool: it sits on his hand for a moment, then he says no with an open hand.
@export var wrong_steps: Array = [0.5, &"wrong"]
@export var wrong_release_animation := &"wrong"
@export var wrong_release_frame := 1
## What he says as an animation starts (on the Voice player): animation name → sound. Keep each
## sound shorter than its animation, so he isn't still talking when he moves on.
@export var voices: Dictionary[StringName, AudioStream] = {}
## Frames of the impatient loop where his fingers snap (the hand jumps to the snapped drawing),
## for the Snap player. Check them when the loop is exported or packed again.
@export var snap_frames := PackedInt32Array([5, 9])
## The first frame of the impatient loop where the snapping is over and his hand is back at rest.
@export var snap_quiet_from := 16
## He clears his throat (Throat player) while he waits for a slow player: once he has waited
## throat_clear_after seconds, then every throat_clear_every, but never while snapping or taking.
@export var throat_clear_after := 6.0
@export var throat_clear_every := 7.0

## Seconds he has been waiting for the current tool; 0 when nothing is asked for. The level sets it.
var waiting_seconds := 0.0
## While the player holds a tool he stops snapping, so his hand is at rest when it lands on it.
## ToolGrabber sets it.
var player_holding := false:
	set(value):
		if value == player_holding:
			return
		player_holding = value
		_waiting_changed()

var _taking := false
## Counts take() calls, so an older one stops when a newer one starts.
var _take_count := 0
var _next_throat_clear := 0.0

@onready var _sprite: AnimatedSprite3D = $Sprite
## His fingers, which follow Sprite's animation and frame.
@onready var _front: AnimatedSprite3D = $Front
@onready var _voice: AudioStreamPlayer = $Voice
@onready var _snap: AudioStreamPlayer = $Snap
@onready var _throat: AudioStreamPlayer = $Throat
## Where his hand is in every frame of every animation (frame px, y down), from the Spine export.
@onready var _hands: Dictionary = _sprite.sprite_frames.get_meta(&"hands")


func _ready() -> void:
	_place_front()
	_sprite.animation_changed.connect(_sync_front)
	_sprite.frame_changed.connect(_sync_front)
	_sprite.frame_changed.connect(func() -> void:
		if _sprite.animation == &"impatient" and _sprite.frame in snap_frames:
			_snap.play()
		# Done snapping: back to idle once this snap is over.
		if _sprite.animation == &"impatient" and _sprite.frame >= snap_quiet_from \
				and _waiting() == &"idle" and not _taking:
			_play(&"idle"))
	# Only one-shots finish; the waiting loops never do. During take() it moves on by itself.
	_sprite.animation_finished.connect(func() -> void:
		if not _taking:
			_play(_waiting()))
	# The end of a loop is his rest pose, where any loop can start.
	_sprite.animation_looped.connect(func() -> void:
		if _sprite.animation != _waiting() and not _taking:
			_play(_waiting()))
	_play(_waiting())


func _process(_delta: float) -> void:
	if waiting_seconds <= 0.0:
		_next_throat_clear = throat_clear_after
	elif waiting_seconds >= _next_throat_clear and not impatient and not _taking:
		_throat.play()
		_next_throat_clear = waiting_seconds + throat_clear_every


## Plays what he does with a handed tool (correct_steps or wrong_steps), then he waits again.
func take(right: bool) -> void:
	_take_count += 1
	var count := _take_count
	_taking = true
	# The right tool is what he was waiting for: no more impatience.
	if right:
		impatient = false
	for step: Variant in _steps(right):
		if _is_wait(step):
			if _sprite.animation != &"idle":
				_play(&"idle")
			await get_tree().create_timer(step, false).timeout
		else:
			_play(step)
			await _sprite.animation_finished
		if count != _take_count:
			return
	_taking = false
	_play(_waiting())


## Seconds from take(right) until his hand lets go of the tool.
func release_delay(right: bool) -> float:
	var release := _release_animation(right)
	var seconds := 0.0
	for step: Variant in _steps(right):
		if not _is_wait(step) and StringName(step) == release:
			break
		seconds += float(step) if _is_wait(step) else _seconds(step)
	return seconds + _release_frame(right) / _fps(release)


## How fast (m/s) his hand moves as it lets go of the tool, from the release frame's drawing and
## the one before, so a thrown tool carries on the hand's motion.
func throw_velocity(right: bool) -> Vector3:
	var anim := _release_animation(right)
	var frame := _release_frame(right)
	var points: PackedVector2Array = _hands[anim]
	var step := points[frame] - points[maxi(frame - 1, 0)]
	return _sprite.global_basis * Vector3(step.x, -step.y, 0.0) * _sprite.pixel_size * _fps(anim)


## Where a tool on his hand goes right now: the middle of the hand drawing showing, hand_front
## towards the camera. It moves frame by frame, like the drawing.
func hand_point() -> Vector3:
	var pixel: Vector2 = _hands[_sprite.animation][_sprite.frame]
	var size := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame).get_size()
	var local := Vector3(pixel.x - size.x / 2.0, size.y / 2.0 - pixel.y, 0.0) * _sprite.pixel_size
	return _sprite.global_transform * (local + Vector3.BACK * hand_front)


## Puts the fingers fingers_front closer to the camera, made as much smaller as that brings them
## closer, so on screen they sit exactly on his hand.
func _place_front() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var depth := (global_position - camera.global_position).dot(-camera.global_basis.z)
	var closer := 1.0 - fingers_front / depth
	_front.global_position = camera.global_position.lerp(global_position, closer)
	_front.pixel_size = _sprite.pixel_size * closer


func _sync_front() -> void:
	if _front.animation != _sprite.animation:
		_front.animation = _sprite.animation
	_front.frame = _sprite.frame


func _play(anim: StringName) -> void:
	_sprite.play(anim)
	# play() carries on if it's already this animation; a second hand-off starts it over.
	_sprite.set_frame_and_progress(0, 0.0)
	if voices.has(anim):
		_voice.stream = voices[anim]
		_voice.play()


func _waiting() -> StringName:
	return &"impatient" if impatient and not player_holding else &"idle"


## Switches to the waiting loop now wanted where it won't jump: right away if a snap is already
## over, else when the snap ends or the idle loop comes back to rest (see _ready).
func _waiting_changed() -> void:
	if not is_node_ready() or _taking or _sprite.animation == _waiting():
		return
	if _sprite.animation == &"impatient" and _sprite.frame >= snap_quiet_from:
		_play(_waiting())


static func _is_wait(step: Variant) -> bool:
	return step is float or step is int


func _steps(right: bool) -> Array:
	return correct_steps if right else wrong_steps


func _release_animation(right: bool) -> StringName:
	return correct_release_animation if right else wrong_release_animation


func _release_frame(right: bool) -> int:
	return correct_release_frame if right else wrong_release_frame


func _fps(anim: StringName) -> float:
	return _sprite.sprite_frames.get_animation_speed(anim) * _sprite.speed_scale


## How long a one-shot animation plays.
func _seconds(anim: StringName) -> float:
	return _sprite.sprite_frames.get_frame_count(anim) / _fps(anim)
