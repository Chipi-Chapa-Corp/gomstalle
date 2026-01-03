extends Interactable

@export var mesh: MeshInstance3D
@export var label: Label3D

@export var required_amount: int = 10
@export var current_amount: int = 0
@export var required_amount_per_use: int = 1

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return true

func get_hunter_can_interact() -> bool:
	return false

func perform_interact(_enable: bool, metadata: Dictionary) -> void:
	var target = Utils.resolve_node(metadata.get("target"))
	if target == null or not target.inventory.has_item(CharacterInventory.InventoryItem.WOOD, required_amount_per_use):
		return
	target.inventory.remove_item(CharacterInventory.InventoryItem.WOOD, required_amount_per_use)
	rpc("sync_interact")

func _ready() -> void:
	label.text = str(current_amount - required_amount)

@rpc("any_peer", "call_local", "reliable")
func sync_interact() -> void:
	current_amount += required_amount_per_use
	label.text = str(current_amount - required_amount)
	if current_amount >= required_amount:
		get_parent().queue_free() # TODO: Sync
