extends StaticBody3D

const IS_STATIC = false
var apply_outline: Callable

func _ready():
	apply_outline = Interactor.init_outline(get_parent())

func interact(_enable: bool, _meta: Dictionary):
	if not IS_STATIC:
		apply_outline.call(false)

func notice(enable: bool):
	apply_outline.call(enable)
