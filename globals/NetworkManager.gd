extends Node

const BOT_NAMES := ["Rattle", "Bones", "Moss", "Pip", "Rook", "Ash", "Patch", "Twitch", "Flint"]

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal peer_list_changed(peers: Array[Dictionary])
signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)
signal session_lost

var connected_players_metadata: Array[Dictionary] = []
var last_error := ""

var _backend: Node
var _is_dev_mode := false

func _ready() -> void:
	_set_backend(OS.get_cmdline_args().has("--steam"))

	var multiplayer_api := get_tree().get_multiplayer()
	multiplayer_api.peer_connected.connect(_on_peer_connected)
	multiplayer_api.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer_api.connected_to_server.connect(_on_connected_to_server)
	multiplayer_api.server_disconnected.connect(_on_server_disconnected)

func is_dev_mode() -> bool:
	return _is_dev_mode

func is_using_steam() -> bool:
	return not _is_dev_mode

func use_local_backend(address: String = "127.0.0.1") -> void:
	if not _is_dev_mode:
		_set_backend(false)
	(_backend as LocalBackend).host_address = address

func use_steam_backend() -> bool:
	if _is_dev_mode or not is_ready():
		_set_backend(true)
	return is_ready()

func get_player_name(peer_id: int) -> String:
	if peer_id < 0:
		return BOT_NAMES[(absi(peer_id) - 2) % BOT_NAMES.size()]
	for metadata in connected_players_metadata:
		if metadata.peer_id == peer_id:
			return metadata.name
	return "Wanderer %d" % peer_id

func _set_backend(use_steam: bool) -> void:
	if is_instance_valid(_backend):
		_backend.leave_lobby()
		remove_child(_backend)
		_backend.free()
	_is_dev_mode = not use_steam
	_backend = SteamBackend.new() if use_steam else LocalBackend.new()
	_backend.lobby_created.connect(_on_backend_lobby_created)
	_backend.lobby_joined.connect(func(error): lobby_joined.emit(error))
	_backend.lobby_match_list_updated.connect(func(lobbies): lobby_match_list_updated.emit(lobbies))
	add_child(_backend)

func is_ready() -> bool:
	return _backend.is_ready()

func is_host() -> bool:
	var multiplayer_api := get_tree().get_multiplayer()
	return multiplayer_api.multiplayer_peer != null and multiplayer_api.is_server()

func current_lobby_id() -> int:
	return _backend.current_lobby_id

func create_lobby() -> void:
	last_error = ""
	connected_players_metadata.clear()
	_backend.create_lobby()

func join_lobby(lobby_id: int) -> void:
	last_error = ""
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
	var local_peer_id := multiplayer.get_unique_id()
	_add_player_metadata(local_peer_id)
	peer_list_changed.emit(connected_players_metadata)
	_register_player_name.rpc_id(1, get_player_name(local_peer_id))

@rpc("any_peer", "call_remote", "reliable")
func _register_player_name(player_name: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not _has_player_metadata(sender_id):
		return
	var trimmed_name := player_name.strip_edges().left(24)
	if trimmed_name.is_empty():
		return
	_set_player_name(sender_id, trimmed_name)
	for metadata in connected_players_metadata:
		if metadata.peer_id != sender_id:
			_set_player_name.rpc_id(sender_id, metadata.peer_id, metadata.name)
	_set_player_name.rpc(sender_id, trimmed_name)

@rpc("authority", "call_remote", "reliable")
func _set_player_name(peer_id: int, player_name: String) -> void:
	_add_player_metadata(peer_id)
	for metadata in connected_players_metadata:
		if metadata.peer_id == peer_id:
			metadata.name = player_name
			break
	peer_list_changed.emit(connected_players_metadata)

func _on_peer_connected(peer_id: int) -> void:
	_add_player_metadata(peer_id)
	peer_list_changed.emit(connected_players_metadata)
	player_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_remove_player_metadata(peer_id)
	peer_list_changed.emit(connected_players_metadata)
	player_left.emit(peer_id)

func _on_server_disconnected() -> void:
	last_error = tr("The host closed the castle. You can start another game.")
	session_lost.emit()

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
		player_name = Settings.player_name if peer_id == get_tree().get_multiplayer().get_unique_id() else "Wanderer %d" % peer_id
	return {"peer_id": peer_id, "name": player_name}
