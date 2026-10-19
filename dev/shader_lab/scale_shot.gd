extends Node
## Screenshots for checking that the look doesn't depend on screen size or tool size: the level's
## tray, then the smallest and the largest tool held side by side (neon outline, glow and stars)
## with a hinted tool in the tray, then the request bubble. Run it with a window at several sizes
## and compare; the pictures should match apart from sharpness:
##   Godot --path <repo> --resolution 720x1280 res://dev/shader_lab/scale_shot.tscn -- --out=<folder>
## The held tools also show whether the band is equally thick on a small and a big tool.

const LEVEL_SCENE := "res://levels/level.tscn"
const OUTLINE := preload("res://gameplay/held_neon_outline.tres")
const GLOW := preload("res://gameplay/held_neon_glow.tres")

var out_dir := "user://scale_shot"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		# Try other held-highlight widths without saving them: --outline-width=0.002 --glow-width=0.008
		if a.begins_with("--outline-width="):
			OUTLINE.set_shader_parameter("width", float(a.get_slice("=", 1)))
		if a.begins_with("--glow-width="):
			GLOW.set_shader_parameter("width", float(a.get_slice("=", 1)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	seed(7)
	var level: Node = (load(LEVEL_SCENE) as PackedScene).instantiate()
	add_child(level)
	await get_tree().create_timer(3.5).timeout
	var grabber := level.get_node("ToolGrabber")
	var camera := level.get_node("Camera3D") as Camera3D
	var tray := level.get("_tray") as Node3D
	# The level's own tools plus a tiny one, a long one and a silly one, to compare sizes.
	var scenes := SurgicalTool.scenes_by_id()
	for id in [&"acland_clamp", &"army_navy", &"rubber_duck"]:
		if scenes.has(id) and not tray.get_node("Tools").get_children().any(func(t: SurgicalTool) -> bool: return t.id == id):
			tray.get_node("Tools").add_child(scenes[id].instantiate())
	var tools: Array = tray.get_node("Tools").get_children()
	# The pile differs from run to run, so lay the tools out in rows instead, frozen, sorted by id:
	# every size then shows the same scene.
	tools.sort_custom(func(a: SurgicalTool, b: SurgicalTool) -> bool: return String(a.id) < String(b.id))
	var floor_y := (tray.get("tools_root") as Node3D).global_position.y
	var centre := tray.global_position
	for i in tools.size():
		var tool := tools[i] as SurgicalTool
		tool.freeze = true
		tool.global_rotation = Vector3(0.0, PI * 0.5, 0.0)
		var z := lerpf(-0.16, 0.16, float(i) / maxf(tools.size() - 1, 1))
		tool.global_position = Vector3(centre.x + (0.03 if i % 2 else -0.03), floor_y + 0.01, centre.z + z)
	await get_tree().create_timer(0.5).timeout
	await _save("tray")
	print("scale_shot: tools ", tools.map(func(t: SurgicalTool) -> StringName: return t.id))

	tools.sort_custom(func(a: SurgicalTool, b: SurgicalTool) -> bool:
		return a.visual_bounds().size.length() < b.visual_bounds().size.length())
	var size := get_viewport().get_visible_rect().size
	var lift: float = grabber.get("lift_height")
	var held := {tools[0]: Vector2(0.3, 0.42), tools[-1]: Vector2(0.68, 0.42)}
	for tool: SurgicalTool in held:
		grabber.call("_make_intangible", tool)
		grabber.call("_set_glow", tool, true)
		var screen: Vector2 = held[tool] * size
		var plane := Plane(Vector3.UP, (tray.get("tools_root") as Node3D).global_position.y + lift)
		var hit: Variant = plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
		tool.global_position = hit
		tool.global_rotation = Vector3(0.0, PI * 0.5, 0.0)
	grabber.call("hint", tools[tools.size() / 2])
	# The held look on a tool resting on the cloth too (resting tools may get it as their hint).
	var resting: SurgicalTool = tools.filter(func(t: SurgicalTool) -> bool: return t.id == &"kelly_clamp").front()
	if resting:
		grabber.call("_set_glow", resting, true)
	await get_tree().create_timer(1.2).timeout
	await _save("held")
	print("scale_shot: held ", tools[0].id, " and ", tools[-1].id, ", hinted ", tools[tools.size() / 2].id)

	for tool: SurgicalTool in held.keys() + [resting]:
		if tool:
			grabber.call("_set_glow", tool, false)
	var circle := level.get("_preview_circle") as Control
	for i in 6:
		if circle == null or circle.visible:
			break
		level.call("_request_next")
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.5).timeout
	await _save("bubble")
	get_tree().quit()


func _save(name: String) -> void:
	# A fresh frame, not the last one shown (a hidden window may not have drawn for a while).
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(out_dir).path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("scale_shot: saved ", path, " ", get_viewport().get_texture().get_size())
