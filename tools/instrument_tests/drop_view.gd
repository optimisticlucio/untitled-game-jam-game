extends "res://tools/instrument_tests/drop_test.gd"
## Same drop, rendered with a camera and sky (metal needs reflections). Run WITHOUT --headless.
## Saves the settled frame to SNAPSHOT (env var, absolute path) before quitting.

func _ready() -> void:
	super._ready()
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(0.0, 0.48, 0.42)
	cam.look_at(Vector3(0.0, -0.01, 0.0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _physics_process(delta: float) -> void:
	if elapsed + delta >= SETTLE_S and OS.has_environment("SNAPSHOT"):
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SNAPSHOT"))
	super._physics_process(delta)
