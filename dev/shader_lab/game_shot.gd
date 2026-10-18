extends Node
## Screenshots of the real game: the main scene's first tray, then the next tray, to check that
## every tray gets a new look. Run with a window:
##   Godot --path <repo> res://dev/shader_lab/game_shot.tscn -- --out=<folder>

var out_dir := "user://game_shot"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var level: Node = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	add_child(level)
	await get_tree().create_timer(3.5).timeout
	_save("tray_1")
	if level.has_method("_finish_tray"):
		level.call("_finish_tray")
		await get_tree().create_timer(4.0).timeout
		_save("tray_2")
	get_tree().quit()


func _save(name: String) -> void:
	var path := ProjectSettings.globalize_path(out_dir).path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("game_shot: saved ", path)
