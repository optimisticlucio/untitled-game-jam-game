extends "res://dev/instruments/tests/drop_test.gd"
## Shader lab: the drop_test pile (seed 7) in a placeholder OR, rendered once per shader variant.
## The tools' imported materials are swapped at runtime; no tool scene or asset is changed.
## Run with a window (the GPU is needed, so not --headless):
##   Godot --path <repo> res://dev/shader_lab/lab.tscn -- --out=<folder>
## With --settings=<browser lab settings.json> it uses Julia's browser-lab values, the wear.png and
## blood.png saved next to that file, the tray look (silver with cloth, or wood), and new random
## wear per run (or --seed=N).

const SHADER := ToolLook.TOOL_SHADER
const TRAY_SHADER := ToolLook.TRAY_SHADER
const LAB_SETTLE_S := 6.0
## Lookalikes laid out side by side for the close-up. Lab only: gameplay never names tools.
const PAIRS: Array[String] = ["kelly_clamp", "crile_clamp", "scalpel_10", "scalpel_11", "scalpel_15"]
const PAIRS_X := 1.0
const ROOM_FLOOR := Color(0.10, 0.27, 0.29)
const ROOM_DRAPE := Color(0.22, 0.52, 0.54)
## The tray is the same steel as the tools; a darker tray lets the tools stand out.
const TRAY_TINT := Color(0.7, 0.7, 0.72)

## Shader parameters that variants change, with the values every other variant uses.
const DEFAULTS := {"rim_strength": 0.3}
const DEFAULT_SHADOW_BLUR := 1.0
## Light terms one at a time, for tuning (run with --debug).
const DEBUG_VARIANTS: Array[Dictionary] = [
	{"name": "d0_ambient", "pairs": true, "params": {"rim_strength": 0.0, "env_strength": 0.0, "spec_strength": 0.0, "dark_level": 0.0, "metal_diffuse": 0.0}},
	{"name": "d1_diffuse_full", "pairs": true, "params": {"rim_strength": 0.0, "env_strength": 0.0, "spec_strength": 0.0, "dark_level": 1.0, "metal_diffuse": 1.0}},
	{"name": "d2_env_1", "pairs": true, "params": {"rim_strength": 0.0, "env_strength": 1.0, "spec_strength": 0.0, "dark_level": 0.0, "metal_diffuse": 0.0}},
	{"name": "d3_spec", "pairs": true, "params": {"rim_strength": 0.0, "env_strength": 0.0, "spec_strength": 1.2, "dark_level": 0.0, "metal_diffuse": 0.0}},
	{"name": "d5_current", "pairs": true, "shader": false},
]
## With --settings: the pile, a closer look at it, and the lookalikes.
const SETTINGS_VARIANTS: Array[Dictionary] = [
	{"name": "julia_pile"},
	{"name": "julia_close", "close": true},
	{"name": "julia_pairs", "pairs": true},
]
const VARIANTS: Array[Dictionary] = [
	{"name": "00_current", "shader": false},
	{"name": "01_toon_default"},
	{"name": "02_rim_soft", "params": {"rim_strength": 0.12}},
	{"name": "03_rim_strong", "params": {"rim_strength": 0.7}},
	{"name": "04_shadow_hard", "shadow_blur": 0.0},
	{"name": "05_shadow_soft", "shadow_blur": 3.0},
	{"name": "06_pairs_current", "shader": false, "pairs": true},
	{"name": "07_pairs_toon", "pairs": true},
]

var out_dir := "user://shader_lab"
var variants: Array[Dictionary] = VARIANTS
var sun: DirectionalLight3D
var cam: Camera3D
var game_cam_xform := Transform3D.IDENTITY
var pairs_cam_xform := Transform3D.IDENTITY
## Each entry: [MeshInstance3D, surface index, ShaderMaterial].
var swaps: Array[Array] = []
var capturing := false
var pair_bodies: Array[RigidBody3D] = []
var make_gif := false
var pile_path := ""
const GIF_FRAMES := 36
## Browser-lab settings (empty = the built-in variants), and what they turn into.
var settings: Dictionary = {}
var base_params: Dictionary = DEFAULTS.duplicate()
var wear_tex: Texture2D
var blood_tex: Texture2D
var rng := RandomNumberGenerator.new()
## Per-tool random look, one per body, shared by all its surfaces.
var per_body: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		if a == "--debug":
			variants = DEBUG_VARIANTS
		if a == "--gif":
			make_gif = true
		if a.begins_with("--export-pile="):
			pile_path = a.trim_prefix("--export-pile=")
		if a.begins_with("--seed="):
			rng.seed = int(a.trim_prefix("--seed="))
		if a.begins_with("--settings="):
			_load_settings(a.trim_prefix("--settings="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	super._ready()
	_build_room()
	_build_pairs()
	_collect_surfaces(self)
	print("shader_lab: %d tools, %d surfaces swapped" % [bodies.size(), swaps.size()])


func _physics_process(delta: float) -> void:
	elapsed += delta
	if capturing or elapsed < LAB_SETTLE_S:
		return
	capturing = true
	for b in bodies:
		b.freeze = true
	_capture()


func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ROOM_FLOOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 0.95)
	env.ambient_light_energy = 0.4
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	# From the upper left and a little from the far side, so shadows fall where the camera sees them.
	sun.look_at_from_position(Vector3(-0.5, 0.8, -0.3), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 1.5
	sun.shadow_bias = 0.01
	sun.shadow_normal_bias = 1.0
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = ROOM_DRAPE
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	ground.position.y = -tray_half.y - 0.001
	add_child(ground)
	var ground_body := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(4.0, 0.1, 4.0)
	ground_shape.shape = ground_box
	ground_shape.position.y = -0.05
	ground_body.add_child(ground_shape)
	ground_body.position.y = ground.position.y
	add_child(ground_body)

	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	# The game camera is the level's Camera3D, so the lab follows the team's framing.
	var main_scene := load("res://levels/level.tscn") as PackedScene
	var game: Node = main_scene.instantiate() if main_scene else Node.new()
	var game_cam := game.get_node_or_null("Camera3D") as Camera3D
	if game_cam:
		game_cam_xform = game_cam.transform
		cam.fov = game_cam.fov
		cam.keep_aspect = game_cam.keep_aspect
		cam.near = game_cam.near
	else:
		game_cam_xform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.62, 0.22)).looking_at(Vector3.ZERO, Vector3.UP)
		cam.fov = 32.0
	game.free()
	cam.transform = game_cam_xform


func _build_pairs() -> void:
	var floor_y := -tray_half.y
	for i in PAIRS.size():
		var path := SurgicalTool.FOLDER + PAIRS[i] + ".tscn"
		if not ResourceLoader.exists(path):
			push_warning("shader_lab: no %s" % path)
			continue
		var b := (load(path) as PackedScene).instantiate() as RigidBody3D
		b.position = Vector3(PAIRS_X, floor_y + 0.02, (i - 2) * 0.05)
		b.rotation.y = PI / 2.0
		add_child(b)
		bodies.append(b)
		pair_bodies.append(b)
	pairs_cam_xform = Transform3D(Basis.IDENTITY, Vector3(PAIRS_X, floor_y + 0.65, 0.0)).looking_at(
			Vector3(PAIRS_X, floor_y, 0.0), Vector3.FORWARD)


func _collect_surfaces(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		for s in mi.mesh.get_surface_count():
			var tex := _textures(mi.get_active_material(s))
			if tex[0] == null:
				continue
			var body := _body_of(mi)
			var mat := ShaderMaterial.new()
			if body is StaticBody3D and not settings.is_empty():
				mat = ToolLook.tray_material(mi.mesh)
				mat.set_shader_parameter("blood_tex", blood_tex)
				var cell := rng.randi() % 4
				mat.set_shader_parameter("blood_cell", Vector2(cell % 2, floorf(cell / 2.0)))
				mat.set_shader_parameter("blood_flip", Vector2(rng.randi() % 2, rng.randi() % 2))
			else:
				mat.shader = SHADER
				mat.set_shader_parameter("albedo_tex", tex[0])
				mat.set_shader_parameter("orm_tex", tex[1])
				if settings.is_empty():
					mat.set_shader_parameter("tint", _tint_for(mi))
					if body is StaticBody3D:
						# The satin tray would flash a big glint right over the tools.
						mat.set_shader_parameter("glint_strength", 0.0)
				else:
					_randomize_tool(mat, body)
			swaps.append([mi, s, mat])
	for c in node.get_children():
		_collect_surfaces(c)


func _load_settings(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not (data as Dictionary).has("params"):
		push_error("shader_lab: can't read settings from %s" % path)
		return
	settings = data["params"]
	base_params = {}
	for k in settings:
		var v: Variant = settings[k]
		base_params[k] = Color.html(v) if v is String else v
	base_params["glint_cos"] = 0.99985 - float(settings.get("glint_size", 0.35)) * 0.0012
	wear_tex = _load_texture(path.get_base_dir().path_join("wear.png"), true)
	blood_tex = _load_texture(path.get_base_dir().path_join("blood.png"), false)
	variants = SETTINGS_VARIANTS


func _load_texture(path: String, mipmaps: bool) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null:
		push_warning("shader_lab: no texture at %s" % path)
		return null
	if mipmaps:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A new random look for a tool, as the browser lab does: tint, wear placement, and whether it
## gets scratches and stains this time.
func _randomize_tool(mat: ShaderMaterial, body: Node) -> void:
	if not per_body.has(body):
		var hue_color := Color.from_hsv(rng.randf(), 0.5, 1.0)
		var tint_k := float(settings.get("tint_strength", 0.05)) * rng.randf_range(0.3, 1.0)
		var scratched := rng.randf() < float(settings.get("scratch_chance", 0.6))
		var stained := rng.randf() < float(settings.get("stain_chance", 0.5))
		per_body[body] = {
			"tint": Color.WHITE.lerp(hue_color, tint_k),
			"wear_offset": Vector2(rng.randf(), rng.randf()),
			"wear_angle": rng.randf() * TAU,
			"patch_offset": Vector2(rng.randf(), rng.randf()),
			"scratch_amount": float(settings.get("scratch_strength", 0.45)) * rng.randf_range(0.5, 1.0) if scratched else 0.0,
			"stain_amount": float(settings.get("stain_strength", 0.25)) * rng.randf_range(0.5, 1.0) if stained else 0.0,
		}
	var look: Dictionary = per_body[body]
	for k in look:
		mat.set_shader_parameter(k, look[k])
	mat.set_shader_parameter("wear_tex", wear_tex)


## [albedo, orm] from an imported glTF material. The glTF importer may keep ORM as an
## ORMMaterial3D, or split it into roughness/metallic textures that point at the same image.
func _textures(m: Material) -> Array[Texture2D]:
	# Tools already wear the game's look (ToolLook); take its textures.
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		return [sm.get_shader_parameter("albedo_tex"), sm.get_shader_parameter("orm_tex")]
	if m is ORMMaterial3D:
		return [m.albedo_texture, m.orm_texture]
	if m is StandardMaterial3D:
		var sm := m as StandardMaterial3D
		return [sm.albedo_texture, sm.roughness_texture if sm.roughness_texture else sm.metallic_texture]
	return [null, null]


func _body_of(mi: MeshInstance3D) -> Node:
	var n: Node = mi
	while n and not n is RigidBody3D and not n is StaticBody3D:
		n = n.get_parent()
	return n


## A barely visible tint per tool, stable between runs.
func _tint_for(mi: MeshInstance3D) -> Color:
	var n := _body_of(mi)
	if n is StaticBody3D:
		return TRAY_TINT
	var key := String(n.name if n else mi.name).get_slice("_0", 0)
	return Color.from_hsv(float(absi(hash(key)) % 360) / 360.0, 0.04, 1.0)


func _apply(v: Dictionary) -> void:
	var use_shader: bool = v.get("shader", true)
	var params: Dictionary = base_params.merged(v.get("params", {}), true)
	for sw in swaps:
		var mat := sw[2] as ShaderMaterial
		for k in params:
			mat.set_shader_parameter(k, params[k])
		(sw[0] as MeshInstance3D).set_surface_override_material(sw[1], mat if use_shader else null)
	var blur := DEFAULT_SHADOW_BLUR if settings.is_empty() else float(settings.get("shadow_radius", 1.5)) * 0.67
	sun.shadow_blur = v.get("shadow_blur", blur)
	cam.transform = pairs_cam_xform if v.get("pairs", false) else game_cam_xform
	if v.get("close", false):
		cam.transform = game_cam_xform.translated_local(Vector3(0.0, 0.0, -0.3))


func _capture() -> void:
	if not pile_path.is_empty():
		_export_pile()
	for v in variants:
		_apply(v)
		for i in 4:
			await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path(out_dir).path_join(String(v["name"]) + ".png")
		get_viewport().get_texture().get_image().save_png(path)
	print("shader_lab: saved %d images to %s" % [variants.size(), ProjectSettings.globalize_path(out_dir)])
	if make_gif:
		await _capture_gif()
	get_tree().quit()


## The settled pile as JSON for the browser shader lab: every model (glb) with its world matrix
## (column-major, like three.js Matrix4), plus the game camera and the lamp direction.
func _export_pile() -> void:
	var models: Array = []
	_collect_models(self, models)
	var to_light := sun.global_transform.basis.z
	var data := {
		"models": models,
		"camera": {"matrix": _mat(game_cam_xform), "fov": cam.fov, "keep_width": cam.keep_aspect == Camera3D.KEEP_WIDTH},
		"light_dir": [to_light.x, to_light.y, to_light.z],
		"floor_y": -tray_half.y,
	}
	var f := FileAccess.open(pile_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("shader_lab: pile with %d models saved to %s" % [models.size(), pile_path])


func _collect_models(node: Node, out: Array) -> void:
	var n3 := node as Node3D
	if n3 and node.scene_file_path.ends_with(".glb"):
		var body := node.get_parent()
		if not (body is RigidBody3D and pair_bodies.has(body)):
			out.append({"glb": node.scene_file_path.get_file(), "matrix": _mat(n3.global_transform),
					"body": String(body.name) if body else ""})
		return
	for c in node.get_children():
		_collect_models(c, out)


func _mat(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, 0.0, b.y.x, b.y.y, b.y.z, 0.0, b.z.x, b.z.y, b.z.z, 0.0, t.origin.x, t.origin.y, t.origin.z, 1.0]


## Frames for a GIF: the lineup seen from the game's camera angle, each tool rocking across its
## width, so the glint slides over it. Saved as <out>/gif/fNN.png.
func _capture_gif() -> void:
	_apply({})
	# Same angle as the game camera, moved over the lineup and halfway in.
	cam.transform = game_cam_xform.translated(Vector3(PAIRS_X, 0.0, 0.0)).translated_local(Vector3(0.0, 0.0, -0.33))
	var dir := ProjectSettings.globalize_path(out_dir).path_join("gif")
	DirAccess.make_dir_recursive_absolute(dir)
	var rest: Array[Transform3D] = []
	for b in pair_bodies:
		rest.append(b.transform)
	for f in GIF_FRAMES:
		var t := float(f) / GIF_FRAMES * TAU
		for i in pair_bodies.size():
			var b := pair_bodies[i]
			b.transform = rest[i].translated(Vector3(0.0, 0.012, 0.0))
			b.rotate(Vector3.RIGHT, sin(t + i * 0.7) * 0.35)
		for k in 2:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("f%02d.png" % f))
	print("shader_lab: saved %d gif frames to %s" % [GIF_FRAMES, dir])
