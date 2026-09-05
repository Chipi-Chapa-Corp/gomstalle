extends Node
class_name CharacterActions

var character: CharacterBody3D

var _attack_elapsed := -1.0
var _hit_bodies: Array[Node3D] = []

const ROTATION_SPEED := 12.0
const ATTACK_STARTUP := 0.12

func _init(node: CharacterBody3D) -> void:
	character = node

func handle(delta: float) -> void:
	advance_attack(delta)
	if Input.is_action_just_pressed("attack"):
		start_attack()
	if Input.is_action_just_pressed("jump"):
		character.movement.request_jump()
	if Input.is_action_just_pressed("skill_1"):
		character.movement.start_air_slide()
	if Input.is_action_just_pressed("emote"):
		character.rpc("play_action_animation", &"Cheer")
	handle_rotation(delta)

func start_attack() -> bool:
	if not character.is_hunter or character.is_dead or character.is_stunned or character.attack_cooldown_timer.time_left > 0.0:
		return false
	_hit_bodies.clear()
	_attack_elapsed = 0.0
	character.attack_cooldown_timer.start()
	character.rpc("play_action_animation", &"Attack")
	return true

func advance_attack(delta: float) -> void:
	if _attack_elapsed < 0.0:
		return
	_attack_elapsed += delta
	var active: bool = _attack_elapsed >= ATTACK_STARTUP and _attack_elapsed < ATTACK_STARTUP + character.attack_time
	character.attack_hitbox.monitoring = active
	if active:
		for body in character.attack_hitbox.get_overlapping_bodies():
			handle_attacked_body(body)
	if _attack_elapsed >= ATTACK_STARTUP + character.attack_time:
		_attack_elapsed = -1.0

func cancel_attack() -> void:
	_attack_elapsed = -1.0
	character.attack_hitbox.set_deferred("monitoring", false)

func handle_rotation(delta: float) -> void:
	if Input.is_action_pressed("aim"):
		var hit := _mouse_ground_hit()
		if hit != Vector3.INF:
			var target_direction: Vector3 = hit - character.model.global_position
			target_direction.y = 0.0
			if target_direction.length() > 0.001:
				var target_yaw := atan2(-target_direction.x, -target_direction.z) + PI
				character.model.rotation.y = lerp_angle(character.model.rotation.y, target_yaw, ROTATION_SPEED * delta)
	else:
		var horizontal_velocity_vector := Vector3(character.velocity.x, 0.0, character.velocity.z)
		if horizontal_velocity_vector.length() > 0.1:
			var target_yaw := atan2(-horizontal_velocity_vector.x, -horizontal_velocity_vector.z) + PI
			character.model.rotation.y = lerp_angle(character.model.rotation.y, target_yaw, ROTATION_SPEED * delta)

func _mouse_ground_hit() -> Vector3:
	var mouse_position := character.get_viewport().get_mouse_position()
	var ray_origin: Vector3 = character.camera.project_ray_origin(mouse_position)
	var ray_destination: Vector3 = character.camera.project_ray_normal(mouse_position)
	var ground := Plane(Vector3.UP, character.global_transform.origin.y)
	var hit = ground.intersects_ray(ray_origin, ray_destination)
	return hit if hit != null else Vector3.INF

func handle_attacked_body(body: Node3D) -> void:
	if not character.is_multiplayer_authority() or character.is_dead or character.is_stunned or not character.is_hunter:
		return
	if _attack_elapsed < ATTACK_STARTUP or _attack_elapsed >= ATTACK_STARTUP + character.attack_time or _hit_bodies.has(body):
		return
	if body == character or not character.can_reach_attack(body):
		return
	_hit_bodies.append(body)
	if body is CharacterBody3D and not body.is_hunter:
		character.request_kill(body.peer_id)
	elif body.is_in_group("attackable"):
		body.on_attacked()
