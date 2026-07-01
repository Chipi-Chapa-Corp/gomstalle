extends Node
class_name WorldPlayerListUtils

var world: Node3D
var player_list_item_sample_persistent: Control
var _spawned_peer_ids: Array[int] = []

func _init(node: Node3D) -> void:
	world = node

func initialize() -> void:
	player_list_item_sample_persistent = world.player_list_item_sample.duplicate()
	player_list_item_sample_persistent.visible = true

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

func handle_peer_list_changed(peers: Array[Dictionary]) -> void:
	for child in world.player_list.get_children():
		world.player_list.remove_child(child)
		child.queue_free()
	for peer in peers:
		var item = player_list_item_sample_persistent.duplicate()
		item.get_node("Container/Label").text = peer["name"]
		world.player_list.add_child(item)

func _spawn_player(peer_id: int) -> void:
	if _spawned_peer_ids.has(peer_id):
		return
	_spawned_peer_ids.append(peer_id)
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})
