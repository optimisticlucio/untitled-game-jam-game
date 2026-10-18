extends Node3D
## Test scene for ToolGrabber. Every SurgicalTool scene in the project is laid
## out in the tray, and the target asks for them one at a time in random order.
## Nothing here knows about specific tools: add or remove tool scenes freely.

## Searched recursively for scenes whose root is a SurgicalTool with an id.
@export_dir var tool_folder := SurgicalTool.FOLDER
## Width and depth of the area in the tray that tools are laid out in.
@export var layout_size := Vector2(0.28, 0.40)
## How much neighbouring tools overlap when laid out (0 = just touching).
@export_range(0.0, 0.5) var overlap := 0.15
## Random turn given to each tool when laid out, in degrees either way.
@export var yaw_jitter_degrees := 8.0

## The screen shape the scene is laid out for. Wider screens get bars of
## extra table at the sides instead of losing the top and bottom.
const DESIGN_ASPECT := 9.0 / 16.0

var _requested: SurgicalTool

@onready var _camera: Camera3D = $Camera3D
## The camera's horizontal field of view at DESIGN_ASPECT, as set in the scene.
@onready var _design_fov := _camera.fov
@onready var _tools: Node3D = $Tools
@onready var _grabber: ToolGrabber = $ToolGrabber
@onready var _target: Node3D = $Target
@onready var _preview: ToolPreview = %ToolPreview
@onready var _popup: Control = %Popup
@onready var _message: Label = %Message


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	var tools := _find_tools(tool_folder)
	if tools.is_empty():
		_show_message("No SurgicalTool scenes found in %s" % tool_folder)
		return
	_lay_out(tools)
	_grabber.tool_handed.connect(_on_tool_handed)
	_request_next()


func _process(_delta: float) -> void:
	# Keep the preview beside the target, whatever the screen's aspect ratio.
	var beside := _target.global_position + Vector3(0.13, 0.0, 0.0)
	_preview.position = _camera.unproject_position(beside) - _preview.size * 0.5


## Keeps the whole DESIGN_ASPECT area in view on any screen shape.
func _fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x / size.y <= DESIGN_ASPECT:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.fov = _design_fov
	else:
		_camera.keep_aspect = Camera3D.KEEP_HEIGHT
		var half_width := tan(deg_to_rad(_design_fov) * 0.5)
		_camera.fov = rad_to_deg(2.0 * atan(half_width / DESIGN_ASPECT))


func _on_tool_handed(tool: SurgicalTool) -> void:
	if tool.id == _requested.id:
		await _grabber.consume(tool)
		_request_next()
	else:
		_grabber.return_to_tray(tool)


func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()


func _request_next() -> void:
	var remaining: Array[SurgicalTool] = []
	for child in _tools.get_children():
		if child is SurgicalTool and not child.is_queued_for_deletion():
			remaining.append(child)
	if remaining.is_empty():
		_show_message("Congratulations!")
		return
	_requested = remaining.pick_random()
	_preview.show_tool(load(_requested.scene_file_path))


func _show_message(text: String) -> void:
	_message.text = text
	_preview.hide()
	_popup.show()


## Instances of every SurgicalTool scene under folder.
func _find_tools(folder: String) -> Array[SurgicalTool]:
	var tools: Array[SurgicalTool] = []
	for dir in DirAccess.get_directories_at(folder):
		if not dir.begins_with("."):
			tools.append_array(_find_tools(folder.path_join(dir)))
	for file in DirAccess.get_files_at(folder):
		# Exported builds list scenes as .tscn.remap.
		var path := folder.path_join(file.trim_suffix(".remap"))
		if path.get_extension() != "tscn":
			continue
		var node := (load(path) as PackedScene).instantiate()
		if node is SurgicalTool and node.id != &"":
			tools.append(node)
		else:
			node.free()
	return tools


## Packs the tools into rows, long side across, longest first. When the rows
## run out of depth, the next tools go in a layer on top and fall onto the pile.
func _lay_out(tools: Array[SurgicalTool]) -> void:
	var footprints: Dictionary[SurgicalTool, Vector3] = {}
	var centers: Dictionary[SurgicalTool, Vector3] = {}
	for tool in tools:
		_tools.add_child(tool)
		var bounds := ToolPreview.visual_bounds(tool)
		var yaw := 0.0 if bounds.size.x >= bounds.size.z else PI / 2.0
		yaw += deg_to_rad(randf_range(-yaw_jitter_degrees, yaw_jitter_degrees))
		tool.rotation.y = yaw
		var size := bounds.size
		footprints[tool] = Vector3(maxf(size.x, size.z), size.y, minf(size.x, size.z))
		centers[tool] = bounds.get_center().rotated(Vector3.UP, yaw)
	tools.sort_custom(func(a: SurgicalTool, b: SurgicalTool) -> bool:
		return footprints[a].x > footprints[b].x)

	var x := 0.0
	var z := 0.0
	var row_depth := 0.0
	var height := 0.02
	for tool in tools:
		var size := footprints[tool] * (1.0 - overlap)
		if x > 0.0 and x + size.x > layout_size.x:
			x = 0.0
			z += row_depth
			row_depth = 0.0
		if z > 0.0 and z + size.z > layout_size.y:
			z = 0.0
			height += 0.03
		var slot := Vector3(x + size.x * 0.5 - layout_size.x * 0.5, 0.0, z + size.z * 0.5 - layout_size.y * 0.5)
		var center := centers[tool]
		tool.position = slot - Vector3(center.x, 0.0, center.z) + Vector3.UP * height
		# Staggered so overlapping neighbours don't start inside each other.
		height += 0.004
		x += size.x
		row_depth = maxf(row_depth, size.z)
