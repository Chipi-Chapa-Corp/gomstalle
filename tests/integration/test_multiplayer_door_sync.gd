extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const DoorScene = preload("res://scenes/door/scene.tscn")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")
const TestArenaFactory = preload("res://tests/helpers/test_arena_factory.gd")
const PlayerScript = preload("res://scenes/player/script.gd")
const GutErrorGuard = preload("res://tests/helpers/gut_error_guard.gd")

var harness
var original_time_scale: float
var original_engine_error_treatment: int

func before_each() -> void:
	original_engine_error_treatment = GutErrorGuard.suppress_engine_errors(self)
	original_time_scale = Engine.time_scale

func after_each() -> void:
	Engine.time_scale = original_time_scale
	InputTestUtils.release_input_actions()
	if is_instance_valid(harness):
		harness.disable_player_physics(harness.host_world)
		harness.disable_player_physics(harness.client_world)
		await harness.cleanup()
	GutErrorGuard.restore_engine_errors(self, original_engine_error_treatment)
	harness = null

func test_door_open_syncs_to_client() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child(harness)
	await harness.setup_with_players(24567, 180)

	var host_player = harness.host_player as PlayerScript
	var client_player = harness.client_player as PlayerScript
	var host_client_player = harness.host_remote_player as PlayerScript

	assert_not_null(host_player, "Host player should exist")
	assert_not_null(client_player, "Client player should exist")
	assert_not_null(host_client_player, "Host should have client player")

	host_player.set_physics_process(false)
	host_player.set_process_input(false)

	var arena_origin = Vector3(1000, 0, 1000)
	var door_local_position = Vector3(0, 0, 3)
	var host_arena = TestArenaFactory.create(harness.host_world, arena_origin)
	var client_arena = TestArenaFactory.create(harness.client_world, arena_origin)
	var host_door = _spawn_test_door(host_arena, door_local_position)
	var client_door = _spawn_test_door(client_arena, door_local_position)
	var client_door_target = _get_interactable_target_position(client_door)
	await get_tree().process_frame

	var start_offset = client_player.interact_radius + 1.0
	var start_position = _calculate_start_position(client_door, start_offset)
	client_player.global_position = start_position
	client_player.velocity = Vector3.ZERO
	await get_tree().physics_frame

	var vertical_distance = absf(client_player.global_position.y - client_door_target.y)
	var max_horizontal = sqrt(maxf(client_player.interact_radius * client_player.interact_radius - vertical_distance * vertical_distance, 0.01))
	var target_distance = maxf(max_horizontal * 0.9, 0.1)
	var initial_distance = _horizontal_distance(client_player.global_position, client_door_target)
	var max_frames = _max_frames_for_distance(initial_distance - target_distance, client_player.run_move_speed)
	await _move_player_towards(client_player, client_door_target, target_distance, max_frames)

	await harness.wait_for_physics_condition(
		func(): return client_player.closest_item == client_door,
		120,
		"door_is_closest_interactable"
	)

	var distance_to_door = client_player.global_position.distance_to(client_door_target)
	assert_true(distance_to_door <= client_player.interact_radius, "Client should be within interact radius")

	await InputTestUtils.press_action(get_tree(), "interact")

	await harness.wait_for_physics_condition(
		func(): return host_door.is_opened and client_door.is_opened,
		120,
		"door_opened_on_both_peers"
	)

	await harness.wait_for_physics_condition(
		func(): return host_client_player.position.distance_to(client_player.position) <= 0.01,
		120,
		"client_position_replicated_to_host"
	)
	var position_delta = host_client_player.position.distance_to(client_player.position)
	assert_almost_eq(position_delta, 0.0, 0.01, "Host should mirror client position")
	assert_true(host_door.is_opened, "Host door should be open")
	assert_true(client_door.is_opened, "Client door should be open")

func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))

func _spawn_test_door(arena: Node3D, local_position: Vector3) -> Node3D:
	var door_instance = DoorScene.instantiate()
	door_instance.name = "TestDoor"
	door_instance.position = local_position
	arena.add_child(door_instance)
	var receiver = door_instance.get_node("Receiver") as Node3D
	assert(receiver != null)
	return receiver

func _get_interactable_target_position(door: Node3D) -> Vector3:
	var collider = door.get_node("CollisionShape3D") as CollisionShape3D
	assert(collider != null)
	return collider.global_position

func _calculate_start_position(door: Node3D, offset_distance: float) -> Vector3:
	var door_position = _get_interactable_target_position(door)
	var forward = door.global_transform.basis.z.normalized()
	return door_position - forward * offset_distance

func _input_vector_towards(player: CharacterBody3D, target_position: Vector3) -> Vector2:
	var offset = target_position - player.global_position
	offset.y = 0.0
	if offset.length() == 0.0:
		return Vector2.ZERO
	var direction = offset.normalized()
	var input_direction = direction.rotated(Vector3.UP, -player.camera_utils.camera_yaw_offset)
	return Vector2(input_direction.x, input_direction.z)

func _max_frames_for_distance(distance: float, speed: float) -> int:
	var remaining_distance = maxf(distance, 0.0)
	var resolved_speed = maxf(speed, 0.1)
	var time_scale = maxf(Engine.time_scale, 0.01)
	var ticks_per_second = float(Engine.physics_ticks_per_second)
	var estimated_frames = int(ceil((remaining_distance / resolved_speed) * ticks_per_second / time_scale * 1.5))
	return maxi(estimated_frames, 30)

func _move_player_towards(player: CharacterBody3D, target_position: Vector3, target_distance: float, max_frames: int) -> void:
	var input_vector = _input_vector_towards(player, target_position)
	InputTestUtils.apply_movement_input(input_vector, true)
	var frames = 0
	var distance = _horizontal_distance(player.global_position, target_position)
	while frames < max_frames and distance > target_distance:
		await get_tree().physics_frame
		distance = _horizontal_distance(player.global_position, target_position)
		frames += 1
	InputTestUtils.release_movement_inputs()
	assert_true(distance <= target_distance, "Player should reach door")
