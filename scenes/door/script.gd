extends Interactable

const ANIMATION_DURATION = 0.45
@onready var ORIENTATION = "horizontal" if get_parent().rotation.y == 0 else "vertical"

var is_opened = false

@export var mesh: MeshInstance3D
@export var body: AnimatableBody3D

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return true

func get_hunter_can_interact() -> bool:
	return true

func perform_interact(enable: bool, metadata: Dictionary) -> void:
	var player_position: Vector3 = metadata.get("position", Vector3.ZERO)
	var door_position: Vector3 = body.global_transform.origin
	var axis_value: float = (player_position.z - door_position.z) if ORIENTATION == "horizontal" else (player_position.x - door_position.x)
	var target: float = 0.0 if is_opened else signf(axis_value) * 90.0 if enable else 0.0
	
	var tween := get_tree().create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(body, "rotation_degrees:y", target, ANIMATION_DURATION)
	is_opened = not is_opened
