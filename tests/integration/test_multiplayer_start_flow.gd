extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")
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

func test_start_sets_hunter_and_hides_start_button_on_both_peers() -> void:
	Engine.time_scale = 2.0
	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24590, 180)

	var host_start_button = harness.host_world.start_button as Button
	var client_start_button = harness.client_world.start_button as Button
	assert_not_null(host_start_button, "Host start button should exist")
	assert_not_null(client_start_button, "Client start button should exist")

	MultiplayerManager.connected_players_metadata.clear()
	MultiplayerManager.connected_players_metadata.append({"peer_id": harness.host_peer_id})
	MultiplayerManager.connected_players_metadata.append({"peer_id": harness.client_peer_id})
	harness.host_world.call("_on_start_pressed")

	await harness.wait_for_physics_condition(
		func(): return GameState.game_state == GameState.State.STARTED,
		120,
		"game_started"
	)
	await harness.wait_for_physics_condition(
		func(): return not host_start_button.visible and not client_start_button.visible,
		120,
		"start_button_hidden_on_both_peers"
	)

	assert_true(GameState.hunter_peer_id != 0, "Hunter should be assigned")
	assert_true(harness.host_player.is_hunter or harness.client_player.is_hunter, "A player should be hunter")
	assert_false(host_start_button.visible, "Host start button should be hidden")
	assert_false(client_start_button.visible, "Client start button should be hidden")
