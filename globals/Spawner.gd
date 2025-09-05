extends Node

@onready var SpawnerNode = MultiplayerSpawner.new()

var scenes: Dictionary = {
	"player": preload("res://scenes/player/scene.tscn"),
}

func _do_spawn(data: Dictionary) -> Node3D:
	var scene = scenes[data["entity"]]
	var entity = scene.instantiate()
	if entity.has_method("_on_before_spawn"):
		entity._on_before_spawn(data["data"])
	return entity

func _ready():
	get_parent().call_deferred("add_child", SpawnerNode)
	SpawnerNode.spawn_path = NodePath(".")
	SpawnerNode.spawn_function = Callable(self, "_do_spawn")

@rpc("authority")
func spawn_entity(entity_name: StringName, data: Dictionary) -> void:
	SpawnerNode.call_deferred("spawn", {
		"entity": entity_name,
		"data": data,
	})
