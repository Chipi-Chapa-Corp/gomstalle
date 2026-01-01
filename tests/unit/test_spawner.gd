extends GutTest

func test_do_spawn_player_calls_before_spawn() -> void:
	var spawner := Spawner.new()
	var data := {
		"entity": "player",
		"data": {
			"peer_id": 7,
			"position": Vector3(1, 2, 3),
		},
	}

	var entity = spawner._do_spawn(data)
	assert_not_null(entity, "Spawner should instantiate entity")
	assert_eq(entity.position, Vector3(1, 2, 3), "Spawn data should set position")
	assert_eq(entity.peer_id, 7, "Spawn data should set peer id")
	entity.queue_free()

func test_do_spawn_without_before_spawn_is_safe() -> void:
	var spawner := Spawner.new()
	var dummy := Node3D.new()
	var packed := PackedScene.new()
	packed.pack(dummy)
	spawner.scenes["dummy"] = packed

	var entity = spawner._do_spawn({"entity": "dummy", "data": {}})
	assert_not_null(entity, "Spawner should instantiate dummy entity")
	entity.queue_free()

func test_set_path_updates_spawner() -> void:
	var spawner := Spawner.new()
	var path := NodePath("/root/World")
	spawner.set_path(path)
	assert_eq(spawner.SpawnerNode.spawn_path, path, "set_path should update spawn_path")
