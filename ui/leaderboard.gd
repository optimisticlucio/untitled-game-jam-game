class_name LeaderboardScreen
extends Control
## Leaderboard: one board per level (picked at the top), best score first. Rows saved on this
## device are highlighted; sample rivals are marked "sample". Each row shows the time too, but
## the order is the level's Scoring. Scores: ScoreBoard.

const MAIN_MENU := "res://ui/main_menu.tscn"

var _levels: Array[LevelData]

@onready var _picker: OptionButton = %LevelPicker
@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	(%BackButton as Button).pressed.connect(_back)
	for button in find_children("*", "BaseButton", true, false):
		button.pressed.connect(get_node(^"/root/UiSounds/Click").play)
	_levels = LevelList.all()
	for level in _levels:
		_picker.add_item(level.display_title())
		if ScoreBoard.level_key(level) == ScoreBoard.focus_level_key:
			_picker.select(_picker.item_count - 1)
	_picker.item_selected.connect(func(_index: int) -> void: _show_board())
	_show_board()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _show_board() -> void:
	for child in _rows.get_children():
		child.queue_free()
	if _picker.item_count == 0:
		return
	var level := _levels[_picker.selected]
	var scoring := ScoreBoard.scoring_for(level)
	var you := ScoreBoard.last_name()
	var rank := 0
	for entry in ScoreBoard.entries(level):
		rank += 1
		_rows.add_child(_row(rank, entry, scoring, not entry["sample"] and entry["name"] == you))


func _row(rank: int, entry: Dictionary, scoring: Scoring, is_you: bool) -> Control:
	var row := PanelContainer.new()
	row.theme_type_variation = &"TealPanel" if is_you else &"CardPanel"
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	row.add_child(line)
	var place := Label.new()
	place.text = str(rank)
	place.custom_minimum_size = Vector2(60, 0)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_child(place)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_constant_override("separation", 0)
	line.add_child(who)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	who.add_child(top)
	var name := Label.new()
	name.text = entry["name"]  # at most ScoreBoard.MAX_NAME_LENGTH characters, so it fits
	top.add_child(name)
	if entry["sample"]:
		var tag := Label.new()
		tag.text = "sample"
		tag.theme_type_variation = &"SmallLabel"
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(tag)
	var detail := Label.new()
	detail.theme_type_variation = &"SmallLabel"
	detail.text = "%s · %d wrong · %d %s" % [ScoreBoard.format_time(entry["seconds"]), entry["wrong"],
		entry["hints"], "hint" if entry["hints"] == 1 else "hints"]
	# Trimmed, not wrapped, so a long line can't push the row past the screen edge.
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(detail)
	var score := Label.new()
	score.text = scoring.format_score(entry["score"])
	score.theme_type_variation = &"HeaderLabel"
	line.add_child(score)
	return row
