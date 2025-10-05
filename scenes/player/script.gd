extends CharacterBody3D

@export var hider_parts: Node3D
@export var hunter_parts: Node3D
@export var hand: RemoteTransform3D
@export var camera: Camera3D
@export var anim_tree: AnimationTree
@export var model: Node3D
@export var label: Label3D
@export var stamina_bar: TextureProgressBar
@export var cooldown_timer: Timer
@export var attack_cooldown_timer: Timer
@export var attack_hitbox: Area3D
@export var stun_effect: Sprite3D

@onready var playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

@onready var space := get_world_3d().direct_space_state
@onready var player_name = "Unknown Player"

@export var hunter_color: Color = Color(1, 0, 0, 1)
@export var hider_color: Color = Color(0, 0, 1, 1)
@export var interact_on_layer: int = 5
@export var interact_radius: float = 1.6
@export var max_interact_results: int = 8
@export var jump_height: int = 5

var peer_id: int
var is_hunter := false

const base_move_speed = 6.0
const run_move_speed = 8.0
const max_stamina = 50
const stamina_usage = 10
const stamina_regen = 5

var current_move_speed = base_move_speed
var stamina = max_stamina
var is_stunned := false
var is_dead := false
const rotation_speed = 8.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var camera_offset: Vector3
var camera_yaw_offset: float = 0.0

var INTERACT_MASK := 1 << (interact_on_layer - 1)

var interact_shape := SphereShape3D.new()
var interact_query_params := PhysicsShapeQueryParameters3D.new()

var item: PhysicsBody3D
var closest_item: PhysicsBody3D
var animation_velocity: Vector3 = Vector3.ZERO
var movement_state_blend: float = 0.0

func _on_before_spawn(data: Dictionary) -> void:
	peer_id = data["peer_id"]
	set_multiplayer_authority(peer_id)
	position = data["position"]

func _ready() -> void:
	hand.transform = Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(-90.0), deg_to_rad(-90.0))), Vector3(0.35, 0, -0.7))
	var rotation_angle = deg_to_rad(45.0)
	camera_yaw_offset = rotation_angle
	if is_multiplayer_authority():
		camera.make_current()
		player_name = Steam.getPersonaName()
		label.visible = false
	else:
		label.text = player_name
		camera.current = false
		set_physics_process(false)
		set_process_input(false)

	attack_hitbox.monitoring = false
	attack_cooldown_timer.connect("timeout", func(): attack_hitbox.monitoring = false)

	GameState.started.connect(_on_game_started)
	camera_offset = camera.global_transform.origin - global_transform.origin
	camera_offset = camera_offset.rotated(Vector3.UP, camera_yaw_offset)
	camera.rotation.y = camera_yaw_offset
	interact_shape.radius = interact_radius
	interact_query_params.shape = interact_shape
	interact_query_params.collision_mask = INTERACT_MASK
	interact_query_params.collide_with_bodies = true
	interact_query_params.collide_with_areas = false
	interact_query_params.exclude = [self]

func _physics_process(delta: float) -> void:
	velocity.y += -gravity * delta

	if not is_instance_valid(item):
		item = null

	handle_movement(delta)
	handle_interactables()
	handle_actions(delta)
	move_and_slide()

	camera.global_transform.origin = global_transform.origin + camera_offset

func handle_interactables() -> void:
	if is_dead:
		return
	if Input.is_action_just_pressed("interact") and cooldown_timer.time_left <= 0.0:
		var forward_direction: Vector3 = model.global_transform.basis.z.normalized()
		var metadata = {
			"position": global_transform.origin,
			"hand": hand.get_path(),
			"target": self.get_path(),
			"direction": forward_direction,
		}

		if item != null:
			item.interact(false, metadata)
			item = null
			anim_tree.set("parameters/IW/Hold_B/blend_amount", 0.0)
		elif closest_item != null:
			cooldown_timer.start()
			anim_tree.set("parameters/IW/Interact_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			closest_item.interact(true, metadata)
			if not closest_item.get_is_static():
				item = closest_item
				anim_tree.set("parameters/IW/Hold_B/blend_amount", 1.0)

	if item != null:
		return

	var next_closest_item: PhysicsBody3D = null
	interact_query_params.transform = Transform3D(Basis(), global_transform.origin)
	var hits := space.intersect_shape(interact_query_params, max_interact_results)
	var best_distance := INF
	var seen_bodies := {}
	for hit in hits:
		var collider: PhysicsBody3D = hit.get("collider")
		var is_collider_valid = collider != null and not seen_bodies.has(collider)
		var is_collider_interactible = collider.is_in_group("interactible")
		var is_collider_accessible = not is_hunter or (is_collider_interactible and collider.get_hunter_can_interact())
		if not is_collider_valid or not is_collider_interactible or not is_collider_accessible:
			continue
		seen_bodies[collider] = true
		var point: Vector3 = hit.get("point", Vector3.ZERO)
		if point == Vector3.ZERO:
			point = collider.global_transform.origin
		var distance := global_transform.origin.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			next_closest_item = collider

	if next_closest_item != closest_item:
		if closest_item:
			closest_item.notice(false)
		closest_item = next_closest_item
		if closest_item:
			closest_item.notice(true)

func stun(timeout: float) -> void:
	if is_dead or is_stunned:
		return
	rpc("sync_stun", timeout)

@rpc("any_peer", "call_local", "reliable")
func sync_stun(timeout: float) -> void:
	if is_dead or is_stunned:
		return
	stun_effect.play()
	is_stunned = true
	anim_tree.set("parameters/IW/Walk/blend_position", Vector2.ZERO)
	anim_tree.set("parameters/IW/Run/blend_position", Vector2.ZERO)
	anim_tree.set("parameters/IW/MovementState/blend_amount", 0.0)
	anim_tree.set("parameters/IW/Stun_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await get_tree().create_timer(timeout).timeout
	is_stunned = false

func handle_movement(delta: float) -> void:
	for i in range(get_slide_collision_count()):
		var collider = get_slide_collision(i).get_collider()
		if collider != null and collider.is_in_group("stunning") and collider.get_can_stun(self):
			stun(collider.ally_stun_time if peer_id == GameState.hunter_peer_id else collider.enemy_stun_time)
			collider.on_stun()

	if is_stunned or is_dead:
		velocity = Vector3.ZERO
		return
	
	var vertical_velocity = velocity.y
	velocity.y = 0.0

	var run_requested = Input.is_action_pressed("run")
	var movement_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var movement_direction = Vector3.ZERO
	if movement_input != Vector2.ZERO:
		var input_vector = Vector3(movement_input.x, 0.0, movement_input.y)
		movement_direction = input_vector.rotated(Vector3.UP, camera_yaw_offset)
	if movement_direction.length() > 1.0:
		movement_direction = movement_direction.normalized()
	var is_moving = movement_direction.length() > 0.0
	var has_stamina = stamina > 0.0
	var is_running = run_requested and has_stamina and is_moving
	current_move_speed = run_move_speed if is_running else base_move_speed

	var horizontal_velocity = movement_direction * current_move_speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	animation_velocity = animation_velocity.lerp(horizontal_velocity, 0.15)

	var local_velocity = model.global_transform.basis.inverse() * animation_velocity
	var local_plane_velocity = Vector2(local_velocity.x, -local_velocity.z)

	var walk_blend_position = local_plane_velocity / base_move_speed if base_move_speed != 0.0 else Vector2.ZERO
	walk_blend_position = walk_blend_position.limit_length(1.0)
	anim_tree.set("parameters/IW/Walk/blend_position", walk_blend_position)

	var run_blend_position = local_plane_velocity / run_move_speed if run_move_speed != 0.0 else Vector2.ZERO
	run_blend_position = run_blend_position.limit_length(1.0)
	anim_tree.set("parameters/IW/Run/blend_position", run_blend_position)

	var target_movement_state = 1.0 if is_running else 0.0
	movement_state_blend = lerp(movement_state_blend, target_movement_state, 0.15)
	anim_tree.set("parameters/IW/MovementState/blend_amount", movement_state_blend)

	if is_running:
		stamina = max(stamina - stamina_usage * delta, 0.0)
	elif not run_requested:
		stamina = min(stamina + stamina_regen * delta, max_stamina)
	if is_multiplayer_authority():
		stamina_bar.visible = stamina < max_stamina
		stamina_bar.value = stamina / max_stamina * 100.0

	velocity.y = vertical_velocity

func jump() -> void:
	if not is_on_floor():
		return
	velocity.y += jump_height
	anim_tree.set("parameters/IW/Jump_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func attack() -> void:
	attack_hitbox.monitoring = true
	anim_tree.set("parameters/IW/Attack_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func handle_actions(delta: float) -> void:
	if is_dead:
		return

	if Input.is_action_just_pressed("jump"):
		if is_hunter:
			if attack_cooldown_timer.time_left <= 0.0:
				attack()
				attack_cooldown_timer.start()
		else:
			jump()

	if Input.is_action_just_pressed("emote"):
		anim_tree.set("parameters/IW/Cheer_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	if Input.is_action_pressed("aim"):
		var hit := _mouse_ground_hit()
		if hit != Vector3.INF:
			var to := hit - model.global_transform.origin as Vector3
			to.y = 0.0
			if to.length() > 0.001:
				var target_yaw := atan2(-to.x, -to.z) + PI
				model.rotation.y = lerp_angle(model.rotation.y, target_yaw, rotation_speed * delta)
	else:
		var horizontal_velocity_vector := Vector3(velocity.x, 0.0, velocity.z)
		if horizontal_velocity_vector.length() > 0.1:
			var target_yaw := atan2(-horizontal_velocity_vector.x, -horizontal_velocity_vector.z) + PI
			model.rotation.y = lerp_angle(model.rotation.y, target_yaw, rotation_speed * delta)

func _mouse_ground_hit() -> Vector3:
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_destination: Vector3 = camera.project_ray_normal(mouse_position)
	var ground := Plane(Vector3.UP, global_transform.origin.y)
	var hit: Vector3 = ground.intersects_ray(ray_origin, ray_destination)
	return hit if hit != null else Vector3.INF

func _exit_tree() -> void:
	if GameState.started.is_connected(_on_game_started):
		GameState.started.disconnect(_on_game_started)

func _set_player_skin() -> void:
	var new_parts = hunter_parts if is_hunter else hider_parts
	var old_parts = hunter_parts if not is_hunter else hider_parts
	old_parts.visible = false
	new_parts.visible = true
	label.modulate = hunter_color if is_hunter else hider_color

func set_dead(state: bool) -> void:
	is_dead = state
	if is_dead:
		playback.travel("Death_A", true)
	else:
		playback.travel("Ressurrect_A", true)
		await get_tree().create_timer(0.6).timeout

func _on_game_started(hunter_peer_id: int) -> void:
	is_hunter = peer_id == hunter_peer_id
	_set_player_skin()

	if is_multiplayer_authority():
		var target_position = GameState.start_positions.get(peer_id, global_position)
		global_position = target_position

func _on_attacked(body: Node3D) -> void:
	if is_dead or is_hunter:
		return
	if body is CharacterBody3D:
		body.set_dead(true)
