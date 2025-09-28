extends Interactable

const ANIMATION_DURATION = 0.45
@onready var ORIENTATION = "horizontal" if get_parent().rotation.y == 0 else "vertical"

var is_opened = false

@onready var door := $"../wall_doorway/wall_doorway_door"

func get_outline_target() -> MeshInstance3D:
	return door

func get_is_static() -> bool:
	return true

func perform_interact(enable: bool, metadata: Dictionary) -> void:
	var player_position: Vector3 = metadata.get("position", Vector3.ZERO)
	var door_position: Vector3 = door.global_transform.origin
	var axis_value: float = (player_position.z - door_position.z) if ORIENTATION == "horizontal" else (player_position.x - door_position.x)
	var target: float = 0.0 if is_opened else signf(axis_value) * 90.0 if enable else 0.0
	get_tree().create_tween().tween_property(door, "rotation_degrees:y", target, ANIMATION_DURATION)
	is_opened = not is_opened
