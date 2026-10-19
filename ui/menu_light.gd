extends TextureRect
## The lamp's light on the home screen (Julia's light layer), flickering a little like the level's
## tired fluorescent tube: a faint hum, and every few seconds one or two quick dips.

## How much the light hums all the time (0 = steady).
@export var hum := 0.06
@export var hum_speed := 6.0
## How far a dip dims the light, and how long a dip and the calm between flickers last (seconds).
@export var dip := 0.45
@export var dip_seconds := Vector2(0.04, 0.1)
@export var gap_seconds := Vector2(2.0, 6.0)
@export var double_chance := 0.35
## Higher = the light follows the dips faster.
@export var smoothing := 30.0

var _noise := FastNoiseLite.new()
var _time := 0.0
var _time_left := 0.0
var _level := 1.0
var _shown := 1.0
var _steps: Array[Vector2] = []


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time_left = randf_range(gap_seconds.x, gap_seconds.y)


func _process(delta: float) -> void:
	_time += delta
	_time_left -= delta
	if _time_left <= 0.0:
		if _steps.is_empty():
			_steps = _flicker()
		var step: Vector2 = _steps.pop_front()
		_level = step.x
		_time_left = step.y
	_shown = lerpf(_shown, _level, 1.0 - exp(-smoothing * delta))
	var humming := 1.0 - hum * (0.5 + 0.5 * _noise.get_noise_1d(_time * hum_speed))
	modulate.a = _shown * humming


## One flicker (one or two quick dips), then the steady light until the next one.
func _flicker() -> Array[Vector2]:
	var steps: Array[Vector2] = []
	for i in 2 if randf() < double_chance else 1:
		steps.append(Vector2(1.0 - dip * randf_range(0.5, 1.0), randf_range(dip_seconds.x, dip_seconds.y)))
		steps.append(Vector2(1.0, randf_range(0.03, 0.09)))
	steps.append(Vector2(1.0, randf_range(gap_seconds.x, gap_seconds.y)))
	return steps
