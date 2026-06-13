extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const GutErrorGuard = preload("res://tests/helpers/gut_error_guard.gd")

var harness
var original_engine_error_treatment: int

func before_each() -> void:
	original_engine_error_treatment = GutErrorGuard.suppress_engine_errors(self)

func after_each() -> void:
	if is_instance_valid(harness):
		harness.disable_player_physics(harness.host_world)
		harness.disable_player_physics(harness.client_world)
		await harness.cleanup()
	GutErrorGuard.restore_engine_errors(self, original_engine_error_treatment)
	harness = null

func test_host_and_client_connect_and_replicate_players() -> void:
	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24600, 180)

	assert_eq(harness.host_manager.get_connected_peer_ids().size(), 2, "Host should see two peers")
	assert_eq(harness.client_manager.get_connected_peer_ids().size(), 2, "Client should see two peers")
	assert_ne(harness.host_peer_id, harness.client_peer_id, "Peers should have distinct ids")

	assert_eq(harness.host_world.player_container.get_child_count(), 2, "Host should spawn two players")
	assert_eq(harness.client_world.player_container.get_child_count(), 2, "Client should replicate two players")

	assert_not_null(harness.host_remote_player, "Host should hold the client player")
	assert_not_null(harness.client_remote_player, "Client should hold the host player")
