extends Interactable

var mesh_instance: MeshInstance3D

func get_outline_target() -> MeshInstance3D:
	return mesh_instance

func perform_interact(_enable: bool, _metadata: Dictionary) -> void:
	pass
