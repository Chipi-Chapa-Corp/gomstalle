extends Node
class_name CharacterInventory

enum InventoryItem {
	WOOD
}

var character: CharacterBody3D
var items: Dictionary = {
	InventoryItem.WOOD: 0,
}

func _init(node: CharacterBody3D) -> void:
	character = node
	update_ui()

func has_item(item: InventoryItem, amount: int) -> bool:
	return items.get(item, 0) >= amount

func add_item(item: InventoryItem, amount: int) -> void:
	if multiplayer.is_server() and item == InventoryItem.WOOD and amount > 0:
		rpc("sync_add_item", item, amount)

func remove_item(item: InventoryItem, amount: int) -> void:
	if multiplayer.is_server() and item == InventoryItem.WOOD and amount > 0:
		rpc("sync_remove_item", item, amount)

@rpc("any_peer", "call_local", "reliable")
func sync_add_item(item: InventoryItem, amount: int) -> void:
	if not _is_server_call() or item != InventoryItem.WOOD or amount <= 0:
		return
	CastleAudio.play_at(&"fuel", character.global_position)
	items[item] = items.get(item, 0) + amount
	update_ui()

@rpc("any_peer", "call_local", "reliable")
func sync_remove_item(item: InventoryItem, amount: int) -> void:
	if not _is_server_call() or item != InventoryItem.WOOD or amount <= 0:
		return
	if has_item(item, amount):
		items[item] -= amount
	update_ui()

func _is_server_call() -> bool:
	var sender_id := multiplayer.get_remote_sender_id()
	return sender_id == MultiplayerPeer.TARGET_PEER_SERVER or sender_id == 0 and multiplayer.is_server()

func update_ui() -> void:
	if character.is_multiplayer_authority():
		character.inventory_wood_label.text = "Wood · %s" % str(items[InventoryItem.WOOD])
