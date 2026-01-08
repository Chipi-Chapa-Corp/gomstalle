extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const DoorScene = preload("res://scenes/door/scene.tscn")

var harness
var original_time_scale: float

func before_each() -> void:
	original_time_scale = Engine.time_scale

func after_each() -> void:
	Engine.time_scale = original_time_scale
	_release_input_actions()
	if is_instance_valid(harness):
		_disable_player_physics(harness.host_world)
		_disable_player_physics(harness.client_world)
		harness.cleanup()
	harness = null

func test_door_open_syncs_to_client() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child(harness)
	await harness.setup(24567)
	await harness.wait_for_peer_count(2, 180)

	await _wait_for_physics_condition(
		func():
			return (
				_get_authority_player(harness.host_world.player_container) != null
				and _get_authority_player(harness.client_world.player_container) != null
			),
		180,
		"authority_players_ready"
	)

	var host_player = _get_authority_player(harness.host_world.player_container)
	var client_player = _get_authority_player(harness.client_world.player_container)

	assert_not_null(host_player, "Host player should exist")
	assert_not_null(client_player, "Client player should exist")

	var host_peer_id = int(host_player.get("peer_id"))
	var client_peer_id = int(client_player.get("peer_id"))

	await _wait_for_physics_condition(
		func():
			return (
				_get_player_by_peer_id(harness.host_world.player_container, client_peer_id) != null
				and _get_player_by_peer_id(harness.client_world.player_container, host_peer_id) != null
			),
		180,
		"replicated_players_ready"
	)

	var host_client_player = _get_player_by_peer_id(harness.host_world.player_container, client_peer_id)

	assert_not_null(host_client_player, "Host should have client player")

	host_player.set_physics_process(false)
	host_player.set_process_input(false)

	var arena_origin = Vector3(1000, 0, 1000)
	var door_local_position = Vector3(0, 0, 3)
	var host_arena = _create_test_arena(harness.host_world, arena_origin)
	var client_arena = _create_test_arena(harness.client_world, arena_origin)
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

	await _wait_for_physics_condition(
		func(): return client_player.closest_item == client_door,
		120,
		"door_is_closest_interactable"
	)

	var distance_to_door = client_player.global_position.distance_to(client_door_target)
	assert_true(distance_to_door <= client_player.interact_radius, "Client should be within interact radius")

	await _press_interact()

	await _wait_for_physics_condition(
		func(): return host_door.is_opened and client_door.is_opened,
		120,
		"door_opened_on_both_peers"
	)

	await _wait_for_physics_condition(
		func(): return host_client_player.position.distance_to(client_player.position) <= 0.01,
		120,
		"client_position_replicated_to_host"
	)
	var position_delta = host_client_player.position.distance_to(client_player.position)
	assert_almost_eq(position_delta, 0.0, 0.01, "Host should mirror client position")
	assert_true(host_door.is_opened, "Host door should be open")
	assert_true(client_door.is_opened, "Client door should be open")

func _wait_for_physics_condition(predicate: Callable, frames: int, label: String) -> void:
	var waited := 0
	while waited < frames:
		if predicate.call():
			return
		await get_tree().physics_frame
		waited += 1
	assert(false, "Timed out waiting for condition: %s" % label)

func _get_player_by_peer_id(container: Node, peer_id: int) -> Node3D:
	for child in container.get_children():
		var candidate = child as Node3D
		if candidate == null:
			continue
		if candidate.get("peer_id") == peer_id:
			return candidate
	return null

func _get_authority_player(container: Node) -> Node3D:
	for child in container.get_children():
		var candidate = child as Node3D
		if candidate == null:
			continue
		if candidate.is_multiplayer_authority():
			return candidate
	return null

func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))

func _disable_player_physics(world: Node) -> void:
	var container = world.get("player_container") as Node
	assert(container != null)
	for child in container.get_children():
		child.set_physics_process(false)
		child.set_process_input(false)

func _create_test_arena(world: Node3D, origin: Vector3) -> Node3D:
	var arena = Node3D.new()
	arena.name = "TestArena"
	world.add_child(arena)
	arena.global_position = origin
	var floor = StaticBody3D.new()
	floor.name = "Floor"
	var floor_shape = CollisionShape3D.new()
	var floor_box = BoxShape3D.new()
	floor_box.size = Vector3(20, 1, 20)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor.add_child(floor_shape)
	arena.add_child(floor)
	return arena

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
	_apply_movement_input(input_vector, true)
	var frames = 0
	var distance = _horizontal_distance(player.global_position, target_position)
	while frames < max_frames and distance > target_distance:
		await get_tree().physics_frame
		distance = _horizontal_distance(player.global_position, target_position)
		frames += 1
	_release_movement_inputs()
	assert_true(distance <= target_distance, "Player should reach door")

func _apply_movement_input(input_vector: Vector2, run: bool) -> void:
	_release_movement_inputs()
	var horizontal = clampf(input_vector.x, -1.0, 1.0)
	var vertical = clampf(input_vector.y, -1.0, 1.0)
	if horizontal < 0.0:
		Input.action_press("move_left", -horizontal)
	elif horizontal > 0.0:
		Input.action_press("move_right", horizontal)
	if vertical < 0.0:
		Input.action_press("move_forward", -vertical)
	elif vertical > 0.0:
		Input.action_press("move_backward", vertical)
	if run:
		Input.action_press("run")

func _release_movement_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("run")

func _release_input_actions() -> void:
	_release_movement_inputs()
	Input.action_release("interact")

func _press_interact() -> void:
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	await get_tree().physics_frame
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	release.strength = 0.0
	Input.parse_input_event(release)
	await get_tree().physics_frame
