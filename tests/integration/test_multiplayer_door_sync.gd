extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")
const PlayerScript = preload("res://scenes/player/script.gd")
const GutErrorGuard = preload("res://tests/helpers/gut_error_guard.gd")

var harness
var original_time_scale: float
var original_engine_error_treatment: int


class DoorPair:
	var host_door: Node3D
	var client_door: Node3D

	func _init(host: Node3D, client: Node3D) -> void:
		host_door = host
		client_door = client

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
	harness.start_visual_capture("Host opens door")
	await harness.wait_for_visual_capture_padding()

	var host_player = harness.host_player as PlayerScript
	var client_player = harness.client_player as PlayerScript
	var host_client_player = harness.host_remote_player as PlayerScript
	var client_host_player = harness.client_remote_player as PlayerScript

	assert_not_null(host_player, "Host player should exist")
	assert_not_null(client_player, "Client player should exist")
	assert_not_null(host_client_player, "Host should have client player")
	assert_not_null(client_host_player, "Client should have host player")

	var door_pair = _resolve_door_pair(host_player.global_position)
	var host_door = door_pair.host_door
	var client_door = door_pair.client_door
	harness.disable_other_interactibles(harness.host_world, host_door)
	harness.disable_other_interactibles(harness.client_world, client_door)
	var door_target = _get_interactable_target_position(host_door)
	var door_axis = _get_door_axis(host_door)
	var interaction_offset = _get_interaction_offset(host_player, host_door)
	var approach_offset = interaction_offset + 0.8
	var passage_offset = _get_passage_offset(host_player, host_door)
	var passage_distance = 0.6
	var safe_offset = _get_safe_offset(client_player, host_door)
	var host_ground = harness.resolve_ground_position(harness.host_world, door_target, host_player.global_position.y, [host_door.get_rid()])
	var client_ground = harness.resolve_ground_position(harness.client_world, _get_interactable_target_position(client_door), client_player.global_position.y, [client_door.get_rid()])
	var door_forward = _select_clear_axis(harness.host_world, host_ground, door_axis, _get_door_excludes(host_door))
	var host_start = _calculate_side_position(host_ground, door_forward, approach_offset)
	var host_interact = _calculate_side_position(host_ground, door_forward, interaction_offset)
	var client_start = _calculate_side_position(client_ground, door_forward, -safe_offset)

	_set_player_position(host_player, host_start)
	_set_player_position(client_player, client_start)
	await get_tree().physics_frame
	host_start = host_player.global_position
	client_start = client_player.global_position
	await _wait_for_player_sync(host_client_player, client_player, "client_initial_position_synced")
	await _wait_for_player_sync(client_host_player, host_player, "host_initial_position_synced")
	await harness.wait_for_visual_capture_padding()

	_set_player_active(client_player, false)
	await _move_player_towards(host_player, host_interact, 0.2, _max_frames_for_distance(_horizontal_distance(host_player.global_position, host_interact), host_player.base_move_speed), "host_interact", false)
	await harness.wait_for_physics_condition(
		func(): return host_player.closest_item == host_door,
		120,
		"host_door_is_closest_interactable"
	)
	await InputTestUtils.press_interact_for_player(get_tree(), host_player)
	_set_player_active(client_player, true)
	await harness.wait_for_visual_capture_padding()

	await harness.wait_for_physics_condition(
		func(): return host_door.is_opened and client_door.is_opened,
		120,
		"door_opened_on_both_peers"
	)
	await harness.wait_for_physics_condition(
		func(): return _horizontal_distance(client_player.global_position, client_start) <= 0.05,
		120,
		"client_not_pushed_by_door"
	)
	await harness.wait_for_visual_capture_padding()

	var host_passage_target = _calculate_side_position(host_ground, door_forward, -passage_offset)
	await _move_player_towards(host_player, host_passage_target, passage_distance, _max_frames_for_distance(_horizontal_distance(host_player.global_position, host_passage_target), host_player.run_move_speed), "host_passage", true)
	await _wait_for_player_sync(client_host_player, host_player, "host_passage_synced")
	await harness.wait_for_visual_capture_padding()

	_set_player_active(host_player, false)
	var client_passage_target = _calculate_side_position(client_ground, door_forward, passage_offset)
	await _move_player_towards(client_player, client_passage_target, passage_distance, _max_frames_for_distance(_horizontal_distance(client_player.global_position, client_passage_target), client_player.run_move_speed), "client_passage", true)
	await _wait_for_player_sync(host_client_player, client_player, "client_passage_synced")
	_set_player_active(host_player, true)
	await harness.wait_for_visual_capture_padding()

	assert_true(host_door.is_opened, "Host door should be open")
	assert_true(client_door.is_opened, "Client door should be open")

func test_client_opens_door_and_can_pass_through() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24572, 180)
	harness.start_visual_capture("Client opens door")
	await harness.wait_for_visual_capture_padding()

	var host_player = harness.host_player as PlayerScript
	var client_player = harness.client_player as PlayerScript
	var host_client_player = harness.host_remote_player as PlayerScript
	var client_host_player = harness.client_remote_player as PlayerScript

	assert_not_null(host_player, "Host player should exist")
	assert_not_null(client_player, "Client player should exist")
	assert_not_null(host_client_player, "Host should have client player")
	assert_not_null(client_host_player, "Client should have host player")

	var door_pair = _resolve_door_pair(client_player.global_position)
	var host_door = door_pair.host_door
	var client_door = door_pair.client_door
	harness.disable_other_interactibles(harness.host_world, host_door)
	harness.disable_other_interactibles(harness.client_world, client_door)
	var door_target = _get_interactable_target_position(client_door)
	var door_axis = _get_door_axis(client_door)
	var interaction_offset = _get_interaction_offset(client_player, client_door)
	var approach_offset = interaction_offset + 0.8
	var passage_offset = _get_passage_offset(client_player, client_door)
	var passage_distance = 0.6
	var safe_offset = _get_safe_offset(host_player, client_door)
	var client_ground = harness.resolve_ground_position(harness.client_world, door_target, client_player.global_position.y, [client_door.get_rid()])
	var host_ground = harness.resolve_ground_position(harness.host_world, _get_interactable_target_position(host_door), host_player.global_position.y, [host_door.get_rid()])
	var door_forward = _select_clear_axis(harness.client_world, client_ground, door_axis, _get_door_excludes(client_door))
	var client_start = _calculate_side_position(client_ground, door_forward, approach_offset)
	var client_interact = _calculate_side_position(client_ground, door_forward, interaction_offset)
	var host_start = _calculate_side_position(host_ground, door_forward, -safe_offset)

	_set_player_position(client_player, client_start)
	_set_player_position(host_player, host_start)
	await get_tree().physics_frame
	client_start = client_player.global_position
	host_start = host_player.global_position
	await _wait_for_player_sync(host_client_player, client_player, "client_initial_position_synced")
	await _wait_for_player_sync(client_host_player, host_player, "host_initial_position_synced")
	await harness.wait_for_visual_capture_padding()

	_set_player_active(host_player, false)
	await _move_player_towards(client_player, client_interact, 0.2, _max_frames_for_distance(_horizontal_distance(client_player.global_position, client_interact), client_player.base_move_speed), "client_interact", false)
	await InputTestUtils.press_interact_for_player(get_tree(), client_player)
	_set_player_active(host_player, true)
	await harness.wait_for_visual_capture_padding()

	assert_true(client_door.multiplayer.has_multiplayer_peer(), "Client door should have multiplayer peer")
	assert_false(client_door.multiplayer.is_server(), "Client door should be non-authority")

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
	await harness.wait_for_physics_condition(
		func(): return _horizontal_distance(host_player.global_position, host_start) <= 0.05,
		120,
		"host_not_pushed_by_door"
	)
	await harness.wait_for_visual_capture_padding()

	var client_passage_target = _calculate_side_position(client_ground, door_forward, -passage_offset)
	await _move_player_towards(client_player, client_passage_target, passage_distance, _max_frames_for_distance(_horizontal_distance(client_player.global_position, client_passage_target), client_player.run_move_speed), "client_passage", true)
	await _wait_for_player_sync(host_client_player, client_player, "client_passage_synced")
	await harness.wait_for_visual_capture_padding()

	_set_player_active(client_player, false)
	var host_passage_target = _calculate_side_position(host_ground, door_forward, passage_offset)
	await _move_player_towards(host_player, host_passage_target, passage_distance, _max_frames_for_distance(_horizontal_distance(host_player.global_position, host_passage_target), host_player.run_move_speed), "host_passage", true)
	await _wait_for_player_sync(client_host_player, host_player, "host_passage_synced")
	_set_player_active(client_player, true)
	await harness.wait_for_visual_capture_padding()

func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))

func _resolve_door_pair(origin: Vector3) -> DoorPair:
	var host_root = _find_nearest_door_root(harness.host_world, origin)
	var door_name = host_root.name
	var host_door = _get_world_door_receiver(harness.host_world, door_name)
	var client_door = _get_world_door_receiver(harness.client_world, door_name)
	return DoorPair.new(host_door, client_door)

func _find_nearest_door_root(world: Node, origin: Vector3) -> Node3D:
	var doors_root = world.get_node("Interactibles/Doors") as Node
	assert(doors_root != null)
	var closest: Node3D = null
	var best_distance := INF
	for child in doors_root.get_children():
		var door_root = child as Node3D
		if door_root == null:
			continue
		var receiver = door_root.get_node_or_null("Receiver") as Node3D
		if receiver == null:
			continue
		var distance = receiver.global_position.distance_to(origin)
		if distance < best_distance:
			best_distance = distance
			closest = door_root
	assert(closest != null)
	return closest

func _get_world_door_receiver(world: Node, door_name: String) -> Node3D:
	var door_root = world.get_node("Interactibles/Doors/%s" % door_name) as Node3D
	assert(door_root != null)
	var receiver = door_root.get_node("Receiver") as Node3D
	assert(receiver != null)
	return receiver

func _get_interactable_target_position(door: Node3D) -> Vector3:
	var collider = door.get_node("CollisionShape3D") as CollisionShape3D
	assert(collider != null)
	return collider.global_position

func _get_door_axis(door: Node3D) -> Vector3:
	var parent = door.get_parent() as Node3D
	assert(parent != null)
	if is_equal_approx(parent.rotation.y, 0.0):
		return Vector3(0, 0, 1)
	return Vector3(1, 0, 0)

func _get_door_excludes(door: Node3D) -> Array:
	var body = door.get("body") as CollisionObject3D
	assert(body != null)
	return [door.get_rid(), body.get_rid()]

func _select_clear_axis(world: Node3D, origin: Vector3, axis: Vector3, exclude: Array) -> Vector3:
	var space = world.get_world_3d().direct_space_state
	var normalized = axis.normalized()
	var start = origin + Vector3(0, 1.0, 0)
	var distance = 3.5
	var exclude_rids = InputTestUtils.resolve_exclude_rids(exclude)
	var forward_clear = _is_ray_clear(space, start, normalized, distance, exclude_rids)
	var backward_clear = _is_ray_clear(space, start, -normalized, distance, exclude_rids)
	if forward_clear and not backward_clear:
		return normalized
	if backward_clear and not forward_clear:
		return -normalized
	return normalized

func _is_ray_clear(space, start: Vector3, direction: Vector3, distance: float, exclude_rids: Array) -> bool:
	var query = PhysicsRayQueryParameters3D.create(start, start + direction * distance)
	if not exclude_rids.is_empty():
		query.exclude = exclude_rids
	return space.intersect_ray(query).is_empty()

func _calculate_side_position(target_position: Vector3, forward: Vector3, offset_distance: float) -> Vector3:
	return target_position + forward * offset_distance

func _max_frames_for_distance(distance: float, speed: float) -> int:
	var remaining_distance = maxf(distance, 0.0)
	var resolved_speed = maxf(speed, 0.1)
	var time_scale = maxf(Engine.time_scale, 0.01)
	var ticks_per_second = float(Engine.physics_ticks_per_second)
	var estimated_frames = int(ceil((remaining_distance / resolved_speed) * ticks_per_second / time_scale * 1.5))
	return maxi(estimated_frames, 30)

func _move_player_towards(player: PlayerScript, target_position: Vector3, target_distance: float, max_frames: int, label: String, run: bool) -> void:
	var distance = await InputTestUtils.move_player_towards(get_tree(), player, target_position, run, target_distance, max_frames)
	assert_true(distance <= target_distance, "Player should reach %s" % label)

func _set_player_active(player: PlayerScript, active: bool) -> void:
	player.set_physics_process(active)
	player.set_process_input(active)

func _set_player_position(player: PlayerScript, position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO

func _wait_for_player_sync(remote_player: PlayerScript, source_player: PlayerScript, label: String) -> void:
	await harness.wait_for_physics_condition(
		func(): return remote_player.global_position.distance_to(source_player.global_position) <= 0.05,
		120,
		label
	)

func _get_safe_offset(player: PlayerScript, door: Node3D) -> float:
	var collider = door.get_node("CollisionShape3D") as CollisionShape3D
	assert(collider != null)
	var shape = collider.shape as BoxShape3D
	assert(shape != null)
	return player.interact_radius + maxf(shape.size.x, shape.size.z)

func _get_interaction_offset(player: PlayerScript, door: Node3D) -> float:
	var collider = door.get_node("CollisionShape3D") as CollisionShape3D
	assert(collider != null)
	var vertical_distance = absf(collider.global_position.y - player.global_position.y)
	var radius = player.interact_radius
	var max_horizontal = radius
	if vertical_distance < radius:
		max_horizontal = sqrt(radius * radius - vertical_distance * vertical_distance)
	return maxf(max_horizontal * 0.8, 0.4)

func _get_passage_offset(player: PlayerScript, door: Node3D) -> float:
	return player.interact_radius + 1.0

func _is_visual_capture_enabled() -> bool:
	return harness != null and harness.is_visual_capture_enabled()
