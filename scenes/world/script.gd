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
	var peers := GameState.sync_connected_peers(multiplayer)
	if peers.is_empty():
		return
	var hunter_peer_id := peers[randi() % peers.size()]
	var positions := _calculate_positions(hunter_peer_id, peers)
	rpc("_notify_game_start", hunter_peer_id, positions)
	_apply_game_start(hunter_peer_id, positions)

@rpc("any_peer")
func _notify_game_start(hunter_peer_id: int, positions: Dictionary) -> void:
	_apply_game_start(hunter_peer_id, positions)

func _apply_game_start(hunter_peer_id: int, positions: Dictionary) -> void:
	GameState.start(hunter_peer_id, positions)
	var local_player := _get_local_player()
	if local_player == null:
		return
	var target_position = positions.get(int(local_player.peer_id), player_spawn_center)
	local_player.global_position = target_position

func _calculate_positions(hunter_peer_id: int, peer_ids: Array[int]) -> Dictionary:
	var positions: Dictionary = {}
	positions[hunter_peer_id] = player_spawn_center
	var hider_ids: Array[int] = []
	for peer_id in peer_ids:
		if peer_id != hunter_peer_id:
			hider_ids.append(peer_id)
	var hider_count := hider_ids.size()
	if hider_count == 0:
		return positions
	var angle_step := TAU / float(hider_count)
	for index in hider_count:
		var peer_id := hider_ids[index]
		var angle := angle_step * index
		var player_position := player_spawn_center + Vector3(cos(angle), 0.0, sin(angle)) * player_spawn_radius
		positions[peer_id] = player_position
	return positions

func _get_local_player() -> Node3D:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			return player
	return null
