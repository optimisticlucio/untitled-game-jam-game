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
## tray's far rim hides the bottom of his coat. The level turns him to face the camera and puts
## Target/HandOffZone on his hand.

## Which loop he waits with: idle, or impatient finger snaps.
@export var impatient := false:
	set(value):
		if value == impatient:
			return
		impatient = value
		if is_node_ready() and not _taking:
			_play(_waiting())
## How far in front of his drawing a tool on his hand sits, so it shows over the glove.
@export var hand_front := 0.03
## What he does with a right tool, in order: an animation's name, or seconds of idle. The tool
## leaves his hand at correct_release_frame of the last animation (check it when that changes).
## Julia's timing: the hand gives a little under the tool, a nod, a second's wait, the throw.
@export var correct_steps: Array = [&"catch", &"correct", 1.0, &"throw"]
@export var correct_release_frame := 6
## The same for a wrong tool: it sits on his hand for a moment, then he says no with an open hand.
@export var wrong_steps: Array = [0.5, &"wrong"]
@export var wrong_release_frame := 1

var _taking := false
## Counts take() calls, so an older one stops when a newer one starts.
var _take_count := 0

@onready var _sprite: AnimatedSprite3D = $Sprite
## Where his hand is in every frame of every animation (frame px, y down), from the Spine export.
@onready var _hands: Dictionary = _sprite.sprite_frames.get_meta(&"hands")


func _ready() -> void:
	# Only one-shots finish; the waiting loops never do. During take() it moves on by itself.
	_sprite.animation_finished.connect(func() -> void:
		if not _taking:
			_play(_waiting()))
	_play(_waiting())


## Plays what he does with a handed tool (correct_steps or wrong_steps), then he waits again.
func take(right: bool) -> void:
	_take_count += 1
	var count := _take_count
	_taking = true
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
	var steps := _steps(right)
	var seconds := 0.0
	for step: Variant in steps.slice(0, -1):
		seconds += float(step) if _is_wait(step) else _seconds(step)
	return seconds + _release_frame(right) / _fps(steps[-1])


## How fast (m/s) his hand moves as it lets go of the tool, from the release frame's drawing and
## the one before, so a thrown tool carries on the hand's motion.
func throw_velocity(right: bool) -> Vector3:
	var anim: StringName = _steps(right)[-1]
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


func _play(anim: StringName) -> void:
	_sprite.play(anim)
	# play() carries on if it's already this animation; a second hand-off starts it over.
	_sprite.set_frame_and_progress(0, 0.0)


func _waiting() -> StringName:
	return &"impatient" if impatient else &"idle"


static func _is_wait(step: Variant) -> bool:
	return step is float or step is int


func _steps(right: bool) -> Array:
	return correct_steps if right else wrong_steps


func _release_frame(right: bool) -> int:
	return correct_release_frame if right else wrong_release_frame


func _fps(anim: StringName) -> float:
	return _sprite.sprite_frames.get_animation_speed(anim) * _sprite.speed_scale


## How long a one-shot animation plays.
func _seconds(anim: StringName) -> float:
	return _sprite.sprite_frames.get_frame_count(anim) / _fps(anim)
