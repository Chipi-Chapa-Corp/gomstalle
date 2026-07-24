extends Interactable

@export var mesh: MeshInstance3D
@export var transformer: RemoteTransform3D
@export var collision_shape: CollisionShape3D
@export var destroy_effect: GPUParticles3D

@onready var collision_shadow: CollisionShape3D = collision_shape.duplicate()
@onready var collision_layer_enabled := collision_layer
@onready var _chair = self
@onready var chair: RigidBody3D = _chair

@export var min_stun_impact: float = 6.0
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

func get_can_stun(target: CharacterBody3D, normal: Vector3) -> bool:
	if not can_stun:
		return false
	var relative_velocity := chair.linear_velocity - target.velocity
	var impact := relative_velocity.dot(normal.normalized())
	return impact >= min_stun_impact

func on_stun() -> void:
	rpc("sync_on_stun")

@rpc("any_peer", "call_local", "reliable")
func sync_on_stun() -> void:
	get_parent().queue_free()

func on_attacked() -> void:
	rpc("sync_on_attacked")

@rpc("any_peer", "call_local", "reliable")
func sync_on_attacked() -> void:
	destroy_effect.emitting = true
	collision_shape.disabled = true
	mesh.visible = false
	await get_tree().create_timer(destroy_effect.lifetime).timeout
	get_parent().queue_free()

func _physics_process(_delta: float) -> void:
	if chair.linear_velocity.length() < min_stun_impact and can_stun:
		can_stun = false

func _build_authoritative_payload(enable: bool, metadata: Dictionary, sender_id: int) -> Dictionary:
	var payload := super._build_authoritative_payload(enable, metadata, sender_id)
	payload["transform"] = chair.global_transform
	if not enable:
		var throw_direction: Vector3 = payload.get("direction", Vector3.ZERO)
		payload["linear_velocity"] = throw_direction.normalized() * THROW_SPEED if throw_direction != Vector3.ZERO else Vector3.ZERO
		payload["angular_velocity"] = Vector3(randf() * 4.0, randf() * 4.0, randf() * 4.0)
	return payload

func do_interact(enable: bool, payload: Dictionary) -> void:
	var caller: CharacterBody3D = payload.get("caller")
	if caller == null:
		return
	var hand := caller.hand as RemoteTransform3D
	if hand == null:
		return
	chair.global_transform = payload.get("transform", chair.global_transform)
	if enable:
		chair.freeze = true
		hand.remote_path = get_path()
		_set_collision_exclusion(caller, true)
		chair.collision_layer = 1 << 0
		return
	chair.freeze = false
	hand.remote_path = ""
	_set_collision_exclusion(caller, false)
	chair.collision_layer = collision_layer_enabled
	chair.linear_velocity = payload.get("linear_velocity", Vector3.ZERO)
	chair.angular_velocity = payload.get("angular_velocity", Vector3.ZERO)
	await get_tree().create_timer(0.1).timeout
	can_stun = true

func _set_collision_exclusion(target: CharacterBody3D, enable: bool) -> void:
	if target == null:
		return
	if enable:
		add_collision_exception_with(target)
		if collision_shadow.get_parent() != target:
			if collision_shadow.get_parent() != null:
				collision_shadow.get_parent().remove_child(collision_shadow)
			target.add_child(collision_shadow)
		transformer.remote_path = collision_shadow.get_path()
		return
	remove_collision_exception_with(target)
	if collision_shadow.get_parent() == target:
		target.remove_child(collision_shadow)
	transformer.remote_path = ""
