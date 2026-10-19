class_name LevelSelect
extends Control
## Level selector: every level in LevelList, in order, all open. Each card shows the level's
## title and the best saved score of the name entered last (ScoreBoard). Tapping one plays it.

const MAIN_MENU := "res://ui/main_menu.tscn"
const LEVEL_SCENE := "res://levels/level.tscn"

@onready var _cards: VBoxContainer = %Cards


func _ready() -> void:
	(%BackButton as Button).pressed.connect(_back)
	var you := ScoreBoard.last_name()
	for level in LevelList.all():
		_cards.add_child(_card(level, you))
	for button in find_children("*", "BaseButton", true, false):
		if button != %BackButton:  # It plays the back sound in _back().
			var sound := ^"/root/UiSounds/Play" if button.get_parent() == _cards else ^"/root/UiSounds/Click"
			button.pressed.connect(get_node(sound).play)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _back() -> void:
	get_node(^"/root/UiSounds/Back").play()
	get_tree().change_scene_to_file(MAIN_MENU)


func _play(level: LevelData) -> void:
	LevelList.chosen = level
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _card(level: LevelData, you: String) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 160)
	card.pressed.connect(_play.bind(level))
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Inside the painted button: clear of its outline, and of the dark band along its bottom.
	column.offset_left = 34.0
	column.offset_top = 14.0
	column.offset_right = -34.0
	column.offset_bottom = -26.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var title := Label.new()
	title.text = level.display_title()
	title.theme_type_variation = &"CardTitle"
	# Trimmed, not wrapped, so a long title can't push the card past the screen edge.
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title)
	var best := Label.new()
	best.text = _best_text(level, you)
	best.theme_type_variation = &"CardInfo"
	column.add_child(best)
	return card


func _best_text(level: LevelData, you: String) -> String:
	var run := ScoreBoard.best(level, you)
	if run.is_empty():
		return tr("Not played yet")
	var scoring := ScoreBoard.scoring_for(level)
	return tr("Best: %s · %s") % [scoring.format_score(run["score"]), ScoreBoard.format_time(run["seconds"])]
