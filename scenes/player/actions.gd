extends Node
class_name CharacterActions

var character: CharacterBody3D

var is_jumping := false

const ROTATION_SPEED = 8.0

func _init(node: CharacterBody3D) -> void:
	character = node

func handle(delta: float) -> void:
	handle_active_action()
	handle_emote()
	handle_rotation(delta)
	handle_skill_1()

func handle_skill_1() -> void:
	if character.is_hunter:
		return
	if Input.is_action_just_pressed("skill_1"):
		character.dash = character.dash_speed
		character.anim_tree.set("parameters/IW/Roll_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		await character.get_tree().create_timer(1.5).timeout

func handle_active_action() -> void:
	if Input.is_action_just_pressed("jump"):
		if character.is_hunter:
			handle_attack()
		else:
			handle_jump()

func handle_jump() -> void:
	if is_jumping:
		return
	is_jumping = true
	character.anim_tree.set("parameters/IW/Jump_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await character.get_tree().create_timer(1.3).timeout
	is_jumping = false

func handle_attack() -> void:
	if character.attack_cooldown_timer.time_left <= 0.0:
		character.attack_cooldown_timer.start()
		character.attack_hitbox.monitoring = true
		character.anim_tree.set("parameters/IW/Attack_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		await character.get_tree().create_timer(character.attack_time).timeout
		character.attack_hitbox.monitoring = false

func handle_emote() -> void:
	if Input.is_action_just_pressed("emote"):
		character.anim_tree.set("parameters/IW/Cheer_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func handle_rotation(delta: float) -> void:
	if Input.is_action_pressed("aim"):
		var hit := _mouse_ground_hit()
		if hit != Vector3.INF:
			var to := hit - character.model.global_transform.origin as Vector3
			to.y = 0.0
			if to.length() > 0.001:
				var target_yaw := atan2(-to.x, -to.z) + PI
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
	var hit: Vector3 = ground.intersects_ray(ray_origin, ray_destination)
	return hit if hit != null else Vector3.INF

func handle_attacked_body(body: Node3D) -> void:
	if character.is_dead or character.is_hunter:
		return
	if body is CharacterBody3D:
		body.set_dead(true)
