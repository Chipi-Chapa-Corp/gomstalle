extends Interactable

@export var mesh: MeshInstance3D
@export var label: Label3D

@export var required_amount: int = 10
@export var current_amount: int = 0
@export var required_amount_per_use: int = 1
signal filled(shrine: Node)
var is_filled := false

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return true

func get_hunter_can_interact() -> bool:
	return false

func _can_interact(_enable: bool, payload: Dictionary) -> bool:
	var caller := resolve_player(int(payload["peer_id"]))
	return caller != null and caller.inventory.has_item(CharacterInventory.InventoryItem.WOOD, required_amount_per_use)

func do_interact(_enable: bool, payload: Dictionary) -> void:
	var caller: CharacterBody3D = payload.get("caller")
	if caller == null:
		return
	if multiplayer.is_server():
		caller.inventory.remove_item(CharacterInventory.InventoryItem.WOOD, required_amount_per_use)
	current_amount += required_amount_per_use
	label.text = str(current_amount - required_amount)
	if current_amount >= required_amount and not is_filled:
		is_filled = true
		filled.emit(self)
		get_parent().queue_free()

func _ready() -> void:
	super._ready()
	label.text = str(current_amount - required_amount)
