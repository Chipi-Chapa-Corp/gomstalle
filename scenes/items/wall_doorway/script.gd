extends StaticBody3D

@onready var parent := self.get_parent()

func interact(enable: bool):
	get_tree().create_tween().tween_property(parent, "rotation_degrees:y", 90 if enable else 0, 0.2)
