extends Interactable

@export var mesh: MeshInstance3D

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return true

func get_hunter_can_interact() -> bool:
	return false

func perform_interact(_enable: bool, _metadata: Dictionary) -> void:
	pass