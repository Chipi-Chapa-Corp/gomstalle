extends Node

var _ready_ok: bool = false
var current_lobby_id: int = 0

const PACKET_READ_LIMIT: int = 32
const MAX_MEMBERS: int = 10

# --------- PUBLIC API ---------
signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)

func is_ready() -> bool:
	return _ready_ok

func join_lobby(lobby_id: int) -> void:
	Steam.joinLobby(lobby_id)

func leave_lobby() -> void:
	Steam.leaveLobby(GameState.room_id)

func create_lobby() -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_MEMBERS)

func refresh_lobby_list() -> void:
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("_app_id", "gomstalle", Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()
# --------- ---------- ---------

func _ready() -> void:
	if not Steam:
		push_error("Steam singleton not found. You need `SteamGodot SteamMultiplayerPeer` version of editor.")
		return
	
	var ok = Steam.steamInit()
	if ok:
		_listen()
		_check_command_line()
		set_process(true)
		_ready_ok = true
	else:
		push_error("Error: Failed to initialize Steam. Is Steam app running and logged in?")

func _process(_delta: float) -> void:
	if Steam and Steam.has_method("run_callbacks"):
		Steam.run_callbacks()

func _listen():
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.p2p_session_request.connect(_on_p2p_session_request)

func _check_command_line() -> void:
	var args := OS.get_cmdline_args()
	if args.size() > 0:
		if args[0] == "+connect_lobby":
			if int(args[1]) > 0:
				print_debug("Command line lobby ID: %s" % args[1])

func _on_lobby_created(lobby_connect: int, lobby_id: int) -> void:
	if lobby_connect != 1:
		lobby_created.emit("Failed to create lobby: " + str(lobby_connect))
		return
		
	current_lobby_id = lobby_id
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, "_app_id", "gomstalle") # Dev mode only
	Steam.setLobbyData(lobby_id, "name", "Test Name")
	Steam.setLobbyData(lobby_id, "state", "waiting")

	Steam.allowP2PPacketRelay(true)

	lobby_created.emit(null)

func _on_lobby_match_list(lobby_ids: Array) -> void:
	var list = lobby_ids.map(func(lobby_id: int):
		var lobby_name := Steam.getLobbyData(lobby_id, "name")
		var lobby_state := Steam.getLobbyData(lobby_id, "state")
		var lobby_num_members := Steam.getNumLobbyMembers(lobby_id)
		return {
			"id": lobby_id,
			"name": lobby_name,
			"state": lobby_state,
			"num_members": lobby_num_members
		}
	)
	lobby_match_list_updated.emit(list)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		current_lobby_id = lobby_id
		_make_p2p_handshake()
		lobby_joined.emit(null)
	else:
		push_error("Failed to join lobby: %s" % response)
		var fail_reason: String

		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."

		refresh_lobby_list()
		lobby_joined.emit(fail_reason)

func _make_p2p_handshake() -> void:
	var host_id := Steam.getLobbyOwner(current_lobby_id)
	Steam.sendP2PPacket(host_id, PackedByteArray([1]), Steam.P2P_SEND_RELIABLE, 0)

func _on_p2p_session_request(peer_id: int, _session_request_flags: int) -> void:
	Steam.acceptP2PSessionWithUser(peer_id)
