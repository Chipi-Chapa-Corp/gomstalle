extends Node
class_name WorldPlayerListUtils

var world: Node3D
var player_list_item_sample_persistent: Control
var _spawned_peer_ids: Array[int] = []

func _init(node: Node3D) -> void:
	world = node

func initialize() -> void:
	player_list_item_sample_persistent = world.player_list_item_sample.duplicate()
	player_list_item_sample_persistent.visible = false
	add_child(player_list_item_sample_persistent)

func spawn_existing_players() -> void:
	if not world.multiplayer.is_server():
		return
	_spawn_player(world.multiplayer.get_unique_id())
	for peer_id in world.multiplayer.get_peers():
		_spawn_player(peer_id)

func handle_player_joined(peer_id: int) -> void:
	if not world.multiplayer.is_server():
		return
	_spawn_player(peer_id)
	ensure_bot_count(GameState.target_player_count)

func handle_player_left(peer_id: int) -> void:
	if not world.multiplayer.is_server():
		return
	GameState.player_departed(peer_id)
	_remove_player(peer_id)
	if GameState.game_state == GameState.State.LOBBY:
		ensure_bot_count(GameState.target_player_count)

func ensure_bot_count(total_players: int) -> void:
	if not world.multiplayer.is_server() or GameState.game_state != GameState.State.LOBBY:
		return
	var humans := NetworkManager.get_connected_peer_ids().size()
	var needed := maxi(0, total_players - humans)
	var bots: Array[int] = []
	for peer_id in _spawned_peer_ids:
		if peer_id < 0:
			bots.append(peer_id)
	while bots.size() > needed:
		_remove_player(bots.pop_back())
	var next_bot_id := -2
	while bots.size() < needed:
		if not _spawned_peer_ids.has(next_bot_id):
			_spawn_player(next_bot_id)
			bots.append(next_bot_id)
		next_bot_id -= 1

func _remove_player(peer_id: int) -> void:
	_spawned_peer_ids.erase(peer_id)
	var player: Node = world.player_container.get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()

func handle_peer_list_changed(peers: Array[Dictionary]) -> void:
	for child in world.player_list.get_children():
		world.player_list.remove_child(child)
		child.queue_free()
	for peer in peers:
		var item = player_list_item_sample_persistent.duplicate()
		item.visible = true
		item.get_node("Container/Label").text = peer["name"]
		world.player_list.add_child(item)

func _spawn_player(peer_id: int) -> void:
	if _spawned_peer_ids.has(peer_id):
		return
	_spawned_peer_ids.append(peer_id)
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO, "is_bot": peer_id < 0})
