class_name MainMenu
extends Control
## Home screen: Play, Pocket Guide, Leaderboard, Settings. Placeholder art (ui/theme.tres,
## ui/icons/). Play emits play_pressed and opens play_scene (the level selector,
## ui/level_select.tscn). Leaderboard opens ui/leaderboard.tscn.

signal play_pressed

const POCKET_GUIDE := "res://ui/pocket_guide.tscn"
const LEADERBOARD := "res://ui/leaderboard.tscn"

## Scene Play opens. Empty: only play_pressed is emitted.
@export_file("*.tscn") var play_scene := ""
## Seconds between a tap and the next screen, so the press and the icon's move can be seen (on a
## phone a tap is over in a moment and the screen would change at once).
@export var leave_delay := 0.22

var _toast_tween: Tween
var _leaving := false

@onready var _settings_sheet: BottomSheet = %SettingsSheet
@onready var _toast: Control = %Toast


func _ready() -> void:
	SettingsPanel.apply_saved()
	if DisplayServer.is_touchscreen_available():
		_drop_hover(theme)
	ButtonFx.install(get_tree())
	(%PlayButton as Button).pressed.connect(_on_play)
	(%GuideButton as Button).pressed.connect(_go.bind(POCKET_GUIDE))
	(%LeaderboardButton as Button).pressed.connect(func() -> void:
		ScoreBoard.focus_level_key = ""
		_go(LEADERBOARD))
	(%SettingsButton as Button).pressed.connect(_settings_sheet.toggle)
	(%CloseSettingsButton as Button).pressed.connect(_settings_sheet.toggle)
	var sounds := {%PlayButton: ^"/root/UiSounds/Play", %CloseSettingsButton: ^"/root/UiSounds/Back"}
	for button in find_children("*", "BaseButton", true, false):
		button.pressed.connect(get_node(sounds.get(button, ^"/root/UiSounds/Click")).play)
	_toast.modulate.a = 0.0


## Touch screens have no hover, but the last tapped button would stay "hovered" and keep looking
## lighter. There, hover looks like normal. The theme is shared, so this covers every screen.
static func _drop_hover(ui_theme: Theme) -> void:
	for type in [&"Button", &"IconButton"]:
		ui_theme.set_stylebox(&"hover", type, ui_theme.get_stylebox(&"normal", type))
	ui_theme.set_color(&"icon_hover_color", &"BarButton", Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_sheet.is_open:
		_settings_sheet.toggle()
		get_viewport().set_input_as_handled()


func _on_play() -> void:
	play_pressed.emit()
	if not play_scene.is_empty():
		_go(play_scene)
	elif play_pressed.get_connections().is_empty():
		_show_toast("Play: no scene set")


## Opens another screen after leave_delay. Taps in the meantime are ignored, so a double tap can't
## open it twice.
func _go(scene: String) -> void:
	if _leaving:
		return
	_leaving = true
	await get_tree().create_timer(leave_delay).timeout
	get_tree().change_scene_to_file(scene)


func _show_toast(text: String) -> void:
	(%ToastLabel as Label).text = text
	get_node(^"/root/UiSounds/Toast").play()
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
