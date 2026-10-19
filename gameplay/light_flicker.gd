class_name LightFlicker
extends Node
## The room's light as a tired fluorescent tube in a dodgy hospital. Put it under a Light3D.
## All the time: a restless hum, the light trembling a little. Every several seconds: a soft
## flicker, one or two dips (rarely a stutter of four), easing in and out so it reads as the
## light, not a glitch. Dim light turns a cold green. The world's sky and the shaders' own room light (the room_light shader global)
## follow, so the whole scene flickers together.

## Strength of the constant trembling (0.04 = up to 4 % dimmer).
@export_range(0.0, 0.5, 0.01) var hum := 0.025
## How fast it trembles.
@export var hum_speed := 18.0
## Seconds between flickers (a random time in this range).
@export var gap_seconds := Vector2(5.0, 12.0)
## How much darker a flicker's dip gets at most (0.15 = 15 %).
@export_range(0.0, 1.0, 0.01) var dip := 0.15
## How long one dip lasts, in seconds (a random time in this range).
@export var dip_seconds := Vector2(0.06, 0.15)
## Chance that a flicker is a double dip, a stutter of four, or the tube nearly going out.
@export_range(0.0, 1.0, 0.05) var double_chance := 0.2
@export_range(0.0, 1.0, 0.05) var stutter_chance := 0.05
@export_range(0.0, 1.0, 0.05) var blackout_chance := 0.0
## How quickly the light follows a dip (higher = sharper). Low values ease it in and out.
@export var smoothing := 30.0
## The light's colour when it's dim.
@export var dim_color := Color(0.78, 1.0, 0.86)

var _light: Light3D
var _environment: Environment
var _light_energy := 1.0
var _light_color := Color.WHITE
var _sky_energy := 1.0
var _noise := FastNoiseLite.new()
var _time := 0.0
var _time_left := 0.0
var _level := 1.0
## The brightness shown, easing toward _level.
var _shown := 1.0
## Steps still to play: x = brightness (1 = normal), y = seconds.
var _steps: Array[Vector2] = []


func _ready() -> void:
	_light = get_parent() as Light3D
	if _light == null:
		push_warning("LightFlicker must be a child of a Light3D")
		set_process(false)
		return
	_light_energy = _light.light_energy
	_light_color = _light.light_color
	_environment = _light.get_world_3d().environment
	if _environment:
		_sky_energy = _environment.background_energy_multiplier
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time_left = randf_range(gap_seconds.x, gap_seconds.y)


func _exit_tree() -> void:
	# Leave the room light normal for whatever comes next (menus, tool viewers). The
	# environment is shared with the next copy of the scene (Play again), which would
	# otherwise read a mid-flicker sky energy as its normal one.
	RenderingServer.global_shader_parameter_set(&"room_light", 1.0)
	if _environment:
		_environment.background_energy_multiplier = _sky_energy


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
	var trembling := 1.0 - hum * (0.5 + 0.5 * _noise.get_noise_1d(_time * hum_speed))
	_set_brightness(_shown * trembling)


## One flicker, then the steady (humming) light until the next one.
func _flicker() -> Array[Vector2]:
	var steps: Array[Vector2] = []
	var roll := randf()
	if roll < blackout_chance:
		# The tube nearly goes out, catches, and stutters back.
		steps.append(Vector2(randf_range(0.3, 0.45), randf_range(0.1, 0.25)))
		steps.append(Vector2(0.8, 0.05))
		steps.append(Vector2(0.5, 0.06))
	else:
		var dips := 1
		if roll < blackout_chance + stutter_chance:
			dips = 4
		elif roll < blackout_chance + stutter_chance + double_chance:
			dips = 2
		for i in dips:
			steps.append(Vector2(1.0 - dip * randf_range(0.5, 1.0), randf_range(dip_seconds.x, dip_seconds.y)))
			steps.append(Vector2(1.0, randf_range(0.03, 0.09)))
	steps.append(Vector2(1.0, randf_range(gap_seconds.x, gap_seconds.y)))
	return steps


func _set_brightness(brightness: float) -> void:
	_light.light_energy = _light_energy * brightness
	RenderingServer.global_shader_parameter_set(&"room_light", brightness)
	_light.light_color = _light_color.lerp(dim_color, clampf((1.0 - brightness) * 1.2, 0.0, 1.0))
	if _environment:
		_environment.background_energy_multiplier = _sky_energy * brightness
