extends Node

@onready var world_scene := "res://scenes/world/scene.tscn"
@onready var main_scene := "res://scenes/main/scene.tscn"

const player_spawn_center: Vector3 = Vector3.ZERO
const player_spawn_radius: float = 4.0
const paused_replication_interval_seconds := 3600.0

signal state_changed(state: State)

var is_paused: bool = false

enum State {
	IDLE,
	LOBBY,
	STARTED,
	FINISHED,
}

enum Winner {
	NONE,
	HUNTER,
	HIDERS,
}

var hunter_peer_id: int = 0
var room_id: int = 0
var game_state: State = State.IDLE
var winner: Winner = Winner.NONE
var start_positions: Dictionary = {}
var portal_active: bool = false
var portal_position: Vector3 = Vector3.ZERO
var portal_cinematic_active: bool = false
var _alive_hider_peer_ids: Array[int] = []
var _pending_lobby_prepare_peer_ids: Array[int] = []
var _pending_lobby_ready_peer_ids: Array[int] = []
var _lobby_transition_started := false
var _lobby_restart_pending := false

# --------- PUBLIC API ---------
func create_and_join_lobby(callback: Callable) -> void:
	NetworkManager.lobby_created.connect(func(error):
		if error:
			push_error("Failed to create lobby: %s" % error)
			callback.call(false)
			return
		callback.call(true), Object.CONNECT_ONE_SHOT)
	NetworkManager.create_lobby()

func join_lobby(lobby_id: int, callback: Callable) -> void:
	GameState.room_id = lobby_id
	NetworkManager.lobby_joined.connect(func(error):
		if error:
			push_error("Failed to join lobby: %s" % error)
			callback.call(false)
			return
		callback.call(true), Object.CONNECT_ONE_SHOT)
	NetworkManager.join_lobby(lobby_id)

func enter_lobby() -> void:
	get_tree().change_scene_to_file(world_scene)
	_set_state(State.LOBBY)

func start_game() -> Error:
	var peer_ids := NetworkManager.get_connected_peer_ids()
	if peer_ids.is_empty():
		return FAILED
	var index = randi() % peer_ids.size()
	hunter_peer_id = peer_ids[index]
	_calculate_positions()
	rpc("_notify_game_start", hunter_peer_id, start_positions)
	_apply_game_start(hunter_peer_id, start_positions)
	return OK

func hider_killed(peer_id: int) -> void:
	if not multiplayer.is_server() or game_state != State.STARTED or not _alive_hider_peer_ids.has(peer_id):
		return
	_alive_hider_peer_ids.erase(peer_id)
	if _alive_hider_peer_ids.is_empty():
		_finish_game(Winner.HUNTER)

func hider_escaped(peer_id: int) -> void:
	if not multiplayer.is_server() or game_state != State.STARTED or not _alive_hider_peer_ids.has(peer_id):
		return
	_finish_game(Winner.HIDERS)

func restart_lobby() -> void:
	if not multiplayer.is_server() or game_state != State.FINISHED:
		return
	_pending_lobby_prepare_peer_ids.assign(multiplayer.get_peers())
	_pause_round_synchronizers()
	rpc("_prepare_lobby_restart")
	if _pending_lobby_prepare_peer_ids.is_empty():
		_begin_lobby_transition()

func lobby_ready() -> void:
	if not _lobby_restart_pending:
		return
	_lobby_restart_pending = false
	rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, "_confirm_lobby_ready")

func reset(state: State) -> void:
	room_id = 0
	_reset_round(state)

func _reset_round(state: State) -> void:
	is_paused = false
	start_positions.clear()
	hunter_peer_id = 0
	winner = Winner.NONE
	portal_active = false
	portal_position = Vector3.ZERO
	portal_cinematic_active = false
	_alive_hider_peer_ids.clear()
	_pending_lobby_prepare_peer_ids.clear()
	_pending_lobby_ready_peer_ids.clear()
	_lobby_transition_started = false
	_lobby_restart_pending = false
	_set_state(state)

func quit(_multiplayer_api: MultiplayerAPI) -> void:
	NetworkManager.reset()
	reset(State.IDLE)
	get_tree().change_scene_to_file(main_scene)
	_set_state(State.IDLE)

func set_local_paused(new_is_paused: bool) -> void:
	is_paused = new_is_paused

# --------- UTILS ---------
func _set_state(state: State) -> void:
	game_state = state
	state_changed.emit(game_state)

@rpc("authority", "call_remote", "reliable")
func _notify_game_start(new_hunter_peer_id: int, new_positions: Dictionary) -> void:
	_apply_game_start(new_hunter_peer_id, new_positions)

func _apply_game_start(new_hunter_peer_id: int, new_positions: Dictionary) -> void:
	hunter_peer_id = new_hunter_peer_id
	start_positions = new_positions
	winner = Winner.NONE
	_alive_hider_peer_ids.clear()
	for peer_id in start_positions:
		if peer_id != hunter_peer_id:
			_alive_hider_peer_ids.append(peer_id)
	_set_state(State.STARTED)

func _finish_game(new_winner: Winner) -> void:
	rpc("_notify_game_finish", new_winner)
	_apply_game_finish(new_winner)

@rpc("authority", "call_remote", "reliable")
func _notify_game_finish(new_winner: Winner) -> void:
	_apply_game_finish(new_winner)

func _apply_game_finish(new_winner: Winner) -> void:
	if game_state != State.STARTED:
		return
	winner = new_winner
	_set_state(State.FINISHED)

@rpc("authority", "call_remote", "reliable")
func _prepare_lobby_restart() -> void:
	_pause_round_synchronizers()
	rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, "_confirm_lobby_prepare")

func _pause_round_synchronizers() -> void:
	for node in get_tree().get_nodes_in_group("round_synchronizers"):
		var synchronizer := node as MultiplayerSynchronizer
		synchronizer.replication_interval = paused_replication_interval_seconds
		synchronizer.delta_interval = paused_replication_interval_seconds

@rpc("any_peer", "call_remote", "reliable")
func _confirm_lobby_prepare() -> void:
	if not multiplayer.is_server() or game_state != State.FINISHED:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _pending_lobby_prepare_peer_ids.has(peer_id):
		return
	_pending_lobby_prepare_peer_ids.erase(peer_id)
	if _pending_lobby_prepare_peer_ids.is_empty():
		_begin_lobby_transition()

func _begin_lobby_transition() -> void:
	if _lobby_transition_started:
		return
	_lobby_transition_started = true
	for player in get_tree().get_nodes_in_group("players"):
		player.queue_free()
	_pending_lobby_ready_peer_ids.assign(multiplayer.get_peers())
	rpc("_notify_lobby_restart")
	if _pending_lobby_ready_peer_ids.is_empty():
		_apply_lobby_restart()

@rpc("authority", "call_remote", "reliable")
func _notify_lobby_restart() -> void:
	while not get_tree().get_nodes_in_group("players").is_empty():
		await get_tree().process_frame
	_reset_round(State.LOBBY)
	_lobby_restart_pending = true
	get_tree().change_scene_to_file(world_scene)

@rpc("any_peer", "call_remote", "reliable")
func _confirm_lobby_ready() -> void:
	if not multiplayer.is_server() or game_state != State.FINISHED:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _pending_lobby_ready_peer_ids.has(peer_id):
		return
	_pending_lobby_ready_peer_ids.erase(peer_id)
	if _pending_lobby_ready_peer_ids.is_empty():
		_apply_lobby_restart()

func _apply_lobby_restart() -> void:
	_reset_round(State.LOBBY)
	get_tree().change_scene_to_file(world_scene)

func _calculate_positions() -> Dictionary:
	start_positions.clear()
	start_positions[hunter_peer_id] = player_spawn_center
	var hider_ids: Array[int] = NetworkManager.get_connected_peer_ids().filter(func(id): return id != hunter_peer_id)
	var hider_count := hider_ids.size()
	if hider_count == 0:
		return start_positions
	var angle_step := TAU / float(hider_count)
	for index in hider_count:
		var peer_id := hider_ids[index]
		var angle := angle_step * index
		var player_position := player_spawn_center + Vector3(cos(angle), 0.0, sin(angle)) * player_spawn_radius
		start_positions[peer_id] = player_position
	return start_positions
