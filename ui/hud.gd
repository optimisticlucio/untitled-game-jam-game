class_name Hud
extends CanvasLayer
## In-game HUD (portrait): a bottom bar with Settings (left), a clock counting up (middle) and a
## sound on/off button (right). Settings opens a sheet that slides up from behind the bar, with
## sound and music volume and Exit. The game never pauses.
## Placeholder art: ui/theme.tres and ui/icons/.
##
## For the game scene: instance ui/hud.tscn and call start_clock() when a round starts.
## Exit goes to the main menu unless something is connected to exit_requested.

## Exit was pressed.
signal exit_requested

const MAIN_MENU := "res://ui/main_menu.tscn"
const SOUND_ICON := preload("res://ui/icons/sound.svg")
const SOUND_OFF_ICON := preload("res://ui/icons/sound_off.svg")

## Seconds counted by the clock (only while running).
var elapsed := 0.0
var clock_running := false

@onready var _clock: Label = %Clock
@onready var _sheet: BottomSheet = %Sheet
@onready var _mute: Button = %MuteButton


func _ready() -> void:
	SettingsPanel.apply_saved()
	(%SettingsButton as Button).pressed.connect(_sheet.toggle)
	(%ExitButton as Button).pressed.connect(_on_exit_pressed)
	_mute.set_pressed_no_signal(SettingsPanel.is_muted())
	_mute.toggled.connect(_on_mute_toggled)
	_update_mute_icon()
	_update_clock()


func _process(delta: float) -> void:
	if clock_running:
		# Capped so a hitch, or the app coming back from the background, doesn't add time.
		elapsed += minf(delta, 0.25)
		_update_clock()


func _unhandled_input(event: InputEvent) -> void:
	# Escape on desktop, the back button on Android.
	if event.is_action_pressed("ui_cancel"):
		_sheet.toggle()
		get_viewport().set_input_as_handled()


func start_clock() -> void:
	elapsed = 0.0
	clock_running = true
	_update_clock()


func stop_clock() -> void:
	clock_running = false


func _update_clock() -> void:
	var s := int(elapsed)
	_clock.text = "%02d:%02d" % [s / 60, s % 60]


func _on_mute_toggled(muted: bool) -> void:
	SettingsPanel.set_muted(muted)
	_update_mute_icon()


func _update_mute_icon() -> void:
	_mute.icon = SOUND_OFF_ICON if _mute.button_pressed else SOUND_ICON


func _on_exit_pressed() -> void:
	exit_requested.emit()
	if exit_requested.get_connections().is_empty():
		get_tree().change_scene_to_file(MAIN_MENU)
