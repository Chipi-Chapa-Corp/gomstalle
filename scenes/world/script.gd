extends Node3D

const MAX_CLIENTS := 4

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)

	if Settings.is_host:
		print("starting server")
		_start_server(func(): _on_peer_connected(multiplayer.get_unique_id()))
	else:
		print("connecting to server")
		_connect_to_server()

func _start_server(cb: Callable):
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(Settings.lobby_port, MAX_CLIENTS)

	var on_connected = func():
		Registry.create_room(Settings.lobby_host, Settings.lobby_port, "duo", "1.0.0", MAX_CLIENTS)

	var on_created = func(_room_id: String, _token: String):
		cb.call()

	Registry.created.connect(on_created)
	Registry.connected.connect(on_connected)
	var ok := await Registry.ensure_connected(Settings.get_registry_url())
	if not ok:
		print("Error: failed to connect to registry")
		return

	multiplayer.multiplayer_peer = peer

func _connect_to_server():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(Settings.lobby_host, Settings.lobby_port)
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		print("not server")
		return
	print("server spawning player ", peer_id)
	$UI/HUD/Start.visible = true
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})

func _on_start() -> void:
	pass
