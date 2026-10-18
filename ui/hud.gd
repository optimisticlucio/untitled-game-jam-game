class_name Hud
extends CanvasLayer
## In-game HUD (portrait): a clock counting up (top centre), a pause button (top right) and a
## pause sheet that slides up from the bottom with Exit and Settings (sound and music volume).
## The same button opens and closes the pause. Pausing sets get_tree().paused; the HUD runs anyway.
## Placeholder art: ui/theme.tres and ui/icons/.
##
## For the game scene: instance ui/hud.tscn and call start_clock() when a round starts.
## Exit goes to the main menu unless something is connected to exit_requested.

signal pause_toggled(paused: bool)
## Exit was pressed (the game is unpaused first).
signal exit_requested

const MAIN_MENU := "res://ui/main_menu.tscn"
const PAUSE_ICON := preload("res://ui/icons/pause.svg")
const PLAY_ICON := preload("res://ui/icons/play.svg")

## Seconds counted by the clock (only while running and not paused).
var elapsed := 0.0
var clock_running := false

@onready var _clock: Label = %Clock
@onready var _pause_button: Button = %PauseButton
@onready var _sheet: BottomSheet = %Sheet
@onready var _settings: Control = %SettingsBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SettingsPanel.apply_saved()
	_pause_button.pressed.connect(toggle_pause)
	(%ExitButton as Button).pressed.connect(_on_exit_pressed)
	(%SettingsButton as Button).pressed.connect(_on_settings_pressed)
	_settings.hide()
	_update_clock()


func _process(delta: float) -> void:
	if clock_running and not get_tree().paused:
		# Capped so a hitch, or the app coming back from the background, doesn't add time.
		elapsed += minf(delta, 0.25)
		_update_clock()


func _unhandled_input(event: InputEvent) -> void:
	# Escape on desktop, the back button on Android.
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


## Screen y where the top bar (clock and pause button) ends. Game UI placed
## near the top of the screen should stay below it.
func top_bar_bottom() -> float:
	return maxf(($Root/ClockPanel as Control).get_global_rect().end.y, _pause_button.get_global_rect().end.y)


func start_clock() -> void:
	elapsed = 0.0
	clock_running = true
	_update_clock()


func stop_clock() -> void:
	clock_running = false


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_button.icon = PLAY_ICON if paused else PAUSE_ICON
	if not paused:
		_settings.hide()
	_sheet.set_open(paused)
	pause_toggled.emit(paused)


func _update_clock() -> void:
	var s := int(elapsed)
	_clock.text = "%02d:%02d" % [s / 60, s % 60]


func _on_settings_pressed() -> void:
	_settings.visible = not _settings.visible
	_sheet.refit()


func _on_exit_pressed() -> void:
	set_paused(false)
	exit_requested.emit()
	if exit_requested.get_connections().is_empty():
		get_tree().change_scene_to_file(MAIN_MENU)
