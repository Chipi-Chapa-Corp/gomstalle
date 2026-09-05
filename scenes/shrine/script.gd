extends Interactable

@export var mesh: MeshInstance3D
@export var label: Label3D

@export var required_amount: int = 6
@export var current_amount: int = 0
@export var required_amount_per_use: int = 3
signal filled(shrine: Node)
var is_filled := false
var is_active := true
var _active_collision_layer: int

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return true

func get_hunter_can_interact() -> bool:
	return false

func _can_interact(_enable: bool, payload: Dictionary) -> bool:
	var caller := resolve_player(int(payload["peer_id"]))
	return is_active and not is_filled and GameState.game_state in [GameState.State.HIDING, GameState.State.STARTED] \
		and caller != null and caller.inventory.has_item(CharacterInventory.InventoryItem.WOOD, required_amount_per_use)

func do_interact(_enable: bool, payload: Dictionary) -> void:
	var caller: CharacterBody3D = payload.get("caller")
	if caller == null:
		return
	if multiplayer.is_server():
		caller.inventory.remove_item(CharacterInventory.InventoryItem.WOOD, required_amount_per_use)
	current_amount += required_amount_per_use
	label.text = "%d / %d" % [current_amount, required_amount]
	if current_amount >= required_amount and not is_filled:
		is_filled = true
		collision_layer = 0
		label.text = "KINDLED"
		filled.emit(self)

func set_active(active: bool) -> void:
	is_active = active
	get_parent().visible = active
	collision_layer = _active_collision_layer if active else 0

func _ready() -> void:
	super._ready()
	_active_collision_layer = collision_layer
	label.text = "%d / %d" % [current_amount, required_amount]
