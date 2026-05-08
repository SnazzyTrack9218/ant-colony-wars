extends Node

signal settings_changed(new_settings: Dictionary)

const DEFAULT_SETTINGS_PATH: String = "res://data/settings/default_settings.json"
const USER_SETTINGS_PATH: String = "user://settings.json"

var settings: Dictionary = {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 0.7,
	"fullscreen": true,
	"resolution_width": 1280,
	"resolution_height": 720
}


func _ready() -> void:
	_load_defaults()
	load_settings()
	_apply_settings()


func set_value(key: String, value) -> void:
	if not settings.has(key):
		return
	settings[key] = value
	_apply_settings()
	save_settings()
	settings_changed.emit(settings.duplicate())


func get_value(key: String, fallback = null):
	return settings.get(key, fallback)


func save_settings() -> void:
	var file := FileAccess.open(USER_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SettingsManager: Could not save settings.")
		return
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(USER_SETTINGS_PATH):
		return
	var file := FileAccess.open(USER_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	for key in data:
		if settings.has(key):
			settings[key] = data[key]


func _load_defaults() -> void:
	if not FileAccess.file_exists(DEFAULT_SETTINGS_PATH):
		return
	var file := FileAccess.open(DEFAULT_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	for key in data:
		if settings.has(key):
			settings[key] = data[key]


func _apply_settings() -> void:
	var width: int = int(settings.get("resolution_width", 1280))
	var height: int = int(settings.get("resolution_height", 720))
	DisplayServer.window_set_size(Vector2i(width, height))
	var window_mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN \
			if bool(settings.get("fullscreen", true)) \
			else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)
	_set_bus_volume("Master", float(settings.get("master_volume", 1.0)))
	_set_bus_volume("SFX", float(settings.get("sfx_volume", 1.0)))
	_set_bus_volume("Music", float(settings.get("music_volume", 0.7)))


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var clamped_volume: float = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped_volume) if clamped_volume > 0.0 else -80.0)
	AudioServer.set_bus_mute(bus_index, clamped_volume <= 0.0)
