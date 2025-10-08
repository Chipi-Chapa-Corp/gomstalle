extends Node

var is_host := false
var connected_peer_ids: Array[int] = []

signal peer_connected(peer_id: int)

func reset(multiplayer_api: MultiplayerAPI) -> void:
	is_host = false
	connected_peer_ids.clear()
	multiplayer_api.multiplayer_peer.close()
	multiplayer_api.multiplayer_peer = null

func join_multiplayer(multiplayer_api: MultiplayerAPI) -> Error:
	return _create_server(multiplayer_api) if is_host else _connect_to_server(multiplayer_api)

func _create_server(multiplayer_api: MultiplayerAPI) -> Error:
	multiplayer_api.peer_connected.connect(_on_peer_connected)
	var peer = SteamMultiplayerPeer.new()
	var result := peer.host_with_lobby(SteamManager.current_lobby_id)
	if result == OK:
		multiplayer_api.multiplayer_peer = peer
		peer_connected.emit(multiplayer_api.get_unique_id())
		return OK
	else:
		push_error("Error: Failed to host with lobby")
		return FAILED

func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)

func _connect_to_server(multiplayer_api: MultiplayerAPI) -> Error:
	var peer = SteamMultiplayerPeer.new()
	var result := peer.connect_to_lobby(SteamManager.current_lobby_id)
	if result == OK:
		multiplayer_api.multiplayer_peer = peer
		return OK
	else:
		push_error("Error: Failed to connect to lobby")
		return FAILED

func sync_connected_peers(multiplayer_api: MultiplayerAPI) -> Array[int]:
	connected_peer_ids = []
	connected_peer_ids.append(multiplayer_api.get_unique_id())
	var remote_peers := multiplayer_api.get_peers()
	for peer_id in remote_peers:
		connected_peer_ids.append(peer_id)
	return connected_peer_ids

func _exit_tree() -> void:
	peer_connected.disconnect(_on_peer_connected)