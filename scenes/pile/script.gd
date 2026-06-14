extends Interactable

@export var mesh: MeshInstance3D
@export var label: Label3D

@export var current_amount: int = 10

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return true

func get_hunter_can_interact() -> bool:
	return false

func _can_interact(_enable: bool, _payload: Dictionary) -> bool:
	return current_amount > 0

func do_interact(_enable: bool, payload: Dictionary) -> void:
	var caller: CharacterBody3D = payload.get("caller")
	if caller == null:
		return
	var amount: int = min(payload.get("amount", 1), current_amount)
	if amount <= 0:
		return
	if multiplayer.is_server():
		caller.inventory.add_item(CharacterInventory.InventoryItem.WOOD, amount)
	current_amount -= amount
	label.text = str(current_amount)
	if current_amount <= 0:
		get_parent().queue_free()

func _ready():
	super._ready()
	label.text = str(current_amount)
