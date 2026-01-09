extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")
const TestArenaFactory = preload("res://tests/helpers/test_arena_factory.gd")
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

func test_start_sets_hunter_and_hides_start_button() -> void:
	Engine.time_scale = 2.0
	await _setup_harness(24582)
	harness.start_visual_capture("hunter_start_flow")
	await harness.wait_for_visual_capture_padding()

	var host_world = harness.host_world
	var client_world = harness.client_world
	var host_start_button = host_world.start_button as Button
	var client_start_button = client_world.start_button as Button
	assert_not_null(host_start_button, "Host start button should exist")
	assert_not_null(client_start_button, "Client start button should exist")

	await _start_match()

	assert_true(GameState.hunter_peer_id != 0, "Hunter should be assigned")
	assert_true(harness.host_player.is_hunter or harness.client_player.is_hunter, "A player should be hunter")
	assert_false(host_start_button.visible, "Host start button should be hidden")
	assert_false(client_start_button.visible, "Client start button should be hidden")

func test_hunter_attack_kills_target_on_both_peers() -> void:
	Engine.time_scale = 2.0
	await _setup_harness(24583)
	harness.start_visual_capture("hunter_kill_flow")
	await harness.wait_for_visual_capture_padding()
	await _start_match()

	var context = _resolve_hunter_context()
	var hunter = context["hunter"] as PlayerScript
	var target = context["target"] as PlayerScript
	var target_view = context["target_view"] as PlayerScript
	assert_not_null(hunter, "Hunter player should exist")
	assert_not_null(target, "Target player should exist")
	assert_not_null(target_view, "Target view should exist")

	var arena_origin = Vector3(1200, 0, 1200)
	TestArenaFactory.create(harness.host_world, arena_origin)
	TestArenaFactory.create(harness.client_world, arena_origin)

	var hunter_position = arena_origin
	var target_position = arena_origin + Vector3(0, 0, 0.6)
	_set_player_position(hunter, hunter_position)
	_set_player_position(target, target_position)

	await _wait_for_player_position(target_view, target_position, "target_position_synced")

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
