class_name LevelResult
extends CanvasLayer
## End-of-level card: time, wrong hand-offs and hints, the score (the level's Scoring) and how
## it's made, and a name field to save it (ScoreBoard). After saving it shows the rank, with buttons to the leaderboard, play again or menu.
## The run is saved as soon as the card shows, under the last name used on this device ("You" at
## first), so a played level is never forgotten. Saving, or leaving, with another name in the field
## moves the run to that name.
## The level adds it with show_run() when the last tray is done.

signal play_again_pressed

const MAIN_MENU := "res://ui/main_menu.tscn"
const LEADERBOARD := "res://ui/leaderboard.tscn"

var _level: LevelData
var _run: RunRecord
## ScoreBoard.submit()'s result for where the run is saved now.
var _submitted: Dictionary
## Save was pressed: the name is final and the rank shown.
var _confirmed := false

@onready var _name: LineEdit = %NameEdit


func _ready() -> void:
	(%SaveButton as Button).pressed.connect(_save)
	_name.text_submitted.connect(func(_text: String) -> void: _save())
	_name.text_changed.connect(func(_text: String) -> void: get_node(^"/root/UiSounds/Key").play())
	(%LeaderboardButton as Button).pressed.connect(_open_leaderboard)
	(%PlayAgainButton as Button).pressed.connect(play_again_pressed.emit)
	(%MenuButton as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	var sounds := {%SaveButton: ^"", %PlayAgainButton: ^"/root/UiSounds/Play", %MenuButton: ^"/root/UiSounds/Back"}
	for button in find_children("*", "BaseButton", true, false):
		var sound: NodePath = sounds.get(button, ^"/root/UiSounds/Click")
		if not sound.is_empty():  # Save plays its own sound in _save(), Enter in the name field too.
			button.pressed.connect(get_node(sound).play)
	(%RankLabel as Label).hide()


func show_run(level: LevelData, run: RunRecord) -> void:
	_level = level
	_run = run
	var scoring := ScoreBoard.scoring_for(level)
	(%TimeValue as Label).text = ScoreBoard.format_time(run.seconds)
	(%WrongValue as Label).text = str(run.wrong_count())
	(%HintsValue as Label).text = str(run.hints)
	(%ScoreValue as Label).text = scoring.format_score(scoring.score(run))
	(%ScoreHint as Label).text = scoring.explanation()
	# Filled in with the name it's saved under, so it's clear typing one is optional.
	_name.text = ScoreBoard.clean_name(ScoreBoard.last_name())
	_submitted = ScoreBoard.submit(level, _name.text, run)


func _exit_tree() -> void:
	if _run and not _confirmed:
		_save_under_typed_name()


func _save() -> void:
	if _confirmed:
		return
	_confirmed = true
	get_node(^"/root/UiSounds/Save").play()
	var result := _save_under_typed_name()
	(%NameRow as Control).hide()
	(%SaveButton as Control).hide()
	var rank := %RankLabel as Label
	rank.text = "Rank %d of %d%s" % [result["rank"], result["count"], "\nNew best!" if result["new_best"] else ""]
	rank.show()


## Moves the run to the name in the field, if that's not where it's saved. Returns where it's saved.
func _save_under_typed_name() -> Dictionary:
	if ScoreBoard.clean_name(_name.text) != _submitted["name"]:
		ScoreBoard.withdraw(_level, _submitted)
		_submitted = ScoreBoard.submit(_level, _name.text, _run)
	return _submitted


func _open_leaderboard() -> void:
	_save()
	ScoreBoard.focus_level_key = ScoreBoard.level_key(_level)
	get_tree().paused = false
	get_tree().change_scene_to_file(LEADERBOARD)
