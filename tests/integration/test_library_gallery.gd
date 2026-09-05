extends GutTest

func test_player_can_climb_to_the_reading_gallery() -> void:
	var room: Node3D = load("res://assets/castle/library/reading_gallery.glb").instantiate()
	add_child_autofree(room)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 20)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(-24, -0.5, -4)
	room.add_child(floor_body)
	var player: CharacterBody3D = load("res://scenes/player/scene.tscn").instantiate()
	player._on_before_spawn({"peer_id": 1, "position": Vector3(-15.15, 0.03, -0.7)})
	room.add_child(player)
	player.set_physics_process(false)
	player.camera_utils.camera_yaw_offset = 0
	for frame in 140:
		await get_tree().physics_frame
		player.forces.handle(1.0 / 60.0)
		player.movement._apply_movement(1.0 / 60.0, Vector2(0, -1), false)
		player.move_and_slide()
		player.movement.finish_physics(1.0 / 60.0)
	assert_gt(player.position.y, 2.6, "Walking reaches the upper gallery without jumping.")
	assert_lt(player.position.z, -7.3, "Player crosses the stair landing.")
