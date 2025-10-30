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
	rpc("sync_add_item", item, amount)

func remove_item(item: InventoryItem, amount: int) -> void:
	rpc("sync_remove_item", item, amount)

@rpc("any_peer", "call_local", "reliable")
func sync_add_item(item: InventoryItem, amount: int) -> void:
	items[item] = items.get(item, 0) + amount
	update_ui()

@rpc("any_peer", "call_local", "reliable")
func sync_remove_item(item: InventoryItem, amount: int) -> void:
	if has_item(item, amount):
		items[item] -= amount
	update_ui()

func update_ui() -> void:
	if character.is_multiplayer_authority():
		character.inventory_wood_label.text = "Wood · %s" % str(items[InventoryItem.WOOD])
