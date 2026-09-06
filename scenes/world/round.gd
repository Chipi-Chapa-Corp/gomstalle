extends Node
class_name WorldRoundUtils

const ESCAPE_RADIUS: float = 1.65

var world: Node3D
var navigation: CastleNavigation
var initialized: bool = false

func _init(node: Node3D) -> void:
	world = node
	name = "Round"

func initialize() -> void:
	NetworkManager.player_left.connect(world.player_list_utils.handle_player_left)
	if multiplayer.is_server():
		world.shrine_utils.choose_active_shrines()
		world.player_list_utils.ensure_bot_count(GameState.target_player_count)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if multiplayer.is_server():
		navigation = CastleNavigation.new(world)
		navigation.build()
		Generator.generate_for_world(world)
		await get_tree().physics_frame
		await get_tree().physics_frame
		initialized = true
		if GameState.solo_session:
			start_selected_round()
	else:
		_client_world_ready.rpc_id(1)

func start_selected_round() -> Error:
	if not initialized or not multiplayer.is_server():
		return ERR_BUSY
	var local_id := multiplayer.get_unique_id()
	var candidates: Array[int] = []
	for player in world.player_container.get_children():
		if Settings.preferred_role != 0 or player.peer_id != local_id:
			candidates.append(player.peer_id)
	if candidates.is_empty():
		return FAILED
	var hunter_id: int = local_id if Settings.preferred_role == 1 else candidates.pick_random()
	return GameState.start_game(hunter_id)

func _physics_process(delta: float) -> void:
	if not initialized or not multiplayer.is_server():
		return
	GameState.advance_round(delta)
	if GameState.game_state != GameState.State.STARTED or not GameState.portal_active or GameState.portal_cinematic_active:
		return
	for player in world.player_container.get_children():
		if player.is_hunter or not GameState.can_player_act(player.peer_id):
			continue
		var offset: Vector3 = player.global_position - GameState.portal_position
		if Vector2(offset.x, offset.z).length() <= ESCAPE_RADIUS and absf(offset.y) <= 2.0:
			GameState.record_escape(player.peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _client_world_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	while not initialized:
		await get_tree().process_frame
	Generator.synchronize_peer(peer_id)
	_configure_shrines.rpc_id(peer_id, world.shrine_utils.active_paths)
	GameState._publish_round()

@rpc("authority", "call_remote", "reliable")
func _configure_shrines(paths: Array[NodePath]) -> void:
	world.shrine_utils.configure_active_shrines(paths)
	initialized = true

func _exit_tree() -> void:
	NetworkManager.player_left.disconnect(world.player_list_utils.handle_player_left)
