class_name LevelResult
extends CanvasLayer
## End-of-level card: time, wrong hand-offs and hints, the score (ScoreBoard), and a name field
## to save it. After saving it shows the rank, with buttons to the leaderboard, play again or menu.
## The level adds it with show_run() when the last tray is done.

signal play_again_pressed

const MAIN_MENU := "res://ui/main_menu.tscn"
const LEADERBOARD := "res://ui/leaderboard.tscn"

var _level: LevelData
var _seconds := 0.0
var _wrong := 0
var _hints := 0

@onready var _name: LineEdit = %NameEdit


func _ready() -> void:
	(%SaveButton as Button).pressed.connect(_save)
	_name.text_submitted.connect(func(_text: String) -> void: _save())
	(%LeaderboardButton as Button).pressed.connect(_open_leaderboard)
	(%PlayAgainButton as Button).pressed.connect(play_again_pressed.emit)
	(%MenuButton as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	for button in find_children("*", "BaseButton", true, false):
		button.pressed.connect(get_node(^"/root/UiSounds/Click").play)
	(%RankLabel as Label).hide()


func show_run(level: LevelData, seconds: float, wrong: int, hints: int) -> void:
	_level = level
	_seconds = seconds
	_wrong = wrong
	_hints = hints
	(%TimeValue as Label).text = ScoreBoard.format_time(seconds)
	(%WrongValue as Label).text = "%d  (+%d s)" % [wrong, int(wrong * ScoreBoard.WRONG_PENALTY)]
	(%HintsValue as Label).text = "%d  (+%d s)" % [hints, int(hints * ScoreBoard.HINT_PENALTY)]
	(%ScoreValue as Label).text = ScoreBoard.format_time(ScoreBoard.score(seconds, wrong, hints))
	_name.text = ScoreBoard.last_name()


func _save() -> void:
	if not (%NameRow as Control).visible:
		return
	var result := ScoreBoard.submit(_level, _name.text, _seconds, _wrong, _hints)
	(%NameRow as Control).hide()
	(%SaveButton as Control).hide()
	var rank := %RankLabel as Label
	rank.text = "Rank %d of %d%s" % [result["rank"], result["count"], "\nNew best!" if result["new_best"] else ""]
	rank.show()


func _open_leaderboard() -> void:
	_save()
	ScoreBoard.focus_level_key = ScoreBoard.level_key(_level)
	get_tree().paused = false
	get_tree().change_scene_to_file(LEADERBOARD)
