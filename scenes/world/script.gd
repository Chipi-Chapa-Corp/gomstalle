extends Node3D

const HOST := "127.0.0.1"
const PORT := 7777
const MAX_CLIENTS := 4

func _ready():
    multiplayer.peer_connected.connect(_on_peer_connected)

    if Settings.is_host:
        print("starting server")
        _start_server()
        _on_peer_connected(multiplayer.get_unique_id())
    else:
        print("connecting to server")
        _connect_to_server()

func _start_server():
    var peer = ENetMultiplayerPeer.new()
    peer.create_server(PORT, MAX_CLIENTS)
    multiplayer.multiplayer_peer = peer

func _connect_to_server():
    var peer = ENetMultiplayerPeer.new()
    peer.create_client(HOST, PORT)
    multiplayer.multiplayer_peer = peer

func _on_peer_connected(peer_id: int) -> void:
    if not multiplayer.is_server():
        print("not server")
        return
    print("server spawning player ", peer_id)
    Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})