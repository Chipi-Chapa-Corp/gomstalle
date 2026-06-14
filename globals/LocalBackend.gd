extends Node
class_name LocalBackend

const MAX_MEMBERS: int = 10
const SERVER_PORT: int = 24545
const DEFAULT_HOST: String = "127.0.0.1"
const JOIN_RESPONSE_SUCCESS: int = 1
const DEVELOPMENT_LOBBY_ID: int = 1
const DEVELOPMENT_LOBBY_NAME: String = "Development Lobby"

signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)

var current_lobby_id: int = 0

var _ready_ok: bool = false
var _peer: ENetMultiplayerPeer
var _known_lobbies: Dictionary = {}
var _pending_join_lobby_id: int = 0

func is_ready() -> bool:
	return _ready_ok

func create_lobby() -> void:
	leave_lobby()

	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(SERVER_PORT, MAX_MEMBERS)
	if error != OK:
		lobby_created.emit("Failed to create lobby: " + error_string(error))
		return

	get_tree().get_multiplayer().multiplayer_peer = _peer
	current_lobby_id = DEVELOPMENT_LOBBY_ID
	_known_lobbies[DEVELOPMENT_LOBBY_ID] = _describe_lobby("waiting", 1)
	lobby_created.emit(null)

func join_lobby(_lobby_id: int) -> void:
	leave_lobby()

	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(DEFAULT_HOST, SERVER_PORT)
	if error != OK:
		lobby_joined.emit("Could not reach the host.")
		return

	_pending_join_lobby_id = DEVELOPMENT_LOBBY_ID
	get_tree().get_multiplayer().multiplayer_peer = _peer

func leave_lobby() -> void:
	if _peer:
		_peer.close()
		_peer = null
	get_tree().get_multiplayer().multiplayer_peer = null
	current_lobby_id = 0

func refresh_lobby_list() -> void:
	var multiplayer_api := get_tree().get_multiplayer()
	var state := "waiting"
	var member_count := 1
	if multiplayer_api.multiplayer_peer and multiplayer_api.is_server():
		member_count = 1 + multiplayer_api.get_peers().size()
	_known_lobbies[DEVELOPMENT_LOBBY_ID] = _describe_lobby(state, member_count)
	lobby_match_list_updated.emit([_known_lobbies[DEVELOPMENT_LOBBY_ID]])

func _ready() -> void:
	var multiplayer_api := get_tree().get_multiplayer()
	multiplayer_api.connected_to_server.connect(_on_connected_to_server)
	multiplayer_api.connection_failed.connect(_on_connection_failed)
	_ready_ok = true

func _describe_lobby(state: String, member_count: int) -> Dictionary:
	return {
		"id": DEVELOPMENT_LOBBY_ID,
		"name": DEVELOPMENT_LOBBY_NAME,
		"state": state,
		"num_members": member_count,
	}

func _on_connected_to_server() -> void:
	current_lobby_id = _pending_join_lobby_id if _pending_join_lobby_id != 0 else DEVELOPMENT_LOBBY_ID
	_pending_join_lobby_id = 0
	lobby_joined.emit(null)

func _on_connection_failed() -> void:
	_pending_join_lobby_id = 0
	lobby_joined.emit("Could not reach the host.")
