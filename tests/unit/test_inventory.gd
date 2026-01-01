extends GutTest

const TestCharacterBody = preload("res://tests/helpers/test_character_body.gd")

var _created_nodes: Array[Node] = []

func after_each() -> void:
	for node in _created_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_created_nodes.clear()

func _make_inventory() -> CharacterInventory:
	var character := TestCharacterBody.new()
	add_child(character)
	_created_nodes.append(character)
	var inventory := CharacterInventory.new(character)
	_created_nodes.append(inventory)
	return inventory

func test_inventory_add_remove() -> void:
	var inventory := _make_inventory()

	assert_false(inventory.has_item(CharacterInventory.InventoryItem.WOOD, 1), "Starts with zero wood")

	inventory.sync_add_item(CharacterInventory.InventoryItem.WOOD, 2)
	assert_true(inventory.has_item(CharacterInventory.InventoryItem.WOOD, 2), "Add should increase count")

	inventory.sync_remove_item(CharacterInventory.InventoryItem.WOOD, 1)
	assert_true(inventory.has_item(CharacterInventory.InventoryItem.WOOD, 1), "Remove should decrease count")

	inventory.sync_remove_item(CharacterInventory.InventoryItem.WOOD, 5)
	assert_true(inventory.has_item(CharacterInventory.InventoryItem.WOOD, 1), "Remove should not go below zero")

func test_inventory_updates_ui_for_authority() -> void:
	var inventory := _make_inventory()
	var character := inventory.character as Node

	inventory.sync_add_item(CharacterInventory.InventoryItem.WOOD, 3)
	assert_eq(character.inventory_wood_label.text, "Wood · 3", "UI should reflect current count")

func test_has_item_zero_is_true() -> void:
	var inventory := _make_inventory()
	assert_true(inventory.has_item(CharacterInventory.InventoryItem.WOOD, 0), "Zero amount should always be available")
