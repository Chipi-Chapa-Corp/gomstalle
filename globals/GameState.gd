extends Node

signal started(hunter_peer_id: int)

var connected_peer_ids: Array[int] = []
var hunter_peer_id: int = 0
var game_started: bool = false

func sync_connected_peers(multiplayer_api: MultiplayerAPI) -> void:
	var peer_ids: Array[int] = []
	peer_ids.append(multiplayer_api.get_unique_id())
	var remote_peers := multiplayer_api.get_peers()
	for peer_id in remote_peers:
		peer_ids.append(int(peer_id))
	set_connected_peers(peer_ids)

func set_connected_peers(peer_ids: Array) -> void:
	var new_connected_peer_ids: Array[int] = []
	for peer_id in peer_ids:
		new_connected_peer_ids.append(int(peer_id))
	connected_peer_ids = new_connected_peer_ids

func mark_started(selected_hunter_peer_id: int) -> void:
	hunter_peer_id = selected_hunter_peer_id
	game_started = true
	started.emit(hunter_peer_id)

func reset() -> void:
	connected_peer_ids.clear()
	hunter_peer_id = 0
	game_started = false
