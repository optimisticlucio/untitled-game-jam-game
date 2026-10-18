extends Node
## Screenshots of the real game: the level's first tray, then the next tray, to check that every
## tray gets a new look (it also prints the blood layout and some tool tints). Run with a window:
##   Godot --path <repo> res://dev/shader_lab/game_shot.tscn -- --out=<folder>

const LEVEL_SCENE := "res://levels/level.tscn"

var out_dir := "user://game_shot"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var level: Node = (load(LEVEL_SCENE) as PackedScene).instantiate()
	add_child(level)
	await get_tree().create_timer(3.5).timeout
	_report(level)
	_save("tray_1")
	if level.has_method("_finish_tray"):
		level.call("_finish_tray")
		await get_tree().create_timer(8.0).timeout
		_report(level)
		_save("tray_2")
	get_tree().quit()


## The tray's blood layout and the first tools' tints, to show they change between trays.
func _report(level: Node) -> void:
	var tray := level.get("_tray") as Node3D
	var tray_mesh := tray.get_node("Body").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mat := tray_mesh.get_surface_override_material(0) as ShaderMaterial
	var tints: Array[String] = []
	for tool in tray.get_node("Tools").get_children().slice(0, 4):
		var mi := tool.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var tm := mi.get_surface_override_material(0) as ShaderMaterial
		tints.append(tm.get_shader_parameter("tint").to_html(false) if tm else "none")
	print("game_shot: blood cell ", mat.get_shader_parameter("blood_cell"), " flip ", mat.get_shader_parameter("blood_flip"), ", tints ", tints)


func _save(name: String) -> void:
	var path := ProjectSettings.globalize_path(out_dir).path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("game_shot: saved ", path)
