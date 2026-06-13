extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")
const PlayerScript = preload("res://scenes/player/script.gd")
const GutErrorGuard = preload("res://tests/helpers/gut_error_guard.gd")

var harness
var original_time_scale: float
var original_metadata: Array[Dictionary]
var original_is_host: bool
var original_engine_error_treatment: int

func before_each() -> void:
	original_engine_error_treatment = GutErrorGuard.suppress_engine_errors(self)
	original_time_scale = Engine.time_scale
	original_metadata = MultiplayerManager.connected_players_metadata.duplicate(true)
	original_is_host = MultiplayerManager.is_host

func after_each() -> void:
	Engine.time_scale = original_time_scale
	InputTestUtils.release_input_actions()
	if is_instance_valid(harness):
		await harness.wait_for_visual_capture_padding()
		harness.stop_visual_capture()
		harness.disable_player_physics(harness.host_world)
		harness.disable_player_physics(harness.client_world)
		await harness.cleanup()
	MultiplayerManager.connected_players_metadata.clear()
	for metadata in original_metadata:
		MultiplayerManager.connected_players_metadata.append(metadata)
	MultiplayerManager.is_host = original_is_host
	GameState.reset(GameState.State.IDLE)
	GutErrorGuard.restore_engine_errors(self, original_engine_error_treatment)
	harness = null

func test_hunter_attack_kills_target_on_both_peers() -> void:
	Engine.time_scale = 2.0
	await _setup_harness(24583)
	harness.start_visual_capture("Host hunter kills")
	await harness.wait_for_visual_capture_padding()
	await _start_match()

	var context = _resolve_hunter_context()
	var hunter = context["hunter"] as PlayerScript
	var target = context["target"] as PlayerScript
	var target_view = context["target_view"] as PlayerScript
	assert_not_null(hunter, "Hunter player should exist")
	assert_not_null(target, "Target player should exist")
	assert_not_null(target_view, "Target view should exist")

	var hunter_world = harness.resolve_player_world(hunter)
	var target_world = harness.resolve_player_world(target)
	var preferred_direction = Vector3(-1, 0, 1)
	var chase_direction = _pick_chase_direction(hunter_world, hunter.global_position, preferred_direction, [hunter.get_rid(), target.get_rid()], 6.0)
	var hunter_start = harness.resolve_ground_position(hunter_world, hunter.global_position, hunter.global_position.y, [hunter.get_rid()])
	var target_start = harness.resolve_ground_position(target_world, hunter_start + chase_direction * 2.8, target.global_position.y, [target.get_rid()])

	_set_player_position(hunter, hunter_start)
	_set_player_position(target, target_start)

	await harness.wait_for_visual_capture_padding()

	hunter.stamina = hunter.max_stamina
	target.stamina = 0.0
	var chase_input = InputTestUtils.input_vector_for_direction(hunter, chase_direction)
	InputTestUtils.apply_movement_input(chase_input, false)
	await _advance_frames(_frames_for_seconds(0.5))
	target.stamina = 0.0
	Input.action_press("run")
	var distance_before = _horizontal_distance(hunter.global_position, target.global_position)
	var relative_speed = maxf(hunter.run_move_speed - target.base_move_speed, 0.1)
	var catch_time = distance_before / relative_speed
	var catch_frames = _frames_for_seconds(catch_time) + 10
	await _advance_frames(_frames_for_seconds(0.2))
	var distance_after = _horizontal_distance(hunter.global_position, target.global_position)
	assert_true(distance_after < distance_before, "Hunter should close distance")
	await _chase_until_close(hunter, target, catch_frames, 1.2)
	InputTestUtils.release_movement_inputs()
	await harness.wait_for_visual_capture_padding()

	hunter.actions.handle_attacked_body(target_view)

	await harness.wait_for_physics_condition(
		func(): return target_view.is_dead,
		120,
		"target_dead_on_hunter"
	)

	await harness.wait_for_physics_condition(
		func(): return target.is_dead,
		120,
		"target_dead_on_self"
	)

func _setup_harness(port: int) -> void:
	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(port, 180)

func _start_match() -> void:
	_seed_global_peers()
	harness.host_world.call("_on_start_pressed")
	await harness.wait_for_physics_condition(
		func(): return GameState.game_state == GameState.State.STARTED,
		120,
		"game_started"
	)
	await harness.wait_for_physics_condition(
		func(): return GameState.hunter_peer_id != 0 and (harness.host_player.is_hunter or harness.client_player.is_hunter),
		120,
		"hunter_assigned"
	)

func _seed_global_peers() -> void:
	MultiplayerManager.connected_players_metadata.clear()
	MultiplayerManager.connected_players_metadata.append({"peer_id": harness.host_peer_id})
	MultiplayerManager.connected_players_metadata.append({"peer_id": harness.client_peer_id})

func _resolve_hunter_context() -> Dictionary:
	var hunter_peer_id = GameState.hunter_peer_id
	if hunter_peer_id == harness.host_peer_id:
		return {
			"hunter": harness.host_player,
			"target": harness.client_player,
			"target_view": harness.host_remote_player,
		}
	if hunter_peer_id == harness.client_peer_id:
		return {
			"hunter": harness.client_player,
			"target": harness.host_player,
			"target_view": harness.client_remote_player,
		}
	assert(false, "Hunter peer id missing from harness")
	return {}

func _set_player_position(player: PlayerScript, position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO

func _wait_for_player_position(player: PlayerScript, position: Vector3, label: String) -> void:
	await harness.wait_for_physics_condition(
		func(): return player.global_position.distance_to(position) <= 0.05,
		120,
		label
	)

func _set_player_active(player: PlayerScript, active: bool) -> void:
	player.set_physics_process(active)
	player.set_process_input(active)

func _frames_for_seconds(seconds: float) -> int:
	var time_scale = maxf(Engine.time_scale, 0.01)
	var ticks_per_second = float(Engine.physics_ticks_per_second)
	return maxi(int(ceil(seconds * ticks_per_second / time_scale)), 1)

func _chase_until_close(hunter: PlayerScript, target: PlayerScript, max_frames: int, stop_distance: float) -> void:
	var frames = 0
	var distance = _horizontal_distance(hunter.global_position, target.global_position)
	while frames < max_frames and distance > stop_distance:
		await get_tree().physics_frame
		distance = _horizontal_distance(hunter.global_position, target.global_position)
		frames += 1
	assert_true(distance <= stop_distance, "Hunter should close distance")

func _advance_frames(frames: int) -> void:
	var steps = 0
	while steps < frames:
		await get_tree().physics_frame
		steps += 1

func _pick_chase_direction(world: Node3D, origin: Vector3, preferred: Vector3, exclude: Array, distance: float) -> Vector3:
	var normalized = preferred.normalized()
	if _is_direction_clear(world, origin, normalized, distance, exclude):
		return normalized
	if _is_direction_clear(world, origin, -normalized, distance, exclude):
		return -normalized
	return InputTestUtils.pick_clear_direction(world, origin, exclude, distance)

func _is_direction_clear(world: Node3D, origin: Vector3, direction: Vector3, distance: float, exclude: Array) -> bool:
	var space = world.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin + Vector3(0, 1.0, 0), origin + direction * distance + Vector3(0, 1.0, 0))
	var exclude_rids = InputTestUtils.resolve_exclude_rids(exclude)
	if not exclude_rids.is_empty():
		query.exclude = exclude_rids
	return space.intersect_ray(query).is_empty()

func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
