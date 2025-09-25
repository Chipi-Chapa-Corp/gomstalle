extends StaticBody3D

const is_static = true
var apply_outline: Callable

@export var is_opened = false

@onready var orientation = "horizontal" if get_parent().rotation.y == 0 else "vertical"

@onready var door := $"../wall_doorway/wall_doorway_door"

func _ready():
	apply_outline = Interactor.init_outline(door)

func interact(enable: bool, metadata: Dictionary):
	if not is_static:
		apply_outline.call(false)
	var player_position: Vector3 = metadata.get("position", Vector3.ZERO)
	var door_position: Vector3 = door.global_transform.origin
	var axis_value: float = (player_position.z - door_position.z) if orientation == "horizontal" else (player_position.x - door_position.x)
	var target := 0.0 if is_opened else signf(axis_value) * 90.0 if enable else 0.0
	get_tree().create_tween().tween_property(door, "rotation_degrees:y", target, 0.4)
	is_opened = not is_opened

func notice(enable: bool):
	apply_outline.call(enable)
