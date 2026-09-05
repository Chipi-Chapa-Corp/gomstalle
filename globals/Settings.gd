extends Node

const SAVE_PATH := "user://settings.cfg"

var player_name := "Wanderer"
var master_volume := 0.75
var fullscreen := false
var preferred_role := 0

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		player_name = config.get_value("player", "name", player_name)
		master_volume = config.get_value("audio", "volume", master_volume)
		fullscreen = config.get_value("display", "fullscreen", fullscreen)
	apply()

func apply() -> void:
	AudioServer.set_bus_volume_linear(0, master_volume)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("audio", "volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SAVE_PATH)
