class_name HeartMonitor
extends AudioStreamPlayer
## The patient's heart monitor: its stream is one beep, played once per beat. The heart speeds up
## while the doctor waits for a tool (waiting_seconds, set by the level) and calms down slowly
## after the hand-off. Same beep at every speed, as on a real monitor.

## Beats per minute when nobody is waiting.
@export var calm_bpm := 56.0
## Beats per minute once the wait reaches stressed_after_seconds.
@export var stressed_bpm := 130.0
## The heart starts speeding up after this long a wait...
@export var calm_for_seconds := 3.0
## ...and is at stressed_bpm after this long.
@export var stressed_after_seconds := 12.0
## How quickly the heart rate follows, in beats per minute per second, so it speeds up and calms
## down gradually.
@export var bpm_change_per_second := 15.0

## Seconds the doctor has been waiting for the current tool; 0 when nothing is asked for.
var waiting_seconds := 0.0
var _bpm: float
var _until_beat := 0.0


func _ready() -> void:
	_bpm = calm_bpm


func _process(delta: float) -> void:
	var stress := clampf(inverse_lerp(calm_for_seconds, stressed_after_seconds, waiting_seconds), 0.0, 1.0)
	_bpm = move_toward(_bpm, lerpf(calm_bpm, stressed_bpm, stress), bpm_change_per_second * delta)
	_until_beat -= delta
	if _until_beat <= 0.0:
		play()
		_until_beat += 60.0 / _bpm
