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

func perform_interact(_enable: bool, metadata: Dictionary) -> void:
	var target = Utils.resolve_node(metadata.get("target"))
	if target == null:
		return
	var amount: int = min(metadata.get("amount", 1), current_amount)
	target.inventory.add_item(CharacterInventory.InventoryItem.WOOD, amount)
	rpc("sync_take", amount)

func _ready():
	super._ready()
	label.text = str(current_amount)

@rpc("any_peer", "call_local", "reliable")
func sync_take(amount: int) -> void:
	current_amount -= amount
	label.text = str(current_amount)
	if current_amount <= 0:
		get_parent().queue_free() # TODO: Sync
