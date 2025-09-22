extends StaticBody3D

@onready var orientation = "horizontal" if get_parent().rotation.y == 0 else "vertical"

@onready var door := $"../wall_doorway/wall_doorway_door"

func interact(enable: bool, metadata: Dictionary):
	var player_position: Vector3 = metadata.get("position", Vector3.ZERO)
	var door_position: Vector3 = door.global_transform.origin
	var axis_value: float = (player_position.z - door_position.z) if orientation == "horizontal" else (player_position.x - door_position.x)
	var target := signf(axis_value) * 90.0 if enable else 0.0
	get_tree().create_tween().tween_property(door, "rotation_degrees:y", target, 0.2)
