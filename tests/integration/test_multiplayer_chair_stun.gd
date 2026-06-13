extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")
const ChairScript = preload("res://scenes/chair/script.gd")
const PlayerScript = preload("res://scenes/player/script.gd")
const GutErrorGuard = preload("res://tests/helpers/gut_error_guard.gd")

var harness
var original_time_scale: float
var original_engine_error_treatment: int
var host_chair: ChairScript
var client_chair: ChairScript


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
	host_chair = null
	client_chair = null

func test_host_stuns_client_with_chair() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24570, 180)
	harness.start_visual_capture("Host throws chair")
	await harness.wait_for_visual_capture_padding()
	await _setup_chairs()
	await harness.wait_for_visual_capture_padding()

	var attacker = harness.host_player as PlayerScript
	var target = harness.client_player as PlayerScript
	var target_view = harness.host_remote_player as PlayerScript

	await _throw_chair_and_expect_stun(attacker, target, target_view, host_chair, client_chair)

func test_client_stuns_host_with_chair() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24571, 180)
	harness.start_visual_capture("Client throws chair")
	await harness.wait_for_visual_capture_padding()
	await _setup_chairs()
	await harness.wait_for_visual_capture_padding()

	var attacker = harness.client_player as PlayerScript
	var target = harness.host_player as PlayerScript
	var target_view = harness.client_remote_player as PlayerScript

	await _throw_chair_and_expect_stun(attacker, target, target_view, client_chair, host_chair)

func _setup_chairs() -> void:
	var chair_root = _find_nearest_chair_root(harness.host_world, harness.host_player.global_position)
	var chair_name = chair_root.name
	host_chair = _get_world_chair(harness.host_world, chair_name)
	client_chair = _get_world_chair(harness.client_world, chair_name)
	client_chair.global_transform = host_chair.global_transform
	harness.disable_other_interactibles(harness.host_world, host_chair)
	harness.disable_other_interactibles(harness.client_world, client_chair)
	_disable_other_chairs(harness.host_world, chair_name)
	_disable_other_chairs(harness.client_world, chair_name)
	await get_tree().process_frame

func _get_world_chair(world: Node, chair_name: String) -> ChairScript:
	var chair_root = world.get_node("Interactibles/Chairs/%s" % chair_name) as Node3D
	assert(chair_root != null)
	var chair_body = chair_root.get_node("RigidBody3D") as ChairScript
	assert(chair_body != null)
	return chair_body

func _disable_other_chairs(world: Node, keep_name: String) -> void:
	var chairs_root = world.get_node("Interactibles/Chairs") as Node
	assert(chairs_root != null)
	for child in chairs_root.get_children():
		var node = child as Node
		if node == null or node.name == keep_name:
			continue
		var chair_body = node.get_node_or_null("RigidBody3D") as ChairScript
		if chair_body != null:
			chair_body.remove_from_group("interactible")
			chair_body.collision_layer = 0
			chair_body.collision_mask = 0

func _throw_chair_and_expect_stun(attacker: PlayerScript, target: PlayerScript, target_view: PlayerScript, attacker_chair: ChairScript, target_chair: ChairScript) -> void:
	assert_not_null(attacker, "Attacker should exist")
	assert_not_null(target, "Target should exist")
	assert_not_null(target_view, "Target view should exist")
	assert_not_null(attacker_chair, "Attacker chair should exist")
	assert_not_null(target_chair, "Target chair should exist")

	attacker.is_hunter = false
	target.is_hunter = false

	var chair_position = attacker_chair.global_position
	var forward = InputTestUtils.pick_clear_direction(attacker, chair_position, [attacker.get_rid(), target.get_rid(), attacker_chair.get_rid()], 5.0)
	var pickup_offset = maxf(attacker.interact_radius * 0.3, 0.5)
	var approach_offset = pickup_offset + 1.0
	var target_offset = pickup_offset + 1.6
	attacker_chair.linear_velocity = Vector3.ZERO
	attacker_chair.angular_velocity = Vector3.ZERO
	target_chair.linear_velocity = Vector3.ZERO
	target_chair.angular_velocity = Vector3.ZERO
	var attacker_start = chair_position - forward * approach_offset
	var attacker_pickup = chair_position - forward * pickup_offset
	var target_position = chair_position + forward * target_offset
	var attacker_world = harness.resolve_player_world(attacker)
	var target_world = harness.resolve_player_world(target)
	attacker_start = harness.resolve_ground_position(attacker_world, attacker_start, attacker.global_position.y, [attacker_chair.get_rid()])
	attacker_pickup = harness.resolve_ground_position(attacker_world, attacker_pickup, attacker_start.y, [attacker_chair.get_rid()])
	target_position = harness.resolve_ground_position(target_world, target_position, target.global_position.y, [target_chair.get_rid()])

	_set_player_position(attacker, attacker_start)
	_set_player_position(target, target_position)
	await get_tree().physics_frame

	await harness.wait_for_visual_capture_padding()

	_set_player_active(target, false)
	var approach_distance = 0.25
	var approach_frames = 120
	await InputTestUtils.move_player_towards(get_tree(), attacker, attacker_pickup, false, approach_distance, approach_frames)
	attacker.global_position = attacker_pickup
	attacker.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await harness.wait_for_physics_condition(
		func(): return attacker.closest_item == attacker_chair,
		120,
		"chair_is_closest_interactable"
	)

	assert_false(attacker.is_stunned, "Attacker should not be stunned")
	assert_false(target.is_stunned, "Target should not be stunned")
	assert_false(target_view.is_stunned, "Target view should not be stunned")

	var metadata = _build_interaction_metadata(attacker, forward)
	attacker_chair.interact(true, metadata)
	attacker.item = attacker_chair
	await get_tree().physics_frame
	_set_player_active(target, true)

	await harness.wait_for_physics_condition(
		func(): return attacker.item == attacker_chair,
		120,
		"chair_picked_up"
	)

	await harness.wait_for_visual_capture_padding()

	_face_target(attacker, target_view.global_position)
	await get_tree().physics_frame

	metadata = _build_interaction_metadata(attacker, attacker.model.global_transform.basis.z.normalized())
	attacker_chair.interact(false, metadata)
	attacker.item = null
	await get_tree().physics_frame

	await harness.wait_for_physics_condition(
		func(): return attacker.item == null,
		120,
		"chair_thrown"
	)

	await harness.wait_for_physics_condition(
		func(): return target.is_stunned,
		180,
		"target_stunned_local"
	)

	await harness.wait_for_physics_condition(
		func(): return target_view.is_stunned,
		180,
		"target_stunned_remote"
	)

func _face_target(player: PlayerScript, target_position: Vector3) -> void:
	var offset = target_position - player.model.global_position
	offset.y = 0.0
	if offset.length() == 0.0:
		return
	var direction = offset.normalized()
	var target_yaw = atan2(-direction.x, -direction.z) + PI
	player.model.rotation.y = target_yaw

func _build_interaction_metadata(attacker: PlayerScript, forward: Vector3) -> Dictionary:
	return {
		"position": attacker.global_transform.origin,
		"hand": attacker.hand.get_path(),
		"target": attacker.get_path(),
		"peer_id": attacker.peer_id,
		"direction": forward,
		"amount": 1,
	}

func _find_nearest_chair_root(world: Node, origin: Vector3) -> Node3D:
	var chairs_root = world.get_node("Interactibles/Chairs") as Node
	assert(chairs_root != null)
	var closest: Node3D = null
	var best_distance := INF
	for child in chairs_root.get_children():
		var chair_root = child as Node3D
		if chair_root == null:
			continue
		var chair_body = chair_root.get_node_or_null("RigidBody3D") as ChairScript
		if chair_body == null:
			continue
		var distance = chair_body.global_position.distance_to(origin)
		if distance < best_distance:
			best_distance = distance
			closest = chair_root
	assert(closest != null)
	return closest

func _set_player_active(player: PlayerScript, active: bool) -> void:
	player.set_physics_process(active)
	player.set_process_input(active)

func _set_player_position(player: PlayerScript, position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
