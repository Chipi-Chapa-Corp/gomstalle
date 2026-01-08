extends Node

var is_host := false
var connected_players_metadata: Array[Dictionary] = []

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal peer_list_changed(peers: Array[Dictionary])

func reset(multiplayer_api: MultiplayerAPI) -> void:
	is_host = false
	connected_players_metadata.clear()
	multiplayer_api.multiplayer_peer.close()
	multiplayer_api.multiplayer_peer = null

func get_connected_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for player_metadata in connected_players_metadata:
		if player_metadata.has("peer_id"):
			peer_ids.append(player_metadata["peer_id"])
	return peer_ids

func join_multiplayer(multiplayer_api: MultiplayerAPI) -> Error:
	if not multiplayer_api.peer_connected.is_connected(_on_peer_connected):
		multiplayer_api.peer_connected.connect(_on_peer_connected)
	if not multiplayer_api.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer_api.peer_disconnected.connect(_on_peer_disconnected)
	var result := _create_server(multiplayer_api) if is_host else _connect_to_server(multiplayer_api)
	if result == OK and is_host:
		_seed_players(multiplayer_api)
	return result

func _create_server(multiplayer_api: MultiplayerAPI) -> Error:
	if _is_local_backend():
		return _create_local_server(multiplayer_api)
	return _create_steam_server(multiplayer_api)

func _connect_to_server(multiplayer_api: MultiplayerAPI) -> Error:
	if _is_local_backend():
		return _connect_local_server(multiplayer_api)
	return _connect_steam_server(multiplayer_api)

func _create_steam_server(multiplayer_api: MultiplayerAPI) -> Error:
	var peer = SteamMultiplayerPeer.new()
	var result := peer.host_with_lobby(SteamManager.current_lobby_id)
	if result == OK:
		multiplayer_api.multiplayer_peer = peer
		peer_connected.emit(multiplayer_api.get_unique_id())
		return OK
	else:
		push_error("Error: Failed to host with lobby")
		return FAILED

func _connect_steam_server(multiplayer_api: MultiplayerAPI) -> Error:
	var peer = SteamMultiplayerPeer.new()
	var result := peer.connect_to_lobby(SteamManager.current_lobby_id)
	if result == OK:
		multiplayer_api.multiplayer_peer = peer
		return OK
	else:
		push_error("Error: Failed to connect to lobby")
		return FAILED

func _create_local_server(multiplayer_api: MultiplayerAPI) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(Settings.local_port, Settings.local_max_clients)
	if result == OK:
		multiplayer_api.multiplayer_peer = peer
		peer_connected.emit(multiplayer_api.get_unique_id())
		return OK
	push_error("Error: Failed to create local server")
	return FAILED

func _connect_local_server(multiplayer_api: MultiplayerAPI) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(Settings.local_host, Settings.local_port)
	if result == OK:
		multiplayer_api.multiplayer_peer = peer
		return OK
	push_error("Error: Failed to connect to local server")
	return FAILED

func _is_local_backend() -> bool:
	return Settings.network_backend == NetworkConfig.BACKEND_LOCAL

func _on_peer_connected(peer_id: int) -> void:
	_add_player_metadata(peer_id)
	if not is_host:
		call_deferred("_ensure_local_metadata")
	peer_list_changed.emit(connected_players_metadata)
	peer_connected.emit(peer_id)

func _ensure_local_metadata() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		call_deferred("_ensure_local_metadata")
		return
	_add_player_metadata(multiplayer.get_unique_id())
	peer_list_changed.emit(connected_players_metadata)

func _on_peer_disconnected(peer_id: int) -> void:
	_remove_player_metadata(peer_id)
	peer_list_changed.emit(connected_players_metadata)
	peer_disconnected.emit(peer_id)

func _seed_players(multiplayer_api: MultiplayerAPI) -> void:
	connected_players_metadata.clear()
	_add_player_metadata(multiplayer_api.get_unique_id())
	var remote_peer_ids := multiplayer_api.get_peers()
	for remote_peer_id in remote_peer_ids:
		_add_player_metadata(remote_peer_id)
	peer_list_changed.emit(connected_players_metadata)

func _add_player_metadata(peer_id: int) -> void:
	if _has_player_metadata(peer_id):
		return
	connected_players_metadata.append(_build_player_metadata(peer_id))

func _remove_player_metadata(peer_id: int) -> void:
	for index in connected_players_metadata.size():
		var metadata := connected_players_metadata[index]
		if metadata.get("peer_id", 0) == peer_id:
			connected_players_metadata.remove_at(index)
			return

func _has_player_metadata(peer_id: int) -> bool:
	for metadata in connected_players_metadata:
		if metadata.get("peer_id", 0) == peer_id:
			return true
	return false

func _build_player_metadata(peer_id: int) -> Dictionary:
	var player_name := ""
	if SteamManager.is_ready():
		if is_multiplayer_authority():
			player_name = Steam.getPersonaName()
		else:
			player_name = Steam.getFriendPersonaName(peer_id)
	if player_name.is_empty():
		player_name = str(peer_id)
	return {"peer_id": peer_id, "name": player_name}

func _exit_tree() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
