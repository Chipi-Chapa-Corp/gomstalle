extends Node

class_name MultiplayerHarness

const WorldScene = preload("res://scenes/world/scene.tscn")
const MultiplayerManagerScript = preload("res://globals/MultiplayerManager.gd")
const SpawnerScript = preload("res://globals/Spawner.gd")

var host_root: Node
var client_root: Node
var host_world: Node
var client_world: Node
var host_manager: Node
var client_manager: Node
var host_spawner: Node
var client_spawner: Node
var host_multiplayer: SceneMultiplayer
var client_multiplayer: SceneMultiplayer
var host_player: Node3D
var client_player: Node3D
var host_peer_id: int
var client_peer_id: int
var host_remote_player: Node3D
var client_remote_player: Node3D

func setup(port: int) -> void:
	Settings.network_backend = NetworkConfig.BACKEND_LOCAL
	Settings.local_host = "127.0.0.1"
	Settings.local_port = port
	Settings.local_max_clients = 2

	host_root = Node.new()
	host_root.name = "HostRoot"
	client_root = Node.new()
	client_root.name = "ClientRoot"
	add_child(host_root)
	add_child(client_root)

	host_multiplayer = SceneMultiplayer.new()
	client_multiplayer = SceneMultiplayer.new()
	host_multiplayer.root_path = host_root.get_path()
	client_multiplayer.root_path = client_root.get_path()
	get_tree().set_multiplayer(host_multiplayer, host_root.get_path())
	get_tree().set_multiplayer(client_multiplayer, client_root.get_path())

	host_spawner = SpawnerScript.new()
	client_spawner = SpawnerScript.new()
	host_root.add_child(host_spawner)
	client_root.add_child(client_spawner)

	await get_tree().process_frame

	host_manager = MultiplayerManagerScript.new()
	host_manager.is_host = true
	host_root.add_child(host_manager)

	client_manager = MultiplayerManagerScript.new()
	client_manager.is_host = false
	client_root.add_child(client_manager)

	host_world = WorldScene.instantiate()
	host_world.set("spawner", host_spawner)
	host_world.set("multiplayer_manager", host_manager)
	host_root.add_child(host_world)

	await get_tree().process_frame

	client_world = WorldScene.instantiate()
	client_world.set("spawner", client_spawner)
	client_world.set("multiplayer_manager", client_manager)
	client_root.add_child(client_world)

func setup_with_players(port: int, frames: int) -> void:
	await setup(port)
	await wait_for_peer_count(2, frames)

	await wait_for_physics_condition(
		func():
			return (
				get_authority_player(host_world.player_container) != null
				and get_authority_player(client_world.player_container) != null
			),
		frames,
		"authority_players_ready"
	)

	host_player = get_authority_player(host_world.player_container)
	client_player = get_authority_player(client_world.player_container)
	assert(host_player != null)
	assert(client_player != null)

	host_peer_id = int(host_player.get("peer_id"))
	client_peer_id = int(client_player.get("peer_id"))

	await wait_for_physics_condition(
		func():
			return (
				get_player_by_peer_id(host_world.player_container, client_peer_id) != null
				and get_player_by_peer_id(client_world.player_container, host_peer_id) != null
			),
		frames,
		"replicated_players_ready"
	)

	host_remote_player = get_player_by_peer_id(host_world.player_container, client_peer_id)
	client_remote_player = get_player_by_peer_id(client_world.player_container, host_peer_id)
	assert(host_remote_player != null)
	assert(client_remote_player != null)

func wait_for_peer_count(expected_count: int, frames: int) -> void:
	var waited := 0
	while waited < frames:
		if host_manager.get_connected_peer_ids().size() == expected_count and client_manager.get_connected_peer_ids().size() == expected_count:
			return
		await get_tree().process_frame
		waited += 1
	assert(false, "Timed out waiting for peers")

func wait_for_condition(predicate: Callable, frames: int) -> void:
	var waited := 0
	while waited < frames:
		if predicate.call():
			return
		await get_tree().process_frame
		waited += 1
	assert(false, "Timed out waiting for condition")

func wait_for_physics_condition(predicate: Callable, frames: int, label: String) -> void:
	var waited := 0
	while waited < frames:
		if predicate.call():
			return
		await get_tree().physics_frame
		waited += 1
	assert(false, "Timed out waiting for condition: %s" % label)

func get_player_by_peer_id(container: Node, peer_id: int) -> Node3D:
	for child in container.get_children():
		var candidate = child as Node3D
		if candidate == null:
			continue
		if candidate.get("peer_id") == peer_id:
			return candidate
	return null

func get_authority_player(container: Node) -> Node3D:
	for child in container.get_children():
		var candidate = child as Node3D
		if candidate == null:
			continue
		if candidate.is_multiplayer_authority():
			return candidate
	return null

func disable_player_physics(world: Node) -> void:
	var container = world.get("player_container") as Node
	assert(container != null)
	for child in container.get_children():
		child.set_physics_process(false)
		child.set_process_input(false)

func cleanup() -> void:
	host_root.process_mode = Node.PROCESS_MODE_DISABLED
	client_root.process_mode = Node.PROCESS_MODE_DISABLED
	host_multiplayer.multiplayer_peer.close()
	client_multiplayer.multiplayer_peer.close()
	host_root.queue_free()
	client_root.queue_free()
	await get_tree().process_frame
	queue_free()
