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

func perform_interact(enable: bool, metadata: Dictionary) -> void:
	rpc("sync_take", 1 if enable else -1)

func _ready():
	super._ready()
	label.text = str(current_amount)

@rpc("any_peer", "call_local", "reliable")
func sync_take(amount: int) -> void:
	current_amount -= amount
	label.text = str(current_amount)
	if current_amount <= 0:
		get_parent().queue_free() # TODO: Sync
