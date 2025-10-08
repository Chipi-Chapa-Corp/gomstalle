extends Node

@onready var world_scene := "res://scenes/world/scene.tscn"
@onready var main_scene := "res://scenes/main/scene.tscn"

const player_spawn_center: Vector3 = Vector3.ZERO
const player_spawn_radius: float = 4.0

signal state_changed(state: StringName)

var is_paused: bool = false

enum State {
	IDLE,
	LOBBY,
	STARTED,
}

var hunter_peer_id: int = 0
var room_id: int = 0
var game_state: State = State.IDLE
var start_positions: Dictionary = {}

# --------- PUBLIC API ---------
func create_and_join_lobby(callback: Callable) -> void:
	MultiplayerManager.is_host = true
	SteamManager.lobby_created.connect(func(error):
		if error:
			push_error("Failed to create lobby: %s" % error)
			callback.call(false)
			return
		callback.call(true), Object.CONNECT_ONE_SHOT)
	SteamManager.create_lobby()

func join_lobby(lobby_id: int, callback: Callable) -> void:
	MultiplayerManager.is_host = false
	GameState.room_id = lobby_id
	SteamManager.lobby_joined.connect(func(error):
		if error:
			push_error("Failed to join lobby: %s" % error)
			callback.call(false)
			return
		callback.call(true), Object.CONNECT_ONE_SHOT)
	SteamManager.join_lobby(lobby_id)

func enter_lobby() -> void:
	get_tree().change_scene_to_file(world_scene)
	_set_state(State.LOBBY)

func start_game() -> Error:
	if MultiplayerManager.connected_peer_ids.is_empty():
		return FAILED
	var index = randi() % MultiplayerManager.connected_peer_ids.size()
	hunter_peer_id = MultiplayerManager.connected_peer_ids[index]
	_calculate_positions()
	rpc("_notify_game_start", hunter_peer_id, start_positions)
	_apply_game_start(hunter_peer_id, start_positions)
	return OK

func reset(state: State) -> void:
	is_paused = false
	start_positions.clear()
	hunter_peer_id = 0
	room_id = 0
	_set_state(state)

func quit(multiplayer_api: MultiplayerAPI) -> void:
	SteamManager.leave_lobby()
	MultiplayerManager.reset(multiplayer_api)
	reset(State.IDLE)
	get_tree().change_scene_to_file(main_scene)
	_set_state(State.IDLE)

func set_local_paused(new_is_paused: bool) -> void:
	is_paused = new_is_paused

# --------- UTILS ---------
func _set_state(state: State) -> void:
	game_state = state
	state_changed.emit(game_state)

@rpc("any_peer")
func _notify_game_start(new_hunter_peer_id: int, new_positions: Dictionary) -> void:
	_apply_game_start(new_hunter_peer_id, new_positions)

func _apply_game_start(new_hunter_peer_id: int, new_positions: Dictionary) -> void:
	hunter_peer_id = new_hunter_peer_id
	start_positions = new_positions
	_set_state(State.STARTED)

func _calculate_positions() -> Dictionary:
	start_positions.clear()
	start_positions[hunter_peer_id] = player_spawn_center
	var hider_ids: Array[int] = MultiplayerManager.connected_peer_ids.filter(func(id): return id != hunter_peer_id)
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
