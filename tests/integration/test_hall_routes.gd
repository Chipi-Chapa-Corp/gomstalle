extends GutTest

const PlayerScene := preload("res://scenes/player/scene.tscn")

var hall_world: Node3D
var dressing: CastleDressing

func before_all() -> void:
	var castle: Node3D = load("res://scenes/world/scene.tscn").instantiate()
	var grid: GridMap = castle.get_node("GridMap")
	castle.remove_child(grid)
	castle.free()
	hall_world = Node3D.new()
	hall_world.add_child(grid)
	dressing = CastleDressing.new()
	hall_world.add_child(dressing)
	add_child(hall_world)
	await get_tree().physics_frame
	await get_tree().physics_frame

func after_all() -> void:
	hall_world.free()

func test_arrival_spawn_ring_and_reception_routes_remain_clear() -> void:
	for angle_index in 16:
		var angle := angle_index * TAU / 16
		_assert_clear(Vector3(cos(angle) * 4, 0.1, sin(angle) * 4))
	for location in [Vector3(-10, 0, 12), Vector3(-5, 0, 12), Vector3(-5, 0, 8), Vector3(5, 0, 8), Vector3(10.5, 0, 6), Vector3(-5, 0, 15.5), Vector3(0, 0, 15.5), Vector3(5.7, 0, 15.5), Vector3(5.7, 0, 11.5)]:
		_assert_clear(location)

func test_grand_hall_crossing_and_adjacent_room_approaches_remain_clear() -> void:
	for horizontal in range(-10, 36, 2):
		_assert_clear(Vector3(horizontal, 0, 58.5))
	for depth in range(45, 58, 2):
		_assert_clear(Vector3(-6, 0, depth))
		_assert_clear(Vector3(22, 0, depth))
	for depth in range(59, 68, 2):
		_assert_clear(Vector3(2, 0, depth))

func test_audience_front_stairs_are_walkable_without_jumping() -> void:
	await _verify_stair(Vector3(2, 0.1, 56), Vector3(2, 2.2, 50.2))

func test_audience_side_stairs_are_walkable_without_jumping() -> void:
	await _verify_stair(Vector3(10.95, 0.1, 48), Vector3(7.3, 2.2, 48))

func test_minstrels_front_stairs_are_walkable_without_jumping() -> void:
	await _verify_stair(Vector3(27.75, 0.1, 56), Vector3(27.75, 2.2, 50.2))

func test_minstrels_side_stairs_are_walkable_without_jumping() -> void:
	await _verify_stair(Vector3(34.8, 0.1, 48.5), Vector3(30.3, 2.2, 48.5))

func test_observatory_stairs_are_walkable_in_both_directions() -> void:
	await _verify_stair(Vector3(10, .1, 78), Vector3(10, 4.05, 85.2))

func _verify_stair(start: Vector3, destination: Vector3) -> void:
	var player: CharacterBody3D = PlayerScene.instantiate()
	player._on_before_spawn({"peer_id": 1, "position": start})
	hall_world.add_child(player)
	player.set_physics_process(false)
	player.camera_utils.camera_yaw_offset = 0
	for frame_index in 15:
		await _advance(player, Vector2.ZERO)
	assert_true(player.is_on_floor(), "Player starts on the actual castle floor")
	await _walk_to(player, destination)
	assert_almost_eq(player.position.y, destination.y, .035, "Player stands on the raised court, without a jump")
	assert_true(player.is_on_floor(), "The upper landing supports the player")
	await _walk_to(player, start)
	assert_lt(player.position.y, .2, "Player walks back down to the castle floor")
	player.free()

func test_cellar_entry_and_both_trolley_routes_remain_clear() -> void:
	for horizontal in range(-32, -23):
		_assert_clear(Vector3(horizontal, 0, 26))
	for depth in range(28, 34):
		_assert_clear(Vector3(-30, 0, depth))
	for horizontal in [-31.5, -27.8]:
		for depth in range(33, 40):
			_assert_clear(Vector3(horizontal, 0, depth))

func test_player_can_walk_both_sides_of_the_cellar_trolley() -> void:
	for horizontal in [-31.5, -27.8]:
		var player: CharacterBody3D = PlayerScene.instantiate()
		player._on_before_spawn({"peer_id": 1, "position": Vector3(-30, .1, 32)})
		hall_world.add_child(player)
		player.set_physics_process(false)
		player.camera_utils.camera_yaw_offset = 0
		for frame_index in 15:
			await _advance(player, Vector2.ZERO)
		await _walk_to(player, Vector3(horizontal, 0, 32.8))
		await _walk_to(player, Vector3(horizontal, 0, 39))
		await _walk_to(player, Vector3(-30, 0, 39))
		assert_true(player.is_on_floor(), "Both trolley aisles support ordinary running")
		player.free()

func _walk_to(player: CharacterBody3D, destination: Vector3) -> void:
	var remaining := Vector2(destination.x - player.position.x, destination.z - player.position.z)
	for frame_index in 180:
		if remaining.length() < .18:
			break
		await _advance(player, remaining.normalized())
		remaining = Vector2(destination.x - player.position.x, destination.z - player.position.z)
	assert_lt(remaining.length(), .3, "Player reaches %s; actual %s" % [destination, player.position])
	for frame_index in 8:
		await _advance(player, Vector2.ZERO)

func _advance(player: CharacterBody3D, movement_input: Vector2) -> void:
	await get_tree().physics_frame
	player.forces.handle(1.0 / 60.0)
	player.movement._apply_movement(1.0 / 60.0, movement_input, false)
	player.move_and_slide()
	player.movement.finish_physics(1.0 / 60.0)

func _assert_clear(location: Vector3) -> void:
	var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), location)
	assert_true(blockers.is_empty(), "Hall route at %s is blocked by %s" % [location, blockers])
