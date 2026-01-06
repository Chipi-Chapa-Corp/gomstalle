extends Node
class_name WorldShrineUtils

var world: Node3D
var shrine_nodes: Array[Node] = []
var shrine_total := 0
var shrine_filled := 0

func _init(node: Node3D) -> void:
	world = node

func register_shrines() -> void:
	shrine_nodes = world.get_tree().get_nodes_in_group("shrine")
	shrine_total = shrine_nodes.size()
	shrine_filled = 0
	for shrine in shrine_nodes:
		if shrine.has_signal("filled") and not shrine.is_connected("filled", _on_shrine_filled):
			shrine.connect("filled", _on_shrine_filled)

func cleanup() -> void:
	for shrine in shrine_nodes:
		if is_instance_valid(shrine) and shrine.has_signal("filled"):
			if shrine.is_connected("filled", _on_shrine_filled):
				shrine.disconnect("filled", _on_shrine_filled)

func _on_shrine_filled(_shrine: Node) -> void:
	shrine_filled += 1
	if shrine_filled != shrine_total:
		return
	if world.multiplayer.is_server():
		world.portal_utils.trigger_portal()
