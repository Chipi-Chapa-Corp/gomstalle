extends StaticBody3D

var apply_outline: Callable

func _ready():
	# apply_outline = Interactor.init_outline(get_parent())
	pass

func interact(_enable: bool, _meta: Dictionary):
	if not get_is_static():
		apply_outline.call(false)

func notice(enable: bool):
	apply_outline.call(enable)

func get_is_static() -> bool:
	return false