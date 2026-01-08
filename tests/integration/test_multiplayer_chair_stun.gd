extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")
const TestArenaFactory = preload("res://tests/helpers/test_arena_factory.gd")
const ChairScene = preload("res://scenes/chair/scene.tscn")
const ChairScript = preload("res://scenes/chair/script.gd")
const PlayerScript = preload("res://scenes/player/script.gd")
const TestErrorGuard = preload("res://tests/helpers/test_error_guard.gd")

var harness
var original_time_scale: float
var original_engine_error_treatment: int
var host_chair: ChairScript
var client_chair: ChairScript
var arena_origin: Vector3

func before_each() -> void:
	original_engine_error_treatment = TestErrorGuard.suppress_engine_errors(self)
	original_time_scale = Engine.time_scale

func after_each() -> void:
	Engine.time_scale = original_time_scale
	InputTestUtils.release_input_actions()
	if is_instance_valid(harness):
		harness.disable_player_physics(harness.host_world)
		harness.disable_player_physics(harness.client_world)
		await harness.cleanup()
	TestErrorGuard.restore_engine_errors(self, original_engine_error_treatment)
	harness = null
	host_chair = null
	client_chair = null

func test_host_stuns_client_with_chair() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child(harness)
	await harness.setup_with_players(24570, 180)
	await _setup_chairs()

	var attacker = harness.host_player as PlayerScript
	var target = harness.client_player as PlayerScript
	var target_view = harness.host_remote_player as PlayerScript

	await _throw_chair_and_expect_stun(attacker, target, target_view, host_chair, client_chair)

func test_client_stuns_host_with_chair() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child(harness)
	await harness.setup_with_players(24571, 180)
	await _setup_chairs()

	var attacker = harness.client_player as PlayerScript
	var target = harness.host_player as PlayerScript
	var target_view = harness.client_remote_player as PlayerScript

	await _throw_chair_and_expect_stun(attacker, target, target_view, client_chair, host_chair)

func _setup_chairs() -> void:
	arena_origin = Vector3(1000, 0, 1000)
	var host_arena = TestArenaFactory.create(harness.host_world, arena_origin)
	var client_arena = TestArenaFactory.create(harness.client_world, arena_origin)
	host_chair = _spawn_chair(host_arena)
	client_chair = _spawn_chair(client_arena)
	await get_tree().process_frame

func _spawn_chair(arena: Node3D) -> ChairScript:
	var chair_instance = ChairScene.instantiate()
	chair_instance.name = "TestChair"
	arena.add_child(chair_instance)
	var chair_body = chair_instance.get_node("RigidBody3D") as ChairScript
	assert(chair_body != null)
	return chair_body

func _throw_chair_and_expect_stun(attacker: PlayerScript, target: PlayerScript, target_view: PlayerScript, attacker_chair: ChairScript, target_chair: ChairScript) -> void:
	assert_not_null(attacker, "Attacker should exist")
	assert_not_null(target, "Target should exist")
	assert_not_null(target_view, "Target view should exist")
	assert_not_null(attacker_chair, "Attacker chair should exist")
	assert_not_null(target_chair, "Target chair should exist")

	attacker.is_hunter = false
	target.is_hunter = false
	target_chair.remove_from_group("interactible")

	var forward = Vector3(0, 0, 1)
	var chair_position = arena_origin
	var attacker_offset = max(attacker.interact_radius * 0.6, 0.6)
	var attacker_position = chair_position - forward * attacker_offset
	var target_position = chair_position + forward * 2.0

	attacker_chair.global_position = chair_position
	target_chair.global_position = chair_position
	attacker_chair.linear_velocity = Vector3.ZERO
	attacker_chair.angular_velocity = Vector3.ZERO
	target_chair.linear_velocity = Vector3.ZERO
	target_chair.angular_velocity = Vector3.ZERO

	attacker.global_position = attacker_position
	target.global_position = target_position
	attacker.velocity = Vector3.ZERO
	target.velocity = Vector3.ZERO

	await get_tree().physics_frame

	await harness.wait_for_physics_condition(
		func(): return target_view.global_position.distance_to(target_position) <= 0.05,
		120,
		"target_position_synced"
	)

	await harness.wait_for_physics_condition(
		func(): return attacker.closest_item == attacker_chair,
		120,
		"chair_is_closest_interactable"
	)

	assert_false(attacker.is_stunned, "Attacker should not be stunned")
	assert_false(target.is_stunned, "Target should not be stunned")
	assert_false(target_view.is_stunned, "Target view should not be stunned")

	await InputTestUtils.press_action(get_tree(), "interact")

	await harness.wait_for_physics_condition(
		func(): return attacker.item == attacker_chair,
		120,
		"chair_picked_up"
	)

	_face_target(attacker, target_view.global_position)
	await get_tree().physics_frame

	await harness.wait_for_physics_condition(
		func(): return attacker.cooldown_timer.time_left <= 0.0,
		120,
		"interaction_cooldown_ready"
	)

	await InputTestUtils.press_action(get_tree(), "interact")

	await harness.wait_for_physics_condition(
		func(): return attacker.item == null,
		120,
		"chair_thrown"
	)

	await harness.wait_for_physics_condition(
		func(): return attacker_chair.can_stun and attacker_chair.linear_velocity.length() > 0.1,
		120,
		"chair_can_stun"
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
