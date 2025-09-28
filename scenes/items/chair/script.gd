extends Interactable

@onready var mesh: MeshInstance3D = $Mesh
@onready var collision_layer_enabled := collision_layer

const THROW_SPEED := 12.0

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return false

# Enable = pick up, Disable = throw
func perform_interact(enable: bool, metadata: Dictionary):
	var hand: Node3D = metadata.get("hand")
	if hand == null:
		return

	var _chair = self
	var chair: RigidBody3D = _chair
	
	if enable:
		get_parent().remove_child(self)
		hand.add_child(self)
		transform = Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(-90.0), deg_to_rad(-90.0))), Vector3(0.35, 0, -0.7))
		if chair is RigidBody3D:
			chair.freeze = true
			chair.collision_layer = 0
	else:
		var world := get_tree().current_scene
		var t := global_transform
		get_parent().remove_child(self)
		world.add_child(self)
		global_transform = t

		chair.freeze = false
		chair.collision_layer = collision_layer_enabled
		var throw_direction: Vector3 = metadata.get("direction", Vector3.ZERO)
		if throw_direction != Vector3.ZERO:
			throw_direction = throw_direction.normalized()
		chair.linear_velocity = throw_direction * THROW_SPEED
		chair.angular_velocity = Vector3(randf() * 4, randf() * 4, randf() * 4)
