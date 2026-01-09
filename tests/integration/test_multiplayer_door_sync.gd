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

class DoorPair:
	var host_door: Node3D
	var client_door: Node3D
	var target_position: Vector3

	func _init(host: Node3D, client: Node3D, target: Vector3) -> void:
		host_door = host
		client_door = client
		target_position = target

func before_each() -> void:
	original_engine_error_treatment = GutErrorGuard.suppress_engine_errors(self)
	original_time_scale = Engine.time_scale

func after_each() -> void:
	Engine.time_scale = original_time_scale
	InputTestUtils.release_input_actions()
	if is_instance_valid(harness):
		await harness.wait_for_visual_capture_padding()
		harness.stop_visual_capture()
		harness.disable_player_physics(harness.host_world)
		harness.disable_player_physics(harness.client_world)
		await harness.cleanup()
	GutErrorGuard.restore_engine_errors(self, original_engine_error_treatment)
	harness = null

func test_door_open_syncs_to_client() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24567, 180)
	harness.start_visual_capture("door_open_sync")
	await harness.wait_for_visual_capture_padding()

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
	var door_pair = _create_door_pair(arena_origin, door_local_position)
	var host_door = door_pair.host_door
	var client_door = door_pair.client_door
	var client_door_target = door_pair.target_position
	await get_tree().process_frame

	await _position_player_for_interaction(client_player, client_door, client_door_target)

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

func test_client_opens_door_and_can_pass_through() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24572, 180)
	harness.start_visual_capture("door_open_sync_client")
	await harness.wait_for_visual_capture_padding()

	var host_player = harness.host_player as PlayerScript
	var client_player = harness.client_player as PlayerScript
	var host_client_player = harness.host_remote_player as PlayerScript

	assert_not_null(host_player, "Host player should exist")
	assert_not_null(client_player, "Client player should exist")
	assert_not_null(host_client_player, "Host should have client player")

	host_player.set_physics_process(false)
	host_player.set_process_input(false)

	var arena_origin = Vector3(1100, 0, 1100)
	var door_local_position = Vector3(0, 0, 3)
	var door_pair = _create_door_pair(arena_origin, door_local_position)
	var host_door = door_pair.host_door
	var client_door = door_pair.client_door
	var client_door_target = door_pair.target_position
	await get_tree().process_frame

	await _position_player_for_interaction(client_player, client_door, client_door_target)

	assert_true(client_door.multiplayer.has_multiplayer_peer(), "Client door should have multiplayer peer")
	assert_false(client_door.multiplayer.is_server(), "Client door should be non-authority")

	await InputTestUtils.press_action(get_tree(), "interact")

	await harness.wait_for_physics_condition(
		func(): return host_door.is_opened,
		120,
		"host_door_opened_by_client"
	)
	await harness.wait_for_physics_condition(
		func(): return absf(client_door.body.rotation_degrees.y) >= 80.0,
		120,
		"client_door_rotation_open"
	)

	var passage_offset = client_player.interact_radius + 1.0
	var passage_target = _calculate_passage_position(client_door, passage_offset)
	var passage_distance = _horizontal_distance(client_player.global_position, passage_target)
	var passage_frames = _max_frames_for_distance(passage_distance, client_player.run_move_speed)
	await _move_player_towards(client_player, passage_target, 0.2, passage_frames, "passage")

	await harness.wait_for_physics_condition(
		func(): return host_client_player.position.distance_to(client_player.position) <= 0.05,
		120,
		"client_position_passed_door_on_host"
	)

func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))

func _create_door_pair(arena_origin: Vector3, door_local_position: Vector3) -> DoorPair:
	var host_arena = TestArenaFactory.create(harness.host_world, arena_origin)
	var client_arena = TestArenaFactory.create(harness.client_world, arena_origin)
	var host_door = _spawn_test_door(host_arena, door_local_position)
	var client_door = _spawn_test_door(client_arena, door_local_position)
	var target_position = _get_interactable_target_position(client_door)
	return DoorPair.new(host_door, client_door, target_position)

func _position_player_for_interaction(player: PlayerScript, door: Node3D, target_position: Vector3) -> void:
	var start_offset = player.interact_radius + 1.0
	var start_position = _calculate_start_position(door, start_offset)
	player.global_position = start_position
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame

	var vertical_distance = absf(player.global_position.y - target_position.y)
	var max_horizontal = sqrt(maxf(player.interact_radius * player.interact_radius - vertical_distance * vertical_distance, 0.01))
	var target_distance = maxf(max_horizontal * 0.9, 0.1)
	var initial_distance = _horizontal_distance(player.global_position, target_position)
	var max_frames = _max_frames_for_distance(initial_distance - target_distance, player.run_move_speed)
	await _move_player_towards(player, target_position, target_distance, max_frames, "door")

	await harness.wait_for_physics_condition(
		func(): return player.closest_item == door,
		120,
		"door_is_closest_interactable"
	)

	var distance_to_door = player.global_position.distance_to(target_position)
	assert_true(distance_to_door <= player.interact_radius, "Player should be within interact radius")

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

func _calculate_passage_position(door: Node3D, offset_distance: float) -> Vector3:
	var door_position = _get_interactable_target_position(door)
	var forward = door.global_transform.basis.z.normalized()
	return door_position + forward * offset_distance

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

func _move_player_towards(player: CharacterBody3D, target_position: Vector3, target_distance: float, max_frames: int, label: String) -> void:
	var input_vector = _input_vector_towards(player, target_position)
	InputTestUtils.apply_movement_input(input_vector, true)
	var frames = 0
	var distance = _horizontal_distance(player.global_position, target_position)
	while frames < max_frames and distance > target_distance:
		await get_tree().physics_frame
		distance = _horizontal_distance(player.global_position, target_position)
		frames += 1
	InputTestUtils.release_movement_inputs()
	if distance > target_distance and _is_visual_capture_enabled():
		player.global_position = target_position
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		distance = _horizontal_distance(player.global_position, target_position)
	assert_true(distance <= target_distance, "Player should reach %s" % label)

func _is_visual_capture_enabled() -> bool:
	return harness != null and harness.is_visual_capture_enabled()
