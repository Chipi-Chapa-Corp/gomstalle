extends Node3D

const MAX_CLIENTS := 4
@export var player_spawn_center: Vector3 = Vector3.ZERO
@export var player_spawn_radius: float = 4.0

func _ready():
	if Settings.is_host:
		print_debug("Starting server [HOST]")
		multiplayer.peer_connected.connect(_on_peer_connected)
		_start_server(func(): _on_peer_connected(multiplayer.get_unique_id()))
	else:
		print_debug("Connecting to server [PEER]")
		_connect_to_server()

func _start_server(cb: Callable):
	var peer = SteamMultiplayerPeer.new()
	var result = peer.host_with_lobby(SteamManager.current_lobby_id)
	if result == OK:
		multiplayer.multiplayer_peer = peer
		cb.call()
	else:
		push_error("Error: Failed to host with lobby " + result)

func _connect_to_server():
	var peer = SteamMultiplayerPeer.new()
	var result = peer.connect_to_lobby(SteamManager.current_lobby_id)
	if result == OK:
		multiplayer.multiplayer_peer = peer
	else:
		push_error("Error: Failed to connect to lobby " + result)
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(peer_id: int) -> void:
	print_debug("Server spawning player ", peer_id)
	$UI/HUD/Start.visible = true
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})

func _on_start_pressed():
	if not Settings.is_host:
		return
	GameState.sync_connected_peers(multiplayer)
	var peers := GameState.connected_peer_ids
	if peers.is_empty():
		return
	var random_index := randi() % peers.size()
	var hunter_peer_id := peers[random_index]
	rpc("_notify_game_start", hunter_peer_id, peers)
	_apply_game_start(hunter_peer_id, peers)

@rpc("any_peer")
func _notify_game_start(hunter_peer_id: int, peer_ids: Array) -> void:
	GameState.set_connected_peers(peer_ids)
	_apply_game_start(hunter_peer_id, peer_ids)

func _apply_game_start(hunter_peer_id: int, peer_ids: Array) -> void:
	GameState.mark_started(hunter_peer_id)
	var players := _get_players()
	if players.is_empty():
		return
	var circle_count = max(peer_ids.size(), 1)
	var angle_step = TAU / circle_count
	var player_index := 0
	for player in players:
		if player.peer_id == hunter_peer_id:
			player.global_position = player_spawn_center
		else:
			var angle = angle_step * player_index
			var new_position = player_spawn_center + Vector3(cos(angle), 0.0, sin(angle)) * player_spawn_radius
			player.global_position = new_position
			player_index += 1

func _get_players() -> Array:
	var player_nodes: Array = []
	for player_node in get_tree().get_nodes_in_group("players"):
		player_nodes.append(player_node)
	return player_nodes
