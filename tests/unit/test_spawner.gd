extends GutTest

const SpawnerScript = preload("res://globals/Spawner.gd")

var _created_nodes: Array[Node] = []

func after_each() -> void:
	for node in _created_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_created_nodes.clear()

func test_do_spawn_player_calls_before_spawn() -> void:
	var spawner := SpawnerScript.new()
	_created_nodes.append(spawner)
	add_child(spawner)
	var data := {
		"entity": "player",
		"data": {
			"peer_id": 7,
			"position": Vector3(1, 2, 3),
		},
	}

	var entity = spawner._do_spawn(data)
	_created_nodes.append(entity)
	assert_not_null(entity, "Spawner should instantiate entity")
	assert_eq(entity.position, Vector3(1, 2, 3), "Spawn data should set position")
	assert_eq(entity.peer_id, 7, "Spawn data should set peer id")

func test_do_spawn_without_before_spawn_is_safe() -> void:
	var spawner := SpawnerScript.new()
	_created_nodes.append(spawner)
	add_child(spawner)
	var dummy := Node3D.new()
	_created_nodes.append(dummy)
	var packed := PackedScene.new()
	packed.pack(dummy)
	spawner.scenes["dummy"] = packed

	var entity = spawner._do_spawn({"entity": "dummy", "data": {}})
	_created_nodes.append(entity)
	assert_not_null(entity, "Spawner should instantiate dummy entity")

func test_set_path_updates_spawner() -> void:
	var spawner := SpawnerScript.new()
	_created_nodes.append(spawner)
	spawner.SpawnerNode = MultiplayerSpawner.new()
	_created_nodes.append(spawner.SpawnerNode)
	add_child(spawner)
	var path := NodePath(".")
	spawner.set_path(path)
	assert_eq(spawner.SpawnerNode.spawn_path, path, "set_path should update spawn_path")
