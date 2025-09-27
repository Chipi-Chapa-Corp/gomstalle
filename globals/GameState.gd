extends Node

signal started(hunter_peer_id: int)

var connected_peer_ids: Array[int] = []
var hunter_peer_id: int = 0

var game_state: StringName = "lobby"
var start_positions: Dictionary = {}

func sync_connected_peers(multiplayer_api: MultiplayerAPI) -> Array[int]:
	var peer_ids: Array[int] = []
	peer_ids.append(multiplayer_api.get_unique_id())
	var remote_peers := multiplayer_api.get_peers()
	for peer_id in remote_peers:
		peer_ids.append(peer_id)
	set_connected_peers(peer_ids)
	return connected_peer_ids

func set_connected_peers(peer_ids: Array[int]) -> void:
	connected_peer_ids = peer_ids.duplicate()

func start(selected_hunter_peer_id: int, positions: Dictionary) -> void:
	hunter_peer_id = selected_hunter_peer_id
	start_positions = positions.duplicate()
	game_state = "started"
	started.emit(hunter_peer_id)

func reset() -> void:
	connected_peer_ids.clear()
	hunter_peer_id = 0
	game_state = "lobby"
	start_positions.clear()
