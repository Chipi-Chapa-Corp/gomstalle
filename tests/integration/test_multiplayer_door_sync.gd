extends GutTest

const MultiplayerHarnessScript = preload("res://tests/helpers/multiplayer_harness.gd")

func test_door_open_syncs_to_client() -> void:
	var harness = MultiplayerHarnessScript.new()
	add_child(harness)
	await harness.setup(24567)
	await harness.wait_for_peer_count(2, 180)

	var door_path = NodePath("Interactibles/Doors/wall_doorway/Receiver")
	var host_door = harness.host_world.get_node(door_path)
	var client_door = harness.client_world.get_node(door_path)

	var metadata := {"position": client_door.global_position + Vector3(0, 0, 1)}
	client_door.interact(true, metadata)

	await harness.wait_for_condition(func(): return host_door.is_opened, 120)
	await harness.wait_for_condition(func(): return client_door.is_opened, 120)

	assert_true(host_door.is_opened, "Host door should be open")
	assert_true(client_door.is_opened, "Client door should be open")
	harness.cleanup()
