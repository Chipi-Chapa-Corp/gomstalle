extends Interactable

func perform_interact(_enable: bool, _meta: Dictionary):
	if not get_is_static():
		set_show_outline(false)

func get_outline_target() -> MeshInstance3D:
	return get_parent()

func get_is_static() -> bool:
	return false
