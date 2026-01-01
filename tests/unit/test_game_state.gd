extends GutTest

var _original_metadata: Array[Dictionary] = []
var _original_hunter_id: int = 0
var _original_state: GameState.State = GameState.State.IDLE
var _original_positions: Dictionary = {}
var _original_room_id: int = 0
var _original_is_paused := false

func before_each() -> void:
	_original_metadata = MultiplayerManager.connected_players_metadata.duplicate(true)
	_original_hunter_id = GameState.hunter_peer_id
	_original_state = GameState.game_state
	_original_positions = GameState.start_positions.duplicate(true)
	_original_room_id = GameState.room_id
	_original_is_paused = GameState.is_paused

func after_each() -> void:
	MultiplayerManager.connected_players_metadata.clear()
	for metadata in _original_metadata:
		MultiplayerManager.connected_players_metadata.append(metadata)
	GameState.hunter_peer_id = _original_hunter_id
	GameState.game_state = _original_state
	GameState.start_positions = _original_positions.duplicate(true)
	GameState.room_id = _original_room_id
	GameState.is_paused = _original_is_paused

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

func test_calculate_positions_hunter_not_in_peer_list() -> void:
	_set_peers([2, 3])
	GameState.hunter_peer_id = 99

	var positions = GameState._calculate_positions()
	assert_eq(positions.size(), 3, "Hunter should be included even if not in peer list")
	assert_true(positions.has(99), "Hunter position should be present")
	assert_eq(positions[99], GameState.player_spawn_center, "Hunter should still spawn at center")

func test_calculate_positions_single_hider() -> void:
	_set_peers([1, 2])
	GameState.hunter_peer_id = 1

	var positions = GameState._calculate_positions()
	assert_eq(positions.size(), 2, "Hunter and one hider should be spawned")
	assert_eq(positions[1], GameState.player_spawn_center, "Hunter should spawn at center")
	assert_almost_eq(positions[2].length(), GameState.player_spawn_radius, 0.01, "Hider should spawn on radius")

func test_apply_game_start_sets_state_and_positions() -> void:
	var positions := {1: Vector3.ZERO, 2: Vector3(1, 0, 0)}
	GameState._apply_game_start(2, positions)

	assert_eq(GameState.hunter_peer_id, 2, "Apply start should set hunter id")
	assert_eq(GameState.start_positions, positions, "Apply start should set positions")
	assert_eq(GameState.game_state, GameState.State.STARTED, "Apply start should set STARTED state")

func test_notify_game_start_applies_state() -> void:
	var positions := {5: Vector3.ZERO}
	GameState._notify_game_start(5, positions)

	assert_eq(GameState.hunter_peer_id, 5, "Notify should set hunter id")
	assert_eq(GameState.start_positions, positions, "Notify should set positions")
	assert_eq(GameState.game_state, GameState.State.STARTED, "Notify should set STARTED state")

func test_reset_clears_state() -> void:
	GameState.is_paused = true
	GameState.hunter_peer_id = 7
	GameState.room_id = 42
	GameState.start_positions = {1: Vector3(1, 0, 0)}

	GameState.reset(GameState.State.LOBBY)

	assert_false(GameState.is_paused, "Reset should clear pause")
	assert_eq(GameState.hunter_peer_id, 0, "Reset should clear hunter id")
	assert_eq(GameState.room_id, 0, "Reset should clear room id")
	assert_eq(GameState.start_positions.size(), 0, "Reset should clear positions")
	assert_eq(GameState.game_state, GameState.State.LOBBY, "Reset should set state")
