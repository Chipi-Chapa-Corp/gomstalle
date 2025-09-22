extends StaticBody3D

const is_static = false
var apply_outline: Callable

func _ready():
	apply_outline = Interactor.init_outline(get_parent())

func interact(enable: bool, _meta: Dictionary):
	print("interact:", enable)
	if not is_static:
		apply_outline.call(false)

func notice(enable: bool):
	print("notice: ", enable)
	apply_outline.call(enable)
