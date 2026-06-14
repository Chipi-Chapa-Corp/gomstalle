extends Node
class_name SteamBackend

const APP_LOBBY_TAG: String = "gomstalle"
const MAX_MEMBERS: int = 10

signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)

var current_lobby_id: int = 0

var _ready_ok: bool = false

func is_ready() -> bool:
	return _ready_ok

func create_lobby() -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_MEMBERS)

func join_lobby(lobby_id: int) -> void:
	Steam.joinLobby(lobby_id)

func leave_lobby() -> void:
	if current_lobby_id != 0:
		Steam.leaveLobby(current_lobby_id)
	get_tree().get_multiplayer().multiplayer_peer = null
	current_lobby_id = 0

func refresh_lobby_list() -> void:
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("_app_id", APP_LOBBY_TAG, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _ready() -> void:
	if not Steam:
		push_error("Steam singleton not found. You need `SteamGodot SteamMultiplayerPeer` version of editor.")
		return
	if not Steam.steamInit():
		push_error("Error: Failed to initialize Steam. Is Steam app running and logged in?")
		return
	_listen()
	set_process(true)
	_ready_ok = true

func _process(_delta: float) -> void:
	if Steam and Steam.has_method("run_callbacks"):
		Steam.run_callbacks()

func _listen() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.p2p_session_request.connect(_on_p2p_session_request)

func _on_lobby_created(lobby_connect: int, lobby_id: int) -> void:
	if lobby_connect != 1:
		lobby_created.emit("Failed to create lobby: " + str(lobby_connect))
		return

	current_lobby_id = lobby_id
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, "_app_id", APP_LOBBY_TAG)
	Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName())
	Steam.setLobbyData(lobby_id, "state", "waiting")
	Steam.allowP2PPacketRelay(true)

	var peer := SteamMultiplayerPeer.new()
	var error := peer.host_with_lobby(lobby_id)
	if error != OK:
		lobby_created.emit("Failed to host lobby: " + error_string(error))
		return
	get_tree().get_multiplayer().multiplayer_peer = peer
	lobby_created.emit(null)

func _on_lobby_match_list(lobby_ids: Array) -> void:
	var list = lobby_ids.map(func(lobby_id: int):
		return {
			"id": lobby_id,
			"name": Steam.getLobbyData(lobby_id, "name"),
			"state": Steam.getLobbyData(lobby_id, "state"),
			"num_members": Steam.getNumLobbyMembers(lobby_id),
		}
	)
	lobby_match_list_updated.emit(list)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Failed to join lobby: %s" % response)
		refresh_lobby_list()
		lobby_joined.emit(_describe_join_failure(response))
		return

	current_lobby_id = lobby_id
	_make_p2p_handshake()
	var peer := SteamMultiplayerPeer.new()
	var error := peer.connect_to_lobby(lobby_id)
	if error != OK:
		lobby_joined.emit("Failed to connect to lobby: " + error_string(error))
		return
	get_tree().get_multiplayer().multiplayer_peer = peer
	lobby_joined.emit(null)

func _describe_join_failure(response: int) -> String:
	match response:
		Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: return "This lobby no longer exists."
		Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: return "You don't have permission to join this lobby."
		Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: return "The lobby is now full."
		Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: return "You are banned from this lobby."
		Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: return "You cannot join due to having a limited account."
		Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: return "This lobby is locked or disabled."
		Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: return "This lobby is community locked."
		Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: return "A user in the lobby has blocked you from joining."
		Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: return "A user you have blocked is in the lobby."
	return "Uh... something unexpected happened!"

func _make_p2p_handshake() -> void:
	var host_id := Steam.getLobbyOwner(current_lobby_id)
	Steam.sendP2PPacket(host_id, PackedByteArray([1]), Steam.P2P_SEND_RELIABLE, 0)

func _on_p2p_session_request(peer_id: int, _session_request_flags: int) -> void:
	Steam.acceptP2PSessionWithUser(peer_id)
