extends Node3D

const USE_STEAM := false # true = Steam transport, false = ENet transport
const MAX_CLIENTS := 4
const ENET_PORT := 25000

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	if Settings.is_host:
		print("starting server")
		_start_server(func(): _on_peer_connected(multiplayer.get_unique_id()))
	else:
		print("connecting to server")
		_connect_to_server()

# ---------------- transport selection ----------------

func _start_server(cb: Callable):
	if USE_STEAM:
		var sp := SteamMultiplayerPeer.new()
		var res := sp.host_with_lobby(SteamManager.current_lobby_id)
		if res != OK: push_error("host_with_lobby failed: %s" % res); return
		multiplayer.multiplayer_peer = sp
		cb.call()
	else:
		var ep := ENetMultiplayerPeer.new()
		var res := ep.create_server(ENET_PORT, MAX_CLIENTS)
		if res != OK: push_error("ENet create_server failed: %s" % res); return
		multiplayer.multiplayer_peer = ep
		Steam.setLobbyData(SteamManager.current_lobby_id, "enet_ip", "127.0.0.1")
		Steam.setLobbyData(SteamManager.current_lobby_id, "enet_port", str(ENET_PORT))
		cb.call()

func _connect_to_server():
	if USE_STEAM:
		var sp := SteamMultiplayerPeer.new()
		var res := sp.connect_to_lobby(SteamManager.current_lobby_id)
		if res != OK: push_error("connect_to_lobby failed: %s" % res); return
		multiplayer.multiplayer_peer = sp
	else:
		var ip := Steam.getLobbyData(SteamManager.current_lobby_id, "enet_ip")
		var port := int(Steam.getLobbyData(SteamManager.current_lobby_id, "enet_port"))
		if ip == "" or port <= 0:
				push_error("Lobby missing ENet endpoint (enet_ip/enet_port)."); return
		var ep := ENetMultiplayerPeer.new()
		var res := ep.create_client(ip, port)
		if res != OK: push_error("ENet create_client failed: %s" % res); return
		multiplayer.multiplayer_peer = ep

func _on_peer_connected(peer_id: int) -> void:
	print("server spawning player ", peer_id)
	$UI/HUD/Start.visible = true
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})
