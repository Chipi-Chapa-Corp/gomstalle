extends Node3D

@export var start_button: Button
@export var menu: Control
@export var hud: Control
@export var player_spawn_center: Vector3 = Vector3.ZERO
@export var player_spawn_radius: float = 4.0
@export var main_scene: PackedScene

const MAX_CLIENTS := 4

func _ready():
	if Settings.is_host:
		multiplayer.peer_connected.connect(_on_peer_connected)
		_start_server(func(): _on_peer_connected(multiplayer.get_unique_id()))
	else:
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
	if multiplayer.is_server():
		start_button.visible = true
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})

func _on_start_pressed():
	if not Settings.is_host:
		return
	start_button.visible = false
	var peers := GameState.sync_connected_peers(multiplayer)
	if peers.is_empty():
		return
	var hunter_peer_id := peers[randi() % peers.size()]
	var positions := _calculate_positions(hunter_peer_id, peers)
	rpc("_notify_game_start", hunter_peer_id, positions)
	_apply_game_start(hunter_peer_id, positions)

@rpc("any_peer")
func _notify_game_start(hunter_peer_id: int, positions: Dictionary) -> void:
	_apply_game_start(hunter_peer_id, positions)

func _apply_game_start(hunter_peer_id: int, positions: Dictionary) -> void:
	GameState.start(hunter_peer_id, positions)
	var local_player := _get_local_player()
	if local_player == null:
		return
	var target_position = positions.get(int(local_player.peer_id), player_spawn_center)
	local_player.global_position = target_position

func _calculate_positions(hunter_peer_id: int, peer_ids: Array[int]) -> Dictionary:
	var positions: Dictionary = {}
	positions[hunter_peer_id] = player_spawn_center
	var hider_ids: Array[int] = []
	for peer_id in peer_ids:
		if peer_id != hunter_peer_id:
			hider_ids.append(peer_id)
	var hider_count := hider_ids.size()
	if hider_count == 0:
		return positions
	var angle_step := TAU / float(hider_count)
	for index in hider_count:
		var peer_id := hider_ids[index]
		var angle := angle_step * index
		var player_position := player_spawn_center + Vector3(cos(angle), 0.0, sin(angle)) * player_spawn_radius
		positions[peer_id] = player_position
	return positions

func _get_local_player() -> Node3D:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			return player
	return null

func _unhandled_input(event: InputEvent) -> void:
	if GameState.game_state != "idle" and event.is_action_pressed("menu"):
		menu.visible = not menu.visible
		hud.visible = not hud.visible
		GameState.set_local_paused(menu.visible)

func _on_quit_pressed() -> void:
	GameState.quit()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_packed(main_scene)
