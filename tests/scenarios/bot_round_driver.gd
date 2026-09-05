extends Node

var _deadline: int
var _last_report: int = 0
var _started: bool = false
var _testing_hunter: bool = false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	_testing_hunter = OS.get_environment("GOMSTALLE_BOT_ROLE") == "HIDER"
	Settings.preferred_role = 0 if _testing_hunter else 1
	GameState.solo_session = false
	GameState.target_player_count = 4
	GameState.create_and_join_lobby(_on_lobby_created)
	_deadline = Time.get_ticks_msec() + 240000

func _on_lobby_created(success: bool) -> void:
	if not success:
		push_error("Bot round could not host.")
		get_tree().quit(1)
		return
	GameState.enter_lobby()
	while get_tree().current_scene == null or get_tree().current_scene.get("round_utils") == null \
		or not get_tree().current_scene.round_utils.initialized:
		await get_tree().process_frame
	var world: Node3D = get_tree().current_scene
	if OS.get_environment("GOMSTALLE_BOT_SHRINE_MODE") == "upper":
		var shrines: Array = world.shrine_utils.shrine_nodes.duplicate()
		shrines.sort_custom(func(first: Node3D, second: Node3D): return first.global_position.y > second.global_position.y)
		var chosen: Array[NodePath] = []
		for index in 3:
			chosen.append(shrines[index].get_path())
		world.shrine_utils.configure_active_shrines(chosen)
	for shrine in world.shrine_utils.shrine_nodes:
		var path: PackedVector3Array = world.round_utils.navigation.find_path(Vector3.ZERO, shrine.global_position)
		var endpoint := path[path.size() - 1]
		print("BOT_ANCHOR target=", shrine.global_position, " endpoint=", endpoint, " distance=", endpoint.distance_to(shrine.global_position))
	world.round_utils.start_selected_round()
	_started = true

func _process(_delta: float) -> void:
	if not _started:
		return
	var now := Time.get_ticks_msec()
	if now - _last_report >= 5000:
		_last_report = now
		_report()
	if GameState.game_state == GameState.State.RESULTS:
		_report()
		var complete := GameState.captured_peer_ids.has(1) if _testing_hunter else GameState.winner == 1 and GameState.shrines_completed == 3 and not GameState.escaped_peer_ids.is_empty()
		print("PASS bot round" if complete else "FAIL bot round")
		get_tree().quit(0 if complete else 1)
	elif now > _deadline:
		push_error("Bot round timed out.")
		get_tree().quit(1)
	return

func _report() -> void:
	var players: Array[Dictionary] = []
	for player in get_tree().get_nodes_in_group("players"):
		var collisions: Array[String] = []
		for index in player.get_slide_collision_count():
			collisions.append(str(player.get_slide_collision(index).get_collider().get_path()))
		var details := {"peer": player.peer_id, "position": str(player.global_position), "wood": player.inventory.items[CharacterInventory.InventoryItem.WOOD], "dead": player.is_dead, "collisions": collisions}
		if player.is_bot:
			details["destination"] = str(player.bot_controller._destination)
			var nearby_doors: Array[Dictionary] = []
			for door in get_tree().get_nodes_in_group("interactible"):
				if door is Door and door.global_position.distance_to(player.global_position) < 4.0:
					nearby_doors.append({"path": str(door.get_path()), "opened": door.open_target_degrees, "accepted": door.can_player_interact(player, true)})
			details["doors"] = nearby_doors
		players.append(details)
	print("BOT_ROUND ", JSON.stringify({"state": GameState.game_state, "remaining": GameState.remaining_seconds,
		"shrines": GameState.shrines_completed, "escaped": GameState.escaped_peer_ids, "players": players}))
