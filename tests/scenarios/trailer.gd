extends SceneTree

func _initialize() -> void:
	ProjectSettings.set_setting("editor/movie_writer/video_quality", 0.95)
	_load_scenario.call_deferred()

func _load_scenario() -> void:
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.position = Vector2i.ZERO
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	root.add_child(load("res://tests/scenarios/trailer_driver.gd").new())
