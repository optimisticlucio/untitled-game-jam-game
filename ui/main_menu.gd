class_name MainMenu
extends Control
## Home screen: Play, Pocket Guide, Leaderboard, Settings. Placeholder art (ui/theme.tres,
## ui/icons/). Level select and the leaderboard aren't built yet: Play emits play_pressed and opens
## play_scene (set to levels/level.tscn for now); Leaderboard shows "coming soon".

signal play_pressed

const POCKET_GUIDE := "res://ui/pocket_guide.tscn"

## Scene Play opens, until level select exists. Empty: only play_pressed is emitted.
@export_file("*.tscn") var play_scene := ""

var _toast_tween: Tween

@onready var _settings_sheet: BottomSheet = %SettingsSheet
@onready var _toast: Control = %Toast


func _ready() -> void:
	SettingsPanel.apply_saved()
	(%PlayButton as Button).pressed.connect(_on_play)
	(%GuideButton as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file(POCKET_GUIDE))
	(%LeaderboardButton as Button).pressed.connect(_show_toast.bind("Leaderboard: coming soon"))
	(%SettingsButton as Button).pressed.connect(_settings_sheet.toggle)
	(%CloseSettingsButton as Button).pressed.connect(_settings_sheet.toggle)
	_toast.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_sheet.is_open:
		_settings_sheet.toggle()
		get_viewport().set_input_as_handled()


func _on_play() -> void:
	play_pressed.emit()
	if not play_scene.is_empty():
		get_tree().change_scene_to_file(play_scene)
	elif play_pressed.get_connections().is_empty():
		_show_toast("Level select: coming soon")


func _show_toast(text: String) -> void:
	(%ToastLabel as Label).text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
