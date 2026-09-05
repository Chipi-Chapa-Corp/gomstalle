extends Node

var _host: bool
var _client_peer_id: int = 0
var _client_stages: Dictionary[String, Dictionary] = {}
var _checks: Array[String] = []
var _failed: bool = false
var _placement_sequence: int = 0
var _movement_origin := Vector3.ZERO

func _ready() -> void:
	name = "NetworkRoundScenario"
	_host = OS.get_environment("GOMSTALLE_E2E_ROLE") == "HOST"
	_run.call_deferred()

func _run() -> void:
	Settings.preferred_role = 1
	Settings.player_name = "Lantern Knight" if _host else "Little Bones"
	GameState.solo_session = false
	GameState.target_player_count = 4
	NetworkManager.use_local_backend()
	if _host:
		GameState.create_and_join_lobby(_on_lobby_created)
	else:
		GameState.join_lobby(1, _on_lobby_created)

func _on_lobby_created(success: bool) -> void:
	if not success:
		_fail("The real ENet lobby could not connect.")
		return
	GameState.enter_lobby()
	if _host:
		_run_host()
	else:
		_run_client()

func _world_ready() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.get("round_utils") != null and scene.round_utils.initialized

func _world() -> Node3D:
	return get_tree().current_scene as Node3D

func _player(peer_id: int) -> CharacterBody3D:
	return _world().player_container.get_node(str(peer_id)) as CharacterBody3D

func _local_player() -> CharacterBody3D:
	return _player(multiplayer.get_unique_id())

func _run_host() -> void:
	if not await _wait(_world_ready, "host world and bot navigation"):
		return
	var ready_file := FileAccess.open(OS.get_environment("GOMSTALLE_E2E_READY"), FileAccess.WRITE)
	ready_file.store_string("hosting")
	ready_file.close()
	print("NETWORK_HOST_READY")
	if not await _wait(func(): return NetworkManager.get_connected_peer_ids().size() == 2, "two real ENet peers"):
		return
	for peer_id in NetworkManager.get_connected_peer_ids():
		if peer_id != multiplayer.get_unique_id():
			_client_peer_id = peer_id
	if not await _wait(func(): return _client_stages.has("world_ready"), "client world contents"):
		return
	if not _require(_world().player_container.get_child_count() == 4, "Four participants include two humans and two bots."):
		return
	var client_world := _client_stages["world_ready"]
	if not _require(client_world["wood_piles"] == _world().get_node("Generated").get_child_count()
		and client_world["shrines"] == 3, "Late client received the same generated fuel and active shrines."):
		return
	_pause_bots()
	if not _require(GameState.start_game(multiplayer.get_unique_id()) == OK, "Host starts the round."):
		return
	if not await _wait(func(): return _client_stages.has("hiding"), "remote hiding grace"):
		return
	_movement_origin = _player(_client_peer_id).global_position
	_move_client.rpc_id(_client_peer_id)
	if not await _wait(func(): return _client_stages.has("movement"), "remote input movement"):
		return
	if not _require(_player(_client_peer_id).global_position.distance_to(_movement_origin) > 1.5, "Client movement reaches the host."):
		return
	if not _require(not GameState.can_player_act(multiplayer.get_unique_id()), "Knight cannot move during hiding grace."):
		return
	GameState.advance_round(GameState.remaining_seconds)
	if not await _wait(func(): return _client_stages.has("hunt"), "remote hunt transition"):
		return
	var door: Door
	for candidate in get_tree().get_nodes_in_group("interactible"):
		if candidate is Door:
			door = candidate
			break
	if not await _interact_client(door, "door"):
		return
	if not await _wait(func(): return not is_zero_approx(door.open_target_degrees), "authoritative door opens"):
		return
	_checks.append("Door interaction crosses ENet from real client input.")
	var pile: Interactable
	for candidate in _world().get_node("Generated").get_children():
		var receiver := candidate.get_node("Receiver") as Interactable
		if receiver.current_amount >= 6:
			pile = receiver
			break
	if not await _interact_client(pile, "fuel_first") or not await _interact_client(pile, "fuel_second"):
		return
	if not await _wait(func(): return _player(_client_peer_id).inventory.items[CharacterInventory.InventoryItem.WOOD] == 6, "six authoritative fuel"):
		return
	var shrine := get_node(_world().shrine_utils.active_paths[0]) as Interactable
	if not await _interact_client(shrine, "offering"):
		return
	if not await _wait(func(): return shrine.current_amount == 3 and _player(_client_peer_id).inventory.items[CharacterInventory.InventoryItem.WOOD] == 3, "offering consumes fuel once"):
		return
	_checks.append("Remote fuel and shrine offering agree on both peers.")
	if not _place_hunter_for_capture():
		return
	Input.action_press("attack")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("attack")
	if not await _wait(func(): return GameState.captured_peer_ids.has(_client_peer_id) and _client_stages.has("captured"), "host sword capture replicates"):
		return
	for player in _world().player_container.get_children():
		if player.is_bot:
			GameState.record_capture(player.peer_id)
	if not await _wait(func(): return _client_stages.has("first_results"), "knight victory results"):
		return
	_checks.append("Captured skeletons cannot escape and knight victory is shared.")
	GameState.restart_round()
	if not await _wait(func(): return _world_ready() and GameState.game_state == GameState.State.LOBBY and _client_stages.has("rematch_lobby"), "fresh rematch lobby"):
		return
	_pause_bots()
	if not _require(not GameState.portal_active and GameState.captured_peer_ids.is_empty(), "Rematch clears portal and captured roster."):
		return
	GameState.start_game(multiplayer.get_unique_id())
	if not await _wait(func(): return _client_stages.has("second_hiding"), "second round role setup"):
		return
	GameState.advance_round(GameState.remaining_seconds)
	var helper: CharacterBody3D
	for player in _world().player_container.get_children():
		if player.is_bot:
			helper = player
			break
	for shrine_path in _world().shrine_utils.active_paths:
		var active_shrine := get_node(shrine_path) as Interactable
		helper.global_position = _interaction_position(helper, active_shrine)
		helper.inventory.add_item(CharacterInventory.InventoryItem.WOOD, 6)
		active_shrine.interact_for_player(helper, true)
		await get_tree().create_timer(0.4).timeout
		active_shrine.interact_for_player(helper, true)
		await get_tree().create_timer(0.4).timeout
	if not await _wait(func(): return GameState.portal_active and not GameState.portal_cinematic_active and _client_stages.has("portal"), "all shrines reveal the portal"):
		return
	if not await _place_client(GameState.portal_position + Vector3.UP * 0.2):
		return
	if not await _wait(func(): return GameState.escaped_peer_ids.has(_client_peer_id) and _client_stages.has("escaped"), "remote skeleton escapes through portal"):
		return
	for player in _world().player_container.get_children():
		if player.is_bot:
			GameState.record_capture(player.peer_id)
	if not await _wait(func(): return _client_stages.has("second_results"), "skeleton victory results"):
		return
	_checks.append("A fresh round opens its portal and a remote escape wins.")
	GameState.quit(multiplayer)
	await get_tree().create_timer(0.3).timeout
	_checks.append("Host departure closes the real connection.")
	_finish(true)

func _run_client() -> void:
	if not await _wait(_world_ready, "client world readiness"):
		return
	_report_stage("world_ready", {"wood_piles": _world().get_node("Generated").get_child_count(), "shrines": _world().shrine_utils.active_paths.size()})
	if not await _wait(func(): return GameState.game_state == GameState.State.HIDING, "hiding state"):
		return
	if not _require(not _local_player().is_hunter and GameState.can_player_act(multiplayer.get_unique_id()), "Client receives skeleton role before hunting."):
		return
	_report_stage("hiding")
	if not await _wait(func(): return GameState.game_state == GameState.State.STARTED, "hunt state"):
		return
	_report_stage("hunt")
	if not await _wait(func(): return GameState.captured_peer_ids.has(multiplayer.get_unique_id()) and _local_player().is_dead, "local capture state"):
		return
	_report_stage("captured")
	if not await _wait(func(): return GameState.game_state == GameState.State.RESULTS and GameState.winner == 0, "knight result"):
		return
	_report_stage("first_results")
	if not await _wait(func(): return _world_ready() and GameState.game_state == GameState.State.LOBBY, "rematch lobby"):
		return
	_report_stage("rematch_lobby")
	if not await _wait(func(): return GameState.game_state == GameState.State.HIDING, "second hiding state"):
		return
	_report_stage("second_hiding")
	if not await _wait(func(): return GameState.portal_active and not GameState.portal_cinematic_active, "remote portal reveal"):
		return
	_report_stage("portal")
	if not await _wait(func(): return GameState.escaped_peer_ids.has(multiplayer.get_unique_id()), "local escape state"):
		return
	if not _require(not GameState.can_player_act(multiplayer.get_unique_id()), "Escaped players leave active play."):
		return
	_report_stage("escaped")
	if not await _wait(func(): return GameState.game_state == GameState.State.RESULTS and GameState.winner == 1, "skeleton result"):
		return
	_report_stage("second_results")
	if not await _wait(func(): return GameState.game_state == GameState.State.IDLE, "host departure returns client to menu"):
		return
	_checks.append("Host departure returns the client to the menu.")
	_finish(true)

func _pause_bots() -> void:
	for player in _world().player_container.get_children():
		if player.is_bot:
			player.set_physics_process(false)

func _interact_client(target: Interactable, stage: String) -> bool:
	var position := _interaction_position(_player(_client_peer_id), target)
	if _failed or not await _place_client(position):
		return false
	_exercise_interaction.rpc_id(_client_peer_id, target.get_path(), stage)
	return await _wait(func(): return _client_stages.has(stage), "client interaction " + stage)

func _interaction_position(player: CharacterBody3D, target: Interactable) -> Vector3:
	var original_position := player.global_position
	var navigation: CastleNavigation = _world().round_utils.navigation
	var candidates: Array[Vector3] = []
	for identifier in navigation.graph.get_point_ids():
		var position := navigation.graph.get_point_position(identifier)
		if Vector2(position.x - target.global_position.x, position.z - target.global_position.z).length() < 2.0 \
			and absf(position.y - target.global_position.y) < 2.0:
			candidates.append(position + Vector3.UP * 0.15)
	candidates.sort_custom(func(first: Vector3, second: Vector3): return first.distance_squared_to(target.global_position) < second.distance_squared_to(target.global_position))
	for candidate in candidates:
		player.global_position = candidate
		player.interactions._update_target()
		if player.closest_item == target and target.can_player_interact(player, true):
			player.global_position = original_position
			return candidate
	player.global_position = original_position
	_fail("No reachable input position for " + str(target.get_path()))
	return original_position

func _place_client(position: Vector3) -> bool:
	_placement_sequence += 1
	var stage := "placed_%d" % _placement_sequence
	_place_local.rpc_id(_client_peer_id, position, stage)
	return await _wait(func(): return _client_stages.has(stage) and _player(_client_peer_id).global_position.distance_to(position) < 0.6, stage)

func _place_hunter_for_capture() -> bool:
	var hunter := _local_player()
	var target := _player(_client_peer_id)
	for index in 8:
		var angle := float(index) * TAU / 8.0
		var position := target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.8
		var navigation: CastleNavigation = _world().round_utils.navigation
		hunter.global_position = navigation.graph.get_point_position(navigation.graph.get_closest_point(position)) + Vector3.UP * 0.1
		var direction := target.global_position - hunter.global_position
		hunter.model.rotation.y = atan2(direction.x, direction.z)
		if hunter.can_reach_attack(target):
			return true
	return _require(false, "A legal sword capture fixture exists.")

@rpc("authority", "call_remote", "reliable")
func _place_local(position: Vector3, stage: String) -> void:
	_local_player().global_position = position
	_local_player().velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report_stage(stage)

@rpc("authority", "call_remote", "reliable")
func _move_client() -> void:
	Input.action_press("move_forward")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(0.2).timeout
	_report_stage("movement")

@rpc("authority", "call_remote", "reliable")
func _exercise_interaction(target_path: NodePath, stage: String) -> void:
	await get_tree().create_timer(0.6).timeout
	var target := get_node(target_path)
	_local_player().interactions._update_target()
	if not _require(_local_player().closest_item == target, "Real input selects " + stage):
		return
	Input.action_press("interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().create_timer(0.25).timeout
	_report_stage(stage)

func _report_stage(stage: String, data: Dictionary = {}) -> void:
	_checks.append(stage)
	print("NETWORK_STAGE client ", stage)
	_receive_stage.rpc_id(1, stage, data)

@rpc("any_peer", "call_remote", "reliable")
func _receive_stage(stage: String, data: Dictionary) -> void:
	if not _host or multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
	_client_stages[stage] = data

func _wait(condition: Callable, description: String, timeout: float = 25.0, fail_on_timeout: bool = true) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call():
		if _failed:
			return false
		if Time.get_ticks_msec() >= deadline:
			if fail_on_timeout:
				_fail("Timed out waiting for " + description)
			return false
		await get_tree().process_frame
	return true

func _require(condition: bool, description: String) -> bool:
	if condition:
		_checks.append(description)
	else:
		_fail(description)
	return condition

func _fail(description: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("NETWORK_FLOW " + description)
	_finish(false)

func _finish(passed: bool) -> void:
	Input.action_release("move_forward")
	Input.action_release("interact")
	Input.action_release("attack")
	var result := {"passed": passed, "checks": _checks, "player_count": 4, "game_started": _checks.size() > 2,
		"door_opened": _client_stages.has("door") if _host else _checks.has("door")}
	var result_file := FileAccess.open(OS.get_environment("GOMSTALLE_E2E_RESULT"), FileAccess.WRITE)
	result_file.store_string(JSON.stringify(result))
	result_file.close()
	print("PASS network round" if passed else "FAIL network round")
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
