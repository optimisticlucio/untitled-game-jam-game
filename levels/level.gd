extends Node3D
## Plays one level: fills the tray, shows the doctor's requests next to the
## hand-off square, checks what's handed over, and reshuffles the tray as the
## LevelData says.

## The screen shape the scene is laid out for. Wider screens get bars of
## extra table at the sides instead of losing the top and bottom.
const DESIGN_ASPECT := 9.0 / 16.0
const LEVEL_RESULT := preload("res://ui/level_result.tscn")

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
## Seconds since the grabber was last busy: holding a tool, or one flying (back to the tray after
## a drop or a wrong hand-off). Starts at infinity: before the first grab there's nothing to wait for.
var _since_busy := INF
## Whether a hint glows now. The surgeon waits impatiently (finger snaps) for as long.
var _hint_shown := false:
	set(value):
		_hint_shown = value
		_surgeon.impatient = value
## Whether the current request has been hinted yet (the tutorial's first hint
## for a request comes at once).
var _hinted_this_request := false
var _hint_elapsed := 0.0
## For the score (Scoring); the tutorial tray isn't recorded.
var _run := RunRecord.new()
## Seconds the player has had for the next hand-off (see RunRecord): since the last one, only
## while a request is live and the tray can be picked from.
var _pick_seconds := 0.0
## Seconds the current request has waited for the right tool (for the heart monitor).
var _request_wait := 0.0

@onready var _camera: Camera3D = $Camera3D
## The camera's horizontal field of view at DESIGN_ASPECT, as set in the scene.
@onready var _design_fov := _camera.fov
@onready var _tray: Tray = $Tray
@onready var _grabber: ToolGrabber = $ToolGrabber
@onready var _surgeon: Surgeon = $Surgeon
@onready var _request: Control = %Request
@onready var _preview: ToolPreview = %ToolPreview
@onready var _preview_circle: Control = %PreviewCircle
@onready var _bubble_tail: Node2D = %Tail
@onready var _request_name: Label = %RequestName
@onready var _popup: Control = %Popup
@onready var _message: Label = %Message
@onready var _hud: Hud = $Hud
@onready var _monitor: HeartMonitor = $Sounds/Monitor


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	for button in $UI.find_children("*", "BaseButton", true, false):
		button.pressed.connect(get_node(^"/root/UiSounds/Play").play)
	if LevelList.chosen:
		level = LevelList.chosen
	_scenes = SurgicalTool.scenes_by_id()
	var problems := level.problems(_scenes.keys()) if level else PackedStringArray(["No LevelData set on the level scene."])
	if not problems.is_empty():
		for problem in problems:
			push_error("Level %s: %s" % [level.resource_path if level else "", problem])
		_show_message("This level can't start:\n" + "\n".join(problems))
		return
	_grabber.tool_handed.connect(_on_tool_handed)
	_trays = level.plan_trays()
	_request.hide()
	_tray.place_away()
	_bring_in_tray()


func _process(delta: float) -> void:
	_since_request += delta
	_since_busy = 0.0 if _grabber.is_busy() else _since_busy + delta
	if _requested != &"" and _grabber.enabled:
		_pick_seconds += delta
		_request_wait += delta
	# Calm in the tutorial, and while nothing is asked for.
	_monitor.waiting_seconds = _request_wait if _requested != &"" and not _in_tutorial() else 0.0
	if _hint_shown:
		_hint_elapsed += delta
		if level.hint_duration_seconds > 0.0 and _hint_elapsed >= level.hint_duration_seconds:
			# Out again, and the request delay starts over.
			_grabber.clear_hints()
			_hint_shown = false
			_since_request = 0.0
	elif _hint_due():
		_show_hint()


## The tutorial tray, when the level has one, is the first: only its own
## tools, and the clock waits for the tray after it.
func _in_tutorial() -> bool:
	return level.has_tutorial() and _tray_index == 0


## Fills the tray while it's off screen, lets the tools settle there, then
## slides it in. Grabbing, requests and the clock start once it's in place.
func _bring_in_tray() -> void:
	_grabber.enabled = false
	_queue.assign(_trays[_tray_index])
	var distractors: Array[StringName] = []
	if not _in_tutorial():
		distractors = level.draw_distractors()
	var tools: Array[SurgicalTool] = []
	for id in _queue + distractors:
		var tool: SurgicalTool = _scenes[id].instantiate()
		tool.resize(level.tool_size_percent / 100.0)
		tools.append(tool)
	_tray.fill(tools)
	await _tray.settle()
	$Sounds/TraySlide.play()
	await _tray.slide_back()
	_grabber.enabled = true
	if not _in_tutorial() and not _hud.clock_running:
		_hud.start_clock()
	_request_next()


func _request_next() -> void:
	_grabber.clear_hints()
	_hint_shown = false
	if _queue.is_empty():
		_finish_tray()
		return
	_requested = _queue.pop_front()
	_since_request = 0.0
	_request_wait = 0.0
	_hinted_this_request = false
	var example: SurgicalTool = _tray.tools().filter(func(t: SurgicalTool) -> bool: return t.id == _requested)[0]
	_request_name.text = tr(example.display_name)
	_preview_circle.visible = not level.name_only_ids.has(_requested)
	if _preview_circle.visible:
		_preview.show_tool(_scenes[_requested])
	_fit_request()


## The bubble keeps its width (it's anchored across the top) and fits its height to the content.
## That waits a frame, until the layout knows how many lines the wrapped name takes.
func _fit_request() -> void:
	# Layout only runs on visible controls (the bubble is hidden while a tray
	# slides in), so lay it out invisibly for that frame, then fit and reveal.
	_request.modulate.a = 0.0
	_request.show()
	await get_tree().process_frame
	if _requested == &"":
		return
	_request.offset_bottom = _request.offset_top + _request.get_combined_minimum_size().y
	_shape_tail()
	_request.modulate.a = 1.0
	$Sounds/Request.play()


## The bubble's tail, fitted to the bubble's height (short with the name only, tall with the tool's
## picture). It's drawn over the bubble: two black lines that start on the bubble's outline (on its
## left side, above the grey bottom edge) and meet at the tip, towards the doctor, with white
## between them that covers the outline there and runs a little into the bubble's white.
func _shape_tail() -> void:
	var style := _request.get_theme_stylebox(&"panel") as StyleBoxFlat
	var border := float(style.border_width_left) if style else 7.0
	var corner := float(style.corner_radius_top_left) if style else 46.0
	var h := _request.size.y
	var mouth_bottom := h - corner - 2.0
	var mouth_top := maxf(mouth_bottom - 46.0, border * 3.0)
	var top := Vector2(_outline_x(mouth_top, h, corner, border), mouth_top)
	var bottom := Vector2(_outline_x(mouth_bottom, h, corner, border), mouth_bottom)
	var tip := Vector2(-70.0, minf(h + 4.0, mouth_bottom + 40.0))
	var inside := Vector2(border + 4.0, 0.0)
	(_bubble_tail.get_node(^"Fill") as Polygon2D).polygon = PackedVector2Array([top, tip, bottom, bottom + inside, top + inside])
	var outline := _bubble_tail.get_node(^"Outline") as Line2D
	outline.width = border
	outline.points = PackedVector2Array([top, tip, bottom])


## x of the middle of the bubble's outline on its left side, at height y (it curves at the corners).
func _outline_x(y: float, h: float, corner: float, border: float) -> float:
	var r := corner - border / 2.0
	if y < corner:
		return corner - sqrt(maxf(r * r - (corner - y) * (corner - y), 0.0))
	if y > h - corner:
		return corner - sqrt(maxf(r * r - (y - h + corner) * (y - h + corner), 0.0))
	return border / 2.0


func _finish_tray() -> void:
	_tray_index += 1
	if _tray_index >= _trays.size():
		$Sounds/Complete.play()
		_show_result()
		return
	_request.hide()
	_grabber.enabled = false
	# A tool still flying back would land after the tray left, and fall out.
	while _grabber.is_busy():
		await get_tree().process_frame
	$Sounds/TraySlide.play()
	await _tray.slide_away()
	_tray.clear()
	_bring_in_tray()


func _on_tool_handed(tool: SurgicalTool) -> void:
	var right := tool.id == _requested
	if not _in_tutorial():
		_run.add_pick(right, _pick_seconds)
	_pick_seconds = 0.0
	if right:
		_requested = &""
		# Gone until the next request shows it.
		_request.hide()
		$Sounds/Correct.play()
		await _grabber.consume(tool)
		_request_next()
	else:
		$Sounds/Wrong.play()
		_grabber.reject(tool)


## A hint waits for both the request delay and a quiet spell after the last
## let-go (or a wrong tool landing back on the tray), and never starts
## mid-grab, so it can't light up something else
## just as the player reaches for a tool. It lasts hint_duration_seconds,
## then the request delay starts over. In the tutorial each request's first
## hint comes at once, so the tool is easy to spot; after that, the same rules.
func _hint_due() -> bool:
	if _in_tutorial() and not _hinted_this_request:
		return _requested != &"" and not _hint_shown and _grabber.enabled
	return (_requested != &"" and not _hint_shown
		and level.hint_delay_seconds > 0.0
		and _since_request >= level.hint_delay_seconds
		and _since_busy >= level.hint_idle_seconds
		and _grabber.enabled and not _grabber.is_busy())


## Hints the copy of the requested tool nearest the top of the pile.
func _show_hint() -> void:
	var best: SurgicalTool
	for tool in _tray.tools():
		if tool.id == _requested and (best == null or tool.global_position.y > best.global_position.y):
			best = tool
	if best:
		_grabber.hint(best)
		$Sounds/Hint.play()
		if not _in_tutorial():
			_run.hints += 1
		_hint_shown = true
		_hinted_this_request = true
		_hint_elapsed = 0.0


func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()


## The end-of-level card: score, name, rank (ui/level_result.tscn, ScoreBoard).
func _show_result() -> void:
	_hud.stop_clock()
	_grabber.enabled = false
	_request.hide()
	var result := LEVEL_RESULT.instantiate() as LevelResult
	add_child(result)
	_run.seconds = _hud.elapsed
	result.show_run(level, _run)
	result.play_again_pressed.connect(_on_play_again_pressed)


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
