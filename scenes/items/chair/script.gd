extends Interactable

@onready var mesh: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var collision_layer_enabled := collision_layer
@onready var _chair = self
@onready var chair: RigidBody3D = _chair

@export var min_stun_speed: float = 10
@export var ally_stun_time: float = 0.2
@export var enemy_stun_time: float = 1.0

const THROW_SPEED := 18.0
@export var can_stun := false

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return false

func get_hunter_can_interact() -> bool:
	return false

func get_can_stun(target: CharacterBody3D) -> bool:
	var crash_speed := chair.linear_velocity - target.velocity
	return can_stun and crash_speed.length() >= min_stun_speed

func on_stun() -> void:
	queue_free()

func _physics_process(_delta: float) -> void:
	collision_shape.global_transform = chair.global_transform
	collision_shape.global_position = chair.global_position
	if chair.linear_velocity.length() < min_stun_speed and can_stun:
		can_stun = false

# Enable = pick up, Disable = throw
func perform_interact(enable: bool, metadata: Dictionary):
	var hand: Node3D = metadata.get("hand")
	var target: CharacterBody3D = metadata.get("target")
	if hand == null:
		return

	if enable:
		if target != null:
			remove_child(collision_shape)
			target.add_child(collision_shape)
		get_parent().remove_child(self)
		hand.add_child(self)
		transform = Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(-90.0), deg_to_rad(-90.0))), Vector3(0.35, 0, -0.7))
		chair.collision_layer = 1 << 0
	else:
		if target != null:
			target.remove_child(collision_shape)
			add_child(collision_shape)
		var world := get_tree().current_scene
		var t := global_transform
		get_parent().remove_child(self)
		world.add_child(self)
		global_transform = t

		chair.collision_layer = collision_layer_enabled
		var throw_direction: Vector3 = metadata.get("direction", Vector3.ZERO)
		if throw_direction != Vector3.ZERO:
			throw_direction = throw_direction.normalized()
		chair.linear_velocity = throw_direction * THROW_SPEED
		chair.angular_velocity = Vector3(randf() * 4, randf() * 4, randf() * 4)
		await get_tree().create_timer(0.1).timeout
		can_stun = true
