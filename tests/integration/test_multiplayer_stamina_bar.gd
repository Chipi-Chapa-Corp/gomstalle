extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")
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

func test_stamina_bar_visibility_and_regeneration() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24568, 180)

	var host_player = harness.host_player as PlayerScript
	var client_player = harness.client_player as PlayerScript

	host_player.set_physics_process(false)
	host_player.set_process_input(false)

	var stamina_bar = client_player.stamina_bar
	assert_not_null(stamina_bar, "Stamina bar should exist")

	await harness.wait_for_physics_condition(
		func(): return not stamina_bar.visible and stamina_bar.value >= 99.0,
		120,
		"stamina_hidden_when_idle"
	)

	InputTestUtils.apply_movement_input(Vector2(0, -1), true)

	await harness.wait_for_physics_condition(
		func(): return stamina_bar.visible and stamina_bar.value < 99.0,
		120,
		"stamina_visible_when_running"
	)

	InputTestUtils.release_movement_inputs()

	await harness.wait_for_physics_condition(
		func(): return not stamina_bar.visible and stamina_bar.value >= 99.0,
		240,
		"stamina_regenerates_and_hides"
	)

func test_remote_stamina_bar_hidden_when_idle() -> void:
	Engine.time_scale = 2.0

	harness = MultiplayerHarnessScript.new()
	add_child_autoqfree(harness)
	await harness.setup_with_players(24569, 180)

	var host_player = harness.host_player as PlayerScript
	var client_remote_player = harness.client_remote_player as PlayerScript

	host_player.set_physics_process(false)
	host_player.set_process_input(false)

	var remote_stamina_bar = client_remote_player.stamina_bar
	assert_not_null(remote_stamina_bar, "Remote stamina bar should exist")

	await harness.wait_for_physics_condition(
		func(): return not remote_stamina_bar.is_visible_in_tree(),
		120,
		"remote_stamina_hidden_when_idle"
	)
