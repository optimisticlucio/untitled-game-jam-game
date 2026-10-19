@tool
extends Node3D
## Editor preview of the held tool's highlight: the neon outline, its glow and the stars floating
## off it (HeldSparkles). Select this root node: the sliders at the top of the inspector change
## gameplay/held_neon_outline.tres, held_neon_glow.tres, held_sparkle.tres and held_sparkles.tscn
## (which the game uses directly) and save them right away. The tool gets the game's toon look, as
## in the game. It's 10x bigger than in the game so the editor view shows it; widths and star sizes
## follow the distance to the camera, so they look the same.

const OUTLINE := preload("res://gameplay/held_neon_outline.tres")
const GLOW := preload("res://gameplay/held_neon_glow.tres")
const STAR := preload("res://gameplay/held_sparkle.tres")

# Inspector groups: [title, prefix]. Each slider below starts with one of the prefixes.
const GROUPS := [["Outline", "outline_"], ["Glow", "glow_"], ["Colours", "colours_"],
		["Sparkles", "sparkle_"], ["Particles", "particles_"]]
# Slider -> [what it changes, its property, "min,max,step"]. What it changes is a material
# ("outline", "glow", "both" or "star") or "particles", the stars' node (held_sparkles.tscn).
const SLIDERS := {
	"outline_width": ["outline", "width", "0,0.02,0.0005"],
	"outline_whiteness": ["outline", "whiteness", "0,1,0.01"],
	"glow_width": ["glow", "width", "0,0.06,0.001"],
	"glow_strength": ["glow", "strength", "0,3,0.05"],
	"glow_softness": ["glow", "softness", "0.1,8,0.1"],
	"glow_whiteness": ["glow", "whiteness", "0,1,0.01"],
	"colours_band_screens": ["both", "band_screens", "0.2,5,0.01"],
	"colours_speed": ["both", "speed", "0,2,0.01"],
	"sparkle_density": ["glow", "sparkle_density", "0,0.5,0.01"],
	"sparkle_cell": ["glow", "sparkle_cell", "0.005,0.1,0.001"],
	"sparkle_speed": ["glow", "sparkle_speed", "0,10,0.1"],
	"particles_amount": ["particles", "amount", "0,120,1"],
	"particles_lifetime": ["particles", "lifetime", "0.2,4,0.05"],
	"particles_speed": ["particles", "initial_velocity_max", "0,0.15,0.001"],
	"particles_spread": ["particles", "spread", "0,180,1"],
	"particles_rise": ["particles", "gravity", "-0.1,0.2,0.001"],
	"particles_size": ["star", "size", "0,0.15,0.001"],
	"particles_brightness": ["star", "brightness", "0,4,0.05"],
	"particles_white_core": ["star", "white_core", "0,1,0.01"],
	"particles_rays": ["star", "ray_length", "0,1.5,0.05"],
}
# The stars' properties saved into held_sparkles.tscn.
const PARTICLE_PROPERTIES := ["amount", "lifetime", "initial_velocity_min", "initial_velocity_max",
		"spread", "gravity"]
# Seconds to wait after the last slider move before writing the files.
const SAVE_DELAY := 0.3

var _unsaved: Array[ShaderMaterial] = []
var _particles_unsaved := false
var _save_in := 0.0


func _ready() -> void:
	ToolLook.apply_to_tool($Tool)
	HeldSparkles.start($Tool)
	# The rise is in metres: this tool is shown bigger, so its stars rise faster.
	_sparkles().gravity *= _tool_scale()
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		Engine.get_singleton(&"EditorInterface").call_deferred(&"edit_node", self)


func _process(delta: float) -> void:
	if _unsaved.is_empty() and not _particles_unsaved:
		return
	_save_in -= delta
	if _save_in > 0.0:
		return
	for material in _unsaved:
		ResourceSaver.save(material)
	_unsaved.clear()
	if _particles_unsaved:
		_save_particles()
		_particles_unsaved = false


func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for group in GROUPS:
		list.append({"name": group[0], "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP,
				"hint_string": group[1]})
		for slider in SLIDERS:
			if slider.begins_with(group[1]):
				list.append({"name": slider, "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE,
						"hint_string": SLIDERS[slider][2], "usage": PROPERTY_USAGE_EDITOR})
	return list


func _get(property: StringName) -> Variant:
	if not SLIDERS.has(property):
		return null
	var slider: Array = SLIDERS[property]
	if slider[0] != "particles":
		return _materials(slider[0])[0].get_shader_parameter(slider[1])
	var sparkles := _sparkles()
	if sparkles == null:
		return null
	if slider[1] == "gravity":
		return sparkles.gravity.y / _tool_scale()
	return float(sparkles.get(slider[1]))


func _set(property: StringName, value: Variant) -> bool:
	if not SLIDERS.has(property):
		return false
	var slider: Array = SLIDERS[property]
	_save_in = SAVE_DELAY
	if slider[0] != "particles":
		for material in _materials(slider[0]):
			material.set_shader_parameter(slider[1], value)
			if not _unsaved.has(material):
				_unsaved.append(material)
		return true
	var sparkles := _sparkles()
	if sparkles == null:
		return true
	match slider[1]:
		"amount":
			sparkles.amount = maxi(1, int(value))
		"gravity":
			sparkles.gravity = Vector3(0.0, value * _tool_scale(), 0.0)
		"initial_velocity_max":
			# One slider for both: the slowest stars move at a third of the fastest.
			sparkles.initial_velocity_max = value
			sparkles.initial_velocity_min = value / 3.0
		_:
			sparkles.set(slider[1], value)
	_particles_unsaved = true
	return true


func _materials(which: String) -> Array[ShaderMaterial]:
	match which:
		"outline":
			return [OUTLINE]
		"glow":
			return [GLOW]
		"star":
			return [STAR]
	return [OUTLINE, GLOW]


func _sparkles() -> CPUParticles3D:
	return $Tool.get_node_or_null(NodePath(HeldSparkles.NODE)) as CPUParticles3D


func _tool_scale() -> float:
	return ($Tool as Node3D).scale.x


## Writes the stars' settings into held_sparkles.tscn, without the starting points (the game puts
## those on each tool) and with the rise in the game's metres.
func _save_particles() -> void:
	var live := _sparkles()
	var copy := HeldSparkles.SCENE.instantiate() as CPUParticles3D
	for property in PARTICLE_PROPERTIES:
		copy.set(property, live.get(property))
	copy.gravity = live.gravity / _tool_scale()
	HeldSparkles.SCENE.pack(copy)
	ResourceSaver.save(HeldSparkles.SCENE)
	copy.free()
