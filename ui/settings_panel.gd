class_name SettingsPanel
extends VBoxContainer
## Sound and music volume, saved to user://settings.cfg, plus the HUD's mute (all sound). Used in
## the HUD's settings sheet and the main menu. Audio players must use the "SFX" or "Music" bus
## (default_bus_layout.tres).

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SOUND_BUS := &"SFX"
const MASTER_BUS := &"Master"

@onready var _sound: Range = %SoundSlider
@onready var _music: Range = %MusicSlider


func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # A missing file just gives the defaults.
	_sound.set_value_no_signal(cfg.get_value("audio", "sound", 1.0))
	_music.set_value_no_signal(cfg.get_value("audio", "music", 1.0))
	_sound.value_changed.connect(_on_changed.bind(SOUND_BUS))
	_music.value_changed.connect(_on_changed.bind(MUSIC_BUS))


## Applies the saved volumes and mute. Call once at startup (the main menu and the HUD do).
static func apply_saved() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	_apply(SOUND_BUS, cfg.get_value("audio", "sound", 1.0))
	_apply(MUSIC_BUS, cfg.get_value("audio", "music", 1.0))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), cfg.get_value("audio", "muted", false))


static func is_muted() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	return cfg.get_value("audio", "muted", false)


## Mutes or unmutes all sound, and remembers it.
static func set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), muted)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)


static func _apply(bus: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


func _on_changed(value: float, bus: StringName) -> void:
	_apply(bus, value)
	# A sample at the new volume, so the player hears where they set it.
	if bus == SOUND_BUS:
		get_node(^"/root/UiSounds/Tick").play()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # Keeps the mute.
	cfg.set_value("audio", "sound", _sound.value)
	cfg.set_value("audio", "music", _music.value)
	cfg.save(SETTINGS_PATH)
