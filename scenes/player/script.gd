extends CharacterBody3D

@onready var space := get_world_3d().direct_space_state
@onready var camera = $Camera3D
@onready var anim_tree = $AnimationTree
@onready var model = $Rig
@onready var label = $Label
@onready var stamina_bar: TextureProgressBar = $"2D/HUD/Stamina"
@onready var cooldown_timer: Timer = $Cooldown
@onready var player_name = Steam.getPersonaName()

@export var hunter_color: Color = Color(1, 0, 0, 1)
@export var hider_color: Color = Color(0, 0, 1, 1)
@export var interact_on_layer: int = 5
@export var interact_radius: float = 1.6
@export var max_interact_results: int = 8

var peer_id: int

const base_move_speed = 6.0
const run_move_speed = 8.0
const max_stamina = 50
const stamina_usage = 10
const stamina_regen = 5

var current_move_speed = base_move_speed
var stamina = max_stamina
const rotation_speed = 8.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var camera_offset: Vector3

var INTERACT_MASK := 1 << (interact_on_layer - 1)

var interact_shape := SphereShape3D.new()
var interact_query_params := PhysicsShapeQueryParameters3D.new()

var item: StaticBody3D
var closest_item: StaticBody3D
var animation_velocity: Vector3 = Vector3.ZERO
var movement_state_blend: float = 0.0

func _on_before_spawn(data: Dictionary) -> void:
	peer_id = data["peer_id"]
	set_multiplayer_authority(peer_id)
	global_position = data["position"]

func _ready() -> void:
	if is_multiplayer_authority():
		camera.make_current()
		label.visible = false
	else:
		label.text = player_name
		camera.current = false
		set_physics_process(false)
		set_process_input(false)

	GameState.started.connect(_on_game_started)
	camera_offset = camera.global_transform.origin - global_transform.origin
	interact_shape.radius = interact_radius
	interact_query_params.shape = interact_shape
	interact_query_params.collision_mask = INTERACT_MASK
	interact_query_params.collide_with_bodies = true
	interact_query_params.collide_with_areas = false
	interact_query_params.exclude = [self]

func _physics_process(delta: float) -> void:
	velocity.y += -gravity * delta
	handle_movement(delta)
	handle_interactables()
	move_and_slide()

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
		if velocity.length() > 0.1:
			var h := velocity; h.y = 0.0
			var target_yaw := atan2(-h.x, -h.z) + PI
			model.rotation.y = lerp_angle(model.rotation.y, target_yaw, rotation_speed * delta)

	camera.global_transform.origin = global_transform.origin + camera_offset

func handle_interactables() -> void:
	var next_closest_item: StaticBody3D = null
	interact_query_params.transform = Transform3D(Basis(), global_transform.origin)
	var hits := space.intersect_shape(interact_query_params, max_interact_results)
	var best_distance := INF
	var seen_bodies := {}
	for hit in hits:
		var collider: StaticBody3D = hit.get("collider")
		if collider == null or seen_bodies.has(collider):
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

	if Input.is_action_just_pressed("interact"):
		if cooldown_timer.time_left > 0.0 or closest_item == null or closest_item == item:
			return
		var metadata = {"position": global_transform.origin}
		if item != null:
			item.interact(false, metadata)
			print("Interacting", item)
		item = closest_item
		cooldown_timer.start()
		anim_tree.set("parameters/IW/Interact_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		item.interact(true, metadata)
		if item.get_is_static():
			item = null

func handle_movement(delta: float) -> void:
	var vertical_velocity = velocity.y
	velocity.y = 0.0

	var run_requested = Input.is_action_pressed("run")
	var movement_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var movement_direction = Vector3(movement_input.x, 0.0, movement_input.y)
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

func _on_game_started(hunter_peer_id: int) -> void:
	if peer_id == hunter_peer_id:
		label.modulate = hunter_color
	else:
		label.modulate = hider_color
	if is_multiplayer_authority():
		var target_position = GameState.start_positions.get(peer_id, global_position)
		global_position = target_position
