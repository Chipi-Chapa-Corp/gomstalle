extends GutTest

const PlayerScene := preload("res://scenes/player/scene.tscn")

var compact: SphereShape3D
var standing: CapsuleShape3D
var passage_world: Node3D
var grid: GridMap

func before_all() -> void:
	var player_reference: CharacterBody3D = PlayerScene.instantiate()
	compact = player_reference.get_node("Dash Collider").shape
	standing = player_reference.get_node("Regular Collider").shape
	player_reference.free()
	var castle: Node3D = load("res://scenes/world/scene.tscn").instantiate()
	grid = castle.get_node("GridMap")
	castle.remove_child(grid)
	castle.free()
	passage_world = Node3D.new()
	passage_world.add_child(grid)
	passage_world.add_child(CastleDressing.new())
	add_child(passage_world)
	await get_tree().physics_frame
	await get_tree().physics_frame

func after_all() -> void:
	passage_world.free()

func test_serving_passage_fits_compact_player_in_both_directions() -> void:
	for direction in [-1.0, 1.0]:
		var start := Vector3(38, 1.15 + compact.radius, 32 - direction * 2.8)
		var motion := Vector3(0, 0, direction * 5.6)
		var travel := _cast_passage(compact, start, motion)
		assert_eq(travel, 1.0, "Compact player must clear the complete serving passage in both directions")
	assert_eq(grid.get_cell_item(Vector3i(48, 0, 30)), -1, "Original solid wall must be removed behind the hatch")

func test_serving_passage_blocks_standing_player() -> void:
	var travel := _cast_passage(standing, Vector3(38, 1.15 + standing.height * 0.5, 34.8), Vector3(0, 0, -5.6))
	assert_lt(travel, 0.5, "Standing player must meet the lintel before entering the compact shortcut")

func test_player_jump_and_air_slide_crosses_the_serving_hatch() -> void:
	var player: CharacterBody3D = PlayerScene.instantiate()
	player._on_before_spawn({"peer_id": 1, "position": Vector3(38, 0.1, 35.3)})
	passage_world.add_child(player)
	autofree(player)
	player.set_physics_process(false)
	player.camera_utils.camera_yaw_offset = 0
	await _advance_player(player, 15, Vector2.ZERO)
	assert_true(player.is_on_floor(), "Player must begin on the actual kitchen floor")
	player.movement.request_jump()
	await _advance_player(player, 12, Vector2(0, -1))
	assert_true(player.movement.start_air_slide(), "A jump toward the counter must allow an air slide")
	await _advance_player(player, 40, Vector2(0, -1))
	assert_lt(player.position.z, 30.8, "The actual player controller must emerge in the banquet room")
	assert_false(player.movement.is_compact, "Player must stand again after leaving the lintel")

func _advance_player(player: CharacterBody3D, frame_count: int, movement_input: Vector2) -> void:
	for frame_index in frame_count:
		await get_tree().physics_frame
		player.forces.handle(1.0 / 60.0)
		player.movement._apply_movement(1.0 / 60.0, movement_input, false)
		player.move_and_slide()
		player.movement.finish_physics(1.0 / 60.0)

func _cast_passage(shape: Shape3D, start: Vector3, motion: Vector3) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform.origin = start
	query.motion = motion
	return passage_world.get_world_3d().direct_space_state.cast_motion(query)[0]
