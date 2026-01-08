extends Node
class_name WorldPlayerListUtils

var world: Node3D
var spawner: Node
var player_list_item_sample_persistent: Control

func _init(node: Node3D, spawner_node: Node) -> void:
	world = node
	spawner = spawner_node

func initialize() -> void:
	player_list_item_sample_persistent = world.player_list_item_sample.duplicate()
	player_list_item_sample_persistent.visible = true

func handle_peer_connected(peer_id: int) -> void:
	if world.multiplayer.is_server():
		world.start_button.visible = true
		spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})

func handle_peer_list_changed(peers: Array[Dictionary]) -> void:
	for child in world.player_list.get_children():
		world.player_list.remove_child(child)
	for peer in peers:
		var item = player_list_item_sample_persistent.duplicate()
		item.get_node("Container/Label").text = peer["name"]
		world.player_list.add_child(item)
