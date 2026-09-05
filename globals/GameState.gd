extends Node

@onready var world_scene := "res://scenes/world/scene.tscn"
@onready var main_scene := "res://scenes/main/scene.tscn"

const player_spawn_center: Vector3 = Vector3.ZERO
const player_spawn_radius: float = 4.0

signal state_changed(state: State)
signal round_changed

const HIDING_SECONDS: float = 12.0
const HUNT_SECONDS: float = 180.0

var is_paused: bool = false

enum State {
	IDLE,
	LOBBY,
	STARTED,
	HIDING,
	RESULTS,
}

var hunter_peer_id: int = 0
var room_id: int = 0
var game_state: State = State.IDLE
var start_positions: Dictionary = {}
var portal_active: bool = false
var portal_position: Vector3 = Vector3.ZERO
var portal_cinematic_active: bool = false
var remaining_seconds: float = 0.0
var escaped_peer_ids: Array[int] = []
var captured_peer_ids: Array[int] = []
var participant_peer_ids: Array[int] = []
var winner: int = -1
var shrines_completed: int = 0
var shrines_total: int = 0
var target_player_count: int = 4
var solo_session: bool = false
var _clock_publish_time: float = 0.0
var _restarting: bool = false
var _reload_waiting: Array[int] = []

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

func enter_lobby(loaded_world: PackedScene = null) -> void:
	SceneLoading.visible = true
	if loaded_world == null:
		get_tree().change_scene_to_file(world_scene)
	else:
		get_tree().change_scene_to_packed(loaded_world)
	_set_state(State.LOBBY)

func start_game(preferred_hunter_id: int = 0) -> Error:
	if not multiplayer.is_server() or game_state != State.LOBBY:
		return ERR_UNAUTHORIZED
	var peer_ids: Array[int] = []
	for player in get_tree().get_nodes_in_group("players"):
		peer_ids.append(player.peer_id)
	if peer_ids.size() < 2:
		return FAILED
	peer_ids.sort()
	if preferred_hunter_id != 0 and not peer_ids.has(preferred_hunter_id):
		return ERR_INVALID_PARAMETER
	participant_peer_ids = peer_ids
	multiplayer.multiplayer_peer.refuse_new_connections = true
	if preferred_hunter_id != 0:
		hunter_peer_id = preferred_hunter_id
	elif NetworkManager.get_connected_peer_ids().size() == 1:
		hunter_peer_id = peer_ids[0]
	else:
		hunter_peer_id = peer_ids.pick_random()
	_calculate_positions()
	_notify_game_start.rpc(hunter_peer_id, start_positions, participant_peer_ids)
	return OK

func can_player_act(peer_id: int) -> bool:
	if captured_peer_ids.has(peer_id) or escaped_peer_ids.has(peer_id):
		return false
	return game_state == State.LOBBY or game_state == State.STARTED \
		or game_state == State.HIDING and peer_id != hunter_peer_id

func advance_round(delta: float) -> void:
	if not multiplayer.is_server() or game_state not in [State.HIDING, State.STARTED] or portal_cinematic_active:
		return
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	_clock_publish_time += delta
	if is_zero_approx(remaining_seconds):
		if game_state == State.HIDING:
			remaining_seconds = HUNT_SECONDS
			_set_state(State.STARTED)
		else:
			_finish_round()
	if _clock_publish_time >= 0.25:
		_clock_publish_time = 0.0
		_publish_round()

func record_capture(peer_id: int) -> void:
	if not multiplayer.is_server() or game_state != State.STARTED or not _is_unresolved_hider(peer_id):
		return
	_release_item(peer_id)
	captured_peer_ids.append(peer_id)
	_resolve_round()

func record_escape(peer_id: int) -> void:
	if not multiplayer.is_server() or game_state != State.STARTED or not portal_active or not _is_unresolved_hider(peer_id):
		return
	_release_item(peer_id)
	escaped_peer_ids.append(peer_id)
	_resolve_round()

func player_departed(peer_id: int) -> void:
	_reload_waiting.erase(peer_id)
	if not multiplayer.is_server() or game_state not in [State.HIDING, State.STARTED] or not participant_peer_ids.has(peer_id):
		return
	_release_item(peer_id)
	if peer_id == hunter_peer_id:
		_finish_round(1)
		return
	if _is_unresolved_hider(peer_id):
		captured_peer_ids.append(peer_id)
	_resolve_round()

func set_shrine_progress(completed: int, total: int) -> void:
	if not multiplayer.is_server():
		return
	shrines_completed = completed
	shrines_total = total
	_publish_round()

func restart_round() -> void:
	if not multiplayer.is_server() or game_state != State.RESULTS or _restarting:
		return
	_restarting = true
	_reload_waiting.assign(multiplayer.get_peers())
	_reload_waiting.append(multiplayer.get_unique_id())
	_prepare_reload.rpc()
	while not _reload_waiting.is_empty():
		await get_tree().process_frame
	for player in get_tree().get_nodes_in_group("players"):
		player.queue_free()
	await get_tree().process_frame
	_reload_world.rpc()

@rpc("authority", "call_local", "reliable")
func _prepare_reload() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			var synchronizer := player.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer
			synchronizer.replication_config = SceneReplicationConfig.new()
	_acknowledge_reload.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _acknowledge_reload() -> void:
	if not multiplayer.is_server() or not _restarting:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_reload_waiting.erase(multiplayer.get_unique_id() if sender_id == 0 else sender_id)

@rpc("authority", "call_local", "reliable")
func _reload_world() -> void:
	SceneLoading.visible = true
	var lobby_id := room_id
	reset(State.LOBBY)
	room_id = lobby_id
	if multiplayer.is_server():
		multiplayer.multiplayer_peer.refuse_new_connections = false
	get_tree().reload_current_scene()

func _is_unresolved_hider(peer_id: int) -> bool:
	return participant_peer_ids.has(peer_id) and peer_id != hunter_peer_id \
		and not captured_peer_ids.has(peer_id) and not escaped_peer_ids.has(peer_id)

func _release_item(peer_id: int) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if player.peer_id == peer_id and is_instance_valid(player.item):
			player.item.release_from(player)

func _resolve_round() -> void:
	for peer_id in participant_peer_ids:
		if _is_unresolved_hider(peer_id):
			_publish_round()
			return
	_finish_round()

func _finish_round(result: int = -1) -> void:
	winner = result if result >= 0 else int(not escaped_peer_ids.is_empty())
	_set_state(State.RESULTS)
	_publish_round()

func _publish_round() -> void:
	_receive_round.rpc(game_state, remaining_seconds, escaped_peer_ids, captured_peer_ids, winner, shrines_completed, shrines_total)

@rpc("authority", "call_local", "reliable")
func _receive_round(state: State, seconds: float, escaped: Array[int], captured: Array[int], result: int, completed: int, total: int) -> void:
	remaining_seconds = seconds
	escaped_peer_ids = escaped.duplicate()
	captured_peer_ids = captured.duplicate()
	winner = result
	shrines_completed = completed
	shrines_total = total
	if game_state != state:
		_set_state(state)
	round_changed.emit()

func reset(state: State) -> void:
	is_paused = false
	start_positions.clear()
	hunter_peer_id = 0
	room_id = 0
	portal_active = false
	portal_position = Vector3.ZERO
	portal_cinematic_active = false
	remaining_seconds = 0.0
	escaped_peer_ids.clear()
	captured_peer_ids.clear()
	participant_peer_ids.clear()
	winner = -1
	shrines_completed = 0
	shrines_total = 0
	_clock_publish_time = 0.0
	_restarting = false
	_reload_waiting.clear()
	_set_state(state)
	round_changed.emit()

func quit(_multiplayer_api: MultiplayerAPI) -> void:
	SceneLoading.visible = false
	solo_session = false
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

@rpc("authority", "call_local", "reliable")
func _notify_game_start(new_hunter_peer_id: int, new_positions: Dictionary, participants: Array[int]) -> void:
	participant_peer_ids = participants.duplicate()
	_apply_game_start(new_hunter_peer_id, new_positions)

func _apply_game_start(new_hunter_peer_id: int, new_positions: Dictionary) -> void:
	hunter_peer_id = new_hunter_peer_id
	start_positions = new_positions
	remaining_seconds = HIDING_SECONDS
	escaped_peer_ids.clear()
	captured_peer_ids.clear()
	winner = -1
	_set_state(State.HIDING)
	round_changed.emit()

func _calculate_positions() -> Dictionary:
	start_positions.clear()
	start_positions[hunter_peer_id] = player_spawn_center
	var roster := participant_peer_ids if not participant_peer_ids.is_empty() else NetworkManager.get_connected_peer_ids()
	var hider_ids: Array[int] = roster.filter(func(peer_id: int): return peer_id != hunter_peer_id)
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
