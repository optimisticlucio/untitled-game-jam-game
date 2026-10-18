extends Node3D
## Plays one level: fills the tray, shows the doctor's requests next to the
## hand-off square, checks what's handed over, and reshuffles the tray as the
## LevelData says.

## The screen shape the scene is laid out for. Wider screens get bars of
## extra table at the sides instead of losing the top and bottom.
const DESIGN_ASPECT := 9.0 / 16.0

@export var level: LevelData

var _scenes: Dictionary[StringName, PackedScene]
## Requests for each tray, in play order.
var _trays: Array[Array] = []
var _tray_index := 0
## Requests still to come on the current tray.
var _queue: Array[StringName] = []
## Empty while no request is live (between requests and during reshuffles).
var _requested: StringName
var _since_request := 0.0
## Starts at infinity: before the first let-go there's nothing to wait for.
var _since_release := INF
var _hint_shown := false
var _hint_elapsed := 0.0

@onready var _camera: Camera3D = $Camera3D
## The camera's horizontal field of view at DESIGN_ASPECT, as set in the scene.
@onready var _design_fov := _camera.fov
@onready var _tray: Tray = $Tray
@onready var _grabber: ToolGrabber = $ToolGrabber
@onready var _request: Control = %Request
@onready var _preview: ToolPreview = %ToolPreview
@onready var _preview_circle: Control = %PreviewCircle
@onready var _request_name: Label = %RequestName
@onready var _popup: Control = %Popup
@onready var _message: Label = %Message
@onready var _hud: Hud = $Hud


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	_scenes = SurgicalTool.scenes_by_id()
	var problems := level.problems(_scenes.keys()) if level else PackedStringArray(["No LevelData set on the level scene."])
	if not problems.is_empty():
		for problem in problems:
			push_error("Level %s: %s" % [level.resource_path if level else "", problem])
		_show_message("This level can't start:\n" + "\n".join(problems))
		return
	_grabber.tool_handed.connect(_on_tool_handed)
	_grabber.tool_released.connect(func(_tool: SurgicalTool) -> void: _since_release = 0.0)
	_trays = level.plan_trays()
	_start_tray()
	_hud.start_clock()


func _process(delta: float) -> void:
	_since_request += delta
	_since_release += delta
	if _hint_shown:
		_hint_elapsed += delta
		if level.hint_duration_seconds > 0.0 and _hint_elapsed >= level.hint_duration_seconds:
			# Out again, and the request delay starts over.
			_grabber.clear_hints()
			_hint_shown = false
			_since_request = 0.0
	elif _hint_due():
		_show_hint()


func _start_tray() -> void:
	_queue.assign(_trays[_tray_index])
	var tools: Array[SurgicalTool] = []
	for id in _queue + level.draw_distractors():
		var tool: SurgicalTool = _scenes[id].instantiate()
		tool.resize(level.tool_size_percent / 100.0)
		tools.append(tool)
	_tray.fill(tools)
	_request_next()


func _request_next() -> void:
	_grabber.clear_hints()
	if _queue.is_empty():
		_finish_tray()
		return
	_requested = _queue.pop_front()
	_since_request = 0.0
	_hint_shown = false
	var example: SurgicalTool = _tray.tools().filter(func(t: SurgicalTool) -> bool: return t.id == _requested)[0]
	_request_name.text = tr(example.display_name)
	_preview_circle.visible = not level.name_only_ids.has(_requested)
	if _preview_circle.visible:
		_preview.show_tool(_scenes[_requested])
	_fit_request()


## The bubble keeps its width (it's anchored across the top) and fits its height to the content.
## That waits a frame, until the layout knows how many lines the wrapped name takes.
func _fit_request() -> void:
	await get_tree().process_frame
	if _requested == &"":
		return
	_request.offset_bottom = _request.offset_top + _request.get_combined_minimum_size().y
	_request.show()


func _finish_tray() -> void:
	_tray_index += 1
	if _tray_index >= _trays.size():
		_show_message("Level complete!")
		return
	_request.hide()
	_grabber.enabled = false
	# A tool still flying back would land after the tray left, and fall out.
	while _grabber.is_busy():
		await get_tree().process_frame
	await _tray.slide_away()
	_tray.clear()
	await _tray.slide_back()
	_grabber.enabled = true
	_start_tray()


func _on_tool_handed(tool: SurgicalTool) -> void:
	if tool.id == _requested:
		_requested = &""
		await _grabber.consume(tool)
		_request_next()
	else:
		_grabber.reject(tool)


## A hint waits for both the request delay and a quiet spell after the last
## let-go, and never starts mid-grab, so it can't light up something else
## just as the player reaches for a tool. It lasts hint_duration_seconds,
## then the request delay starts over.
func _hint_due() -> bool:
	return (_requested != &"" and not _hint_shown
		and level.hint_delay_seconds > 0.0
		and _since_request >= level.hint_delay_seconds
		and _since_release >= level.hint_idle_seconds
		and _grabber.enabled and not _grabber.is_busy())


## Hints the copy of the requested tool nearest the top of the pile.
func _show_hint() -> void:
	var best: SurgicalTool
	for tool in _tray.tools():
		if tool.id == _requested and (best == null or tool.global_position.y > best.global_position.y):
			best = tool
	if best:
		_grabber.hint(best)
		_hint_shown = true
		_hint_elapsed = 0.0


func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()


func _show_message(text: String) -> void:
	_hud.stop_clock()
	_grabber.enabled = false
	_message.text = text
	_request.hide()
	_popup.show()


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
