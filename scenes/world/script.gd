extends Node3D

const MAX_CLIENTS := 4

func _ready():
	if Settings.is_host:
		print("starting server")
		multiplayer.peer_connected.connect(_on_peer_connected)
		_start_server(func(): _on_peer_connected(multiplayer.get_unique_id()))
	else:
		print("connecting to server")
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
	print("server spawning player ", peer_id)
	$UI/HUD/Start.visible = true
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})
