class_name Hud
extends CanvasLayer
## In-game HUD (portrait): a bottom bar with Settings (left), a clock counting up (middle) and a
## sound on/off button (right). Settings opens a sheet that slides up from behind the bar, with
## sound and music volume and Exit. The game never pauses.
## Art: Julia's bar and separators (ui/art/hud_*.png) and icons (ui/icons/hud_*.png), from her
## ui_menu_bottom.psd, laid out symmetrically. Muted = the speaker without its waves.
##
## For the game scene: instance ui/hud.tscn and call start_clock() when a round starts.
## Exit goes to the main menu unless something is connected to exit_requested.

## Exit was pressed.
signal exit_requested

const MAIN_MENU := "res://ui/main_menu.tscn"
const SOUND_ICON := preload("res://ui/icons/hud_sound_on.png")
const SOUND_OFF_ICON := preload("res://ui/icons/hud_sound_off.png")

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
	(%SettingsButton as Button).pressed.connect(get_node(^"/root/UiSounds/Click").play)
	(%ExitButton as Button).pressed.connect(get_node(^"/root/UiSounds/Back").play)
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
	_update_mute_icon()
	if not muted:
		SettingsPanel.set_muted(false)
		get_node(^"/root/UiSounds/Unmute").play()
		return
	# Muting at once would cut off the "off" sound, so it mutes once that has played.
	var off := get_node(^"/root/UiSounds/Mute") as AudioStreamPlayer
	off.play()
	await get_tree().create_timer(off.stream.get_length()).timeout
	if _mute.button_pressed:
		SettingsPanel.set_muted(true)


func _update_mute_icon() -> void:
	_mute.icon = SOUND_OFF_ICON if _mute.button_pressed else SOUND_ICON


func _on_exit_pressed() -> void:
	exit_requested.emit()
	if exit_requested.get_connections().is_empty():
		get_tree().change_scene_to_file(MAIN_MENU)
