extends VBoxContainer

@onready var game_scene: PackedScene = preload("res://scenes/world/scene.tscn")

func _on_host_pressed() -> void:
    Settings.is_host = true
    _on_start()

func _on_join_pressed() -> void:
    Settings.is_host = false
    _on_start()

func _on_start() -> void:
    get_tree().change_scene_to_packed(game_scene)