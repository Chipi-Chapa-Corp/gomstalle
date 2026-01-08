extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")
const InputTestUtils = preload("res://tests/helpers/input_test_utils.gd")

var harness
var original_time_scale: float
var host_player: Node3D
var client_player: Node3D
var host_peer_id: int
var client_peer_id: int
var client_remote_player: Node3D

func before_each() -> void:
	original_time_scale = Engine.time_scale

func after_each() -> void:
	Engine.time_scale = original_time_scale
	InputTestUtils.release_input_actions()
	if is_instance_valid(harness):
		harness.disable_player_physics(harness.host_world)
		harness.disable_player_physics(harness.client_world)
		harness.cleanup()
	harness = null
	host_player = null
	client_player = null
	client_remote_player = null
	host_peer_id = 0
	client_peer_id = 0

func test_stamina_bar_visibility_and_regeneration() -> void:
	Engine.time_scale = 2.0

	await _setup_multiplayer(24568)

	host_player.set_physics_process(false)
	host_player.set_process_input(false)

	var stamina_bar = client_player.get("stamina_bar") as TextureProgressBar
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

	await _setup_multiplayer(24569)

	host_player.set_physics_process(false)
	host_player.set_process_input(false)

	var remote_stamina_bar = client_remote_player.get("stamina_bar") as TextureProgressBar
	assert_not_null(remote_stamina_bar, "Remote stamina bar should exist")

	await harness.wait_for_physics_condition(
		func(): return not remote_stamina_bar.is_visible_in_tree(),
		120,
		"remote_stamina_hidden_when_idle"
	)

func _setup_multiplayer(port: int) -> void:
	harness = MultiplayerHarnessScript.new()
	add_child(harness)
	await harness.setup(port)
	await harness.wait_for_peer_count(2, 180)

	await harness.wait_for_physics_condition(
		func():
			return (
				harness.get_authority_player(harness.host_world.player_container) != null
				and harness.get_authority_player(harness.client_world.player_container) != null
			),
		180,
		"authority_players_ready"
	)

	host_player = harness.get_authority_player(harness.host_world.player_container)
	client_player = harness.get_authority_player(harness.client_world.player_container)

	assert_not_null(host_player, "Host player should exist")
	assert_not_null(client_player, "Client player should exist")

	host_peer_id = int(host_player.get("peer_id"))
	client_peer_id = int(client_player.get("peer_id"))

	await harness.wait_for_physics_condition(
		func():
			return (
				harness.get_player_by_peer_id(harness.host_world.player_container, client_peer_id) != null
				and harness.get_player_by_peer_id(harness.client_world.player_container, host_peer_id) != null
			),
		180,
		"replicated_players_ready"
	)

	client_remote_player = harness.get_player_by_peer_id(harness.client_world.player_container, host_peer_id)
	assert_not_null(client_remote_player, "Client should have host player")
