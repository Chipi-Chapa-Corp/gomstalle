extends SceneTree

func _initialize() -> void:
	ProjectSettings.set_setting("editor/movie_writer/video_quality", 0.95)
	_load_film.call_deferred()

func _load_film() -> void:
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.position = Vector2i.ZERO
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/midnight/scene.tscn")
