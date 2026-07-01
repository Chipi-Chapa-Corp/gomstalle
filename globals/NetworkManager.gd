extends Node

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal peer_list_changed(peers: Array[Dictionary])
signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)

var connected_players_metadata: Array[Dictionary] = []

var _backend: Node
var _is_dev_mode := false

func _ready() -> void:
	_is_dev_mode = OS.get_cmdline_args().has("--dev")
	_backend = LocalBackend.new() if _is_dev_mode else SteamBackend.new()
	_backend.lobby_created.connect(_on_backend_lobby_created)
	_backend.lobby_joined.connect(func(error): lobby_joined.emit(error))
	_backend.lobby_match_list_updated.connect(func(lobbies): lobby_match_list_updated.emit(lobbies))
	add_child(_backend)

	var multiplayer_api := get_tree().get_multiplayer()
	multiplayer_api.peer_connected.connect(_on_peer_connected)
	multiplayer_api.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer_api.connected_to_server.connect(_on_connected_to_server)

func is_dev_mode() -> bool:
	return _is_dev_mode

func is_ready() -> bool:
	return _backend.is_ready()

func is_host() -> bool:
	var multiplayer_api := get_tree().get_multiplayer()
	return multiplayer_api.multiplayer_peer != null and multiplayer_api.is_server()

func current_lobby_id() -> int:
	return _backend.current_lobby_id

func create_lobby() -> void:
	connected_players_metadata.clear()
	_backend.create_lobby()

func join_lobby(lobby_id: int) -> void:
	connected_players_metadata.clear()
	_backend.join_lobby(lobby_id)

func leave_lobby() -> void:
	_backend.leave_lobby()
	connected_players_metadata.clear()

func refresh_lobby_list() -> void:
	_backend.refresh_lobby_list()

func reset() -> void:
	leave_lobby()

func get_connected_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for player_metadata in connected_players_metadata:
		if player_metadata.has("peer_id"):
			peer_ids.append(player_metadata["peer_id"])
	return peer_ids

func _on_backend_lobby_created(error) -> void:
	if error == null:
		_add_player_metadata(get_tree().get_multiplayer().get_unique_id())
		peer_list_changed.emit(connected_players_metadata)
	lobby_created.emit(error)

func _on_connected_to_server() -> void:
	_add_player_metadata(get_tree().get_multiplayer().get_unique_id())
	peer_list_changed.emit(connected_players_metadata)

func _on_peer_connected(peer_id: int) -> void:
	_add_player_metadata(peer_id)
	peer_list_changed.emit(connected_players_metadata)
	player_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_remove_player_metadata(peer_id)
	peer_list_changed.emit(connected_players_metadata)
	player_left.emit(peer_id)

func _add_player_metadata(peer_id: int) -> void:
	if _has_player_metadata(peer_id):
		return
	connected_players_metadata.append(_build_player_metadata(peer_id))

func _remove_player_metadata(peer_id: int) -> void:
	for index in connected_players_metadata.size():
		if connected_players_metadata[index]["peer_id"] == peer_id:
			connected_players_metadata.remove_at(index)
			return

func _has_player_metadata(peer_id: int) -> bool:
	for player_metadata in connected_players_metadata:
		if player_metadata["peer_id"] == peer_id:
			return true
	return false

func _build_player_metadata(peer_id: int) -> Dictionary:
	var player_name := ""
	if not _is_dev_mode and _backend.is_ready():
		if peer_id == get_tree().get_multiplayer().get_unique_id():
			player_name = Steam.getPersonaName()
		else:
			player_name = Steam.getFriendPersonaName(peer_id)
	if player_name.is_empty():
		player_name = str(peer_id)
	return {"peer_id": peer_id, "name": player_name}
