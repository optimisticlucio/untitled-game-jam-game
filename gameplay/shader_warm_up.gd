extends Node
## Autoload. Compiles the level's shaders while the game boots, so the first level doesn't
## freeze for seconds when the tray first comes into view.
##
## The Compatibility renderer compiles a shader (one variant per lighting setup) the first time
## something drawn with it is on screen, and blocks while it does. Godot keeps compiled shaders in
## user://shader_cache, so only the very first launch pays; this moves that cost to the first
## frame, which the boot splash covers. It draws, invisibly, the level's own 3D scene (its lights,
## environment, tray and the grabber's highlight warm-up) with every tool on the tray, and a
## request preview, then frees it all. Using level.tscn itself keeps it in step with the level.

const LEVEL_SCENE := "res://levels/level.tscn"
const PREVIEW_SCENE := "res://ui/tool_preview.tscn"
## Frames to draw before freeing it: enough to be sure everything was drawn once.
const FRAMES := 3


func _ready() -> void:
	# Nothing compiles without a screen (headless dev scripts and tests).
	if DisplayServer.get_name() == "headless":
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(90, 160)
	viewport.own_world_3d = true
	viewport.msaa_3d = get_viewport().msaa_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.audio_listener_enable_3d = false
	add_child(viewport)
	var level := _level_visuals()
	if level == null:
		viewport.queue_free()
		return
	viewport.add_child(level)
	var tray := level.get_node(^"Tray") as Tray
	for scene in SurgicalTool.scenes_by_id().values():
		var tool := scene.instantiate() as SurgicalTool
		tool.freeze = true
		tray.tools_root.add_child(tool)
	var preview := (load(PREVIEW_SCENE) as PackedScene).instantiate() as ToolPreview
	viewport.add_child(preview)
	if not SurgicalTool.scenes_by_id().is_empty():
		preview.show_tool(SurgicalTool.scenes_by_id().values()[0])
	for i in FRAMES:
		await get_tree().process_frame
	viewport.queue_free()


## level.tscn without its script, UI or sounds: only the 3D scene and the grabber (which warms
## the highlight shaders itself).
func _level_visuals() -> Node3D:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate() as Node3D
	if level == null:
		return null
	level.set_script(null)
	for child in level.get_children():
		if child is ToolGrabber:
			child.enabled = false
		elif not child is Node3D:
			level.remove_child(child)
			child.free()
	return level
