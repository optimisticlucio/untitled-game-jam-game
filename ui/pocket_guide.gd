class_name PocketGuide
extends Control
## Pocket Guide: every SurgicalTool in 3D, grouped by function or by speciality (tabs). Tap a card
## for a big view you can turn with a finger, with the tool's name and notes.
## Tools come from SurgicalTool.scenes_by_id(); nothing here names a specific tool.

const MAIN_MENU := "res://ui/main_menu.tscn"
const TOOL_PREVIEW := preload("res://ui/tool_preview.tscn")
## Indexed by SurgicalTool.Category and SurgicalTool.Speciality.
const CATEGORY_NAMES: Array[String] = ["Cutting", "Grasping", "Clamping", "Retracting", "Suturing", "Other"]
const SPECIALITY_NAMES: Array[String] = ["General", "Hand", "Plastic", "Silly"]
const TAP_SLOP := 24.0

## One per tool: {scene, name, description, category, specialities}.
var _entries: Array[Dictionary] = []

@onready var _tabs: TabBar = %Tabs
@onready var _list: VBoxContainer = %List
@onready var _detail: Control = %Detail
@onready var _viewer: ToolViewer = %Viewer


func _ready() -> void:
	(%BackButton as Button).pressed.connect(_on_back)
	(%CloseDetailButton as Button).pressed.connect(_on_back)
	(%ResetButton as Button).pressed.connect(_viewer.reset_view)
	for button in find_children("*", "BaseButton", true, false):
		if button != %BackButton and button != %CloseDetailButton:  # Those play the back sound in _on_back().
			button.pressed.connect(get_node(^"/root/UiSounds/Click").play)
	_tabs.tab_changed.connect(func(_tab: int) -> void:
		get_node(^"/root/UiSounds/Tab").play()
		_rebuild())
	_entries = _tool_entries()
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["name"] as String).naturalnocasecmp_to(b["name"]) < 0)
	_detail.hide()
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	get_node(^"/root/UiSounds/Back").play()
	if _detail.visible:
		_detail.hide()
	else:
		get_tree().change_scene_to_file(MAIN_MENU)


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	var by_function := _tabs.current_tab == 0
	var names := CATEGORY_NAMES if by_function else SPECIALITY_NAMES
	for i in names.size():
		var group := _entries.filter(func(e: Dictionary) -> bool:
			return e["category"] == i if by_function else i in e["specialities"])
		if group.is_empty():
			continue
		var header := Label.new()
		header.text = names[i]
		header.theme_type_variation = &"SectionTitle"
		_list.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 20)
		_list.add_child(grid)
		for e in group:
			grid.add_child(_card(e))


func _card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var preview := TOOL_PREVIEW.instantiate() as ToolPreview
	preview.custom_minimum_size = Vector2(0, 240)
	preview.degrees_per_second = 12.0
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview)
	preview.show_tool(entry["scene"])
	var label := Label.new()
	label.text = entry["name"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	card.gui_input.connect(_on_card_input.bind(card, entry))
	return card


## A tap opens the tool; a drag (scrolling the list) doesn't.
func _on_card_input(event: InputEvent, card: Control, entry: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var button := event as InputEventMouseButton
	if button.pressed:
		card.set_meta("press", button.global_position)
	elif card.has_meta("press") and button.global_position.distance_to(card.get_meta("press")) < TAP_SLOP:
		card.remove_meta("press")
		_open(entry)


func _open(entry: Dictionary) -> void:
	get_node(^"/root/UiSounds/CardOpen").play()
	_viewer.show_tool(entry["scene"])
	(%DetailName as Label).text = entry["name"]
	var tags: Array[String] = [CATEGORY_NAMES[entry["category"]]]
	for s in entry["specialities"]:
		tags.append(SPECIALITY_NAMES[s])
	(%DetailTags as Label).text = " · ".join(tags)
	(%DetailText as Label).text = entry["description"]
	_detail.show()


func _tool_entries() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for scene: PackedScene in SurgicalTool.scenes_by_id().values():
		var tool := scene.instantiate() as SurgicalTool
		found.append({
			"scene": scene,
			"name": tr(tool.display_name),
			"description": tr(tool.description),
			"category": int(tool.category),
			"specialities": Array(tool.specialities),
		})
		tool.free()
	return found
