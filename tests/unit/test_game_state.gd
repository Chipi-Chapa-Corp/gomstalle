extends GutTest

var _original_metadata: Array[Dictionary] = []
var _original_hunter_id: int = 0

func before_each() -> void:
	_original_metadata = MultiplayerManager.connected_players_metadata.duplicate(true)
	_original_hunter_id = GameState.hunter_peer_id

func after_each() -> void:
	MultiplayerManager.connected_players_metadata.clear()
	for metadata in _original_metadata:
		MultiplayerManager.connected_players_metadata.append(metadata)
	GameState.hunter_peer_id = _original_hunter_id

func _set_peers(peer_ids: Array[int]) -> void:
	MultiplayerManager.connected_players_metadata.clear()
	for peer_id in peer_ids:
		MultiplayerManager.connected_players_metadata.append({"peer_id": peer_id})

func test_calculate_positions_single_player() -> void:
	_set_peers([1])
	GameState.hunter_peer_id = 1

	var positions = GameState._calculate_positions()
	assert_eq(positions.size(), 1, "Only hunter should be spawned")
	assert_eq(positions[1], GameState.player_spawn_center, "Hunter should spawn at center")

func test_calculate_positions_multiple_players() -> void:
	_set_peers([1, 2, 3])
	GameState.hunter_peer_id = 1

	var positions = GameState._calculate_positions()
	assert_eq(positions.size(), 3, "All players should be spawned")
	assert_eq(positions[1], GameState.player_spawn_center, "Hunter should spawn at center")

	for peer_id in [2, 3]:
		var distance = positions[peer_id].length()
		assert_almost_eq(distance, GameState.player_spawn_radius, 0.01, "Hider should spawn on radius")
