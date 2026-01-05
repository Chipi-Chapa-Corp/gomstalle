extends CharacterBody3D

@onready var forces := CharacterForces.new(self)
@onready var movement := CharacterMovement.new(self)
@onready var interactions := CharacterInteractions.new(self)
@onready var actions := CharacterActions.new(self)
@onready var looks := CharacterLooks.new(self)

@onready var inventory := CharacterInventory.new(self)

@export var inventory_wood_label: Label
@export var wall_through_material_override: Material
@export var hider_parts: Node3D
@export var hunter_parts: Node3D
@export var hand: RemoteTransform3D
@onready var camera: Camera3D = $Camera3D
@export var anim_tree: AnimationTree
@export var model: Node3D
@export var label: Label3D
@export var stamina_bar: TextureProgressBar
@export var cooldown_timer: Timer
@export var attack_cooldown_timer: Timer
@export var ability_cooldown_timer: Timer
@export var jump_landing_timer: Timer
@export var attack_hitbox: Area3D
@export var stun_effect: Sprite3D
@export var regular_collider: CollisionShape3D
@export var dash_collider: CollisionShape3D
@export var movement_audio_player: AudioStreamPlayer3D
@export var attack_audio_player: AudioStreamPlayer3D
@export var surface_ray: RayCast3D
@export var camera_damping_time_constant: float = 0.15
@export var portal_indicator_distance: float = 0.9
@export var portal_indicator_height_offset: float = 0.03
@export var portal_indicator_turn_speed: float = 10.0

@onready var portal_indicator: Node3D = $PortalIndicator

@onready var playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

@onready var space := get_world_3d().direct_space_state
@onready var player_name

@export var hunter_color: Color = Color(1, 0, 0, 1)
@export var hider_color: Color = Color(0, 0, 1, 1)
@export var dead_color: Color = Color(0, 0, 0, 1)
@export var interact_on_layer: int = 5
@export var interact_radius: float = 1.6
@export var max_interact_results: int = 8

var attack_time: float = 0.4
var jump_height: float = 6.0
var dash_speed: float = 8.0
var dash_duration: float = 2
var dash_height: float = 6.0

var peer_id: int
var is_hunter := false

const base_move_speed = 6.0
const run_move_speed = 8.0
const max_stamina = 50
const stamina_usage = 10
const stamina_regen = 5

var dash := 0.0
var current_move_speed = base_move_speed
var stamina = max_stamina
var is_stunned := false
var is_dead := false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var camera_offset: Vector3
var base_camera_offset: Vector3
var base_camera_basis: Basis
var base_camera_fov: float = 0.0
var camera_yaw_offset: float = 0.0
var camera_velocity: Vector3 = Vector3.ZERO
var camera_override_active: bool = false
var camera_override_target: Vector3 = Vector3.ZERO
var camera_override_direction: Vector3 = Vector3.ZERO
var camera_override_fov: float = 0.0
var camera_override_damping_time_constant: float = 0.0
var camera_temporary_damping_time_constant: float = 0.0
var camera_temporary_damping_duration_remaining: float = 0.0
var portal_indicator_yaw: float = 0.0

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
	add_child(inventory)
	hand.transform = Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(-90.0), deg_to_rad(-90.0))), Vector3(0.35, 0, -0.7))
	var rotation_angle = deg_to_rad(45.0)
	camera_yaw_offset = rotation_angle
	if is_multiplayer_authority():
		camera.set_as_top_level(true)
		camera.make_current()
		label.text = Steam.getPersonaName()
		label.visible = false
	else:
		camera.current = false
		set_physics_process(false)
		set_process_input(false)
	portal_indicator.top_level = true
	portal_indicator.visible = false

	print("player ready, process %s" % is_physics_processing())

	attack_hitbox.monitoring = false

	GameState.state_changed.connect(_on_game_state_changed)

	camera_offset = camera.global_transform.origin - global_transform.origin
	camera_offset = camera_offset.rotated(Vector3.UP, camera_yaw_offset)
	camera.rotation.y = camera_yaw_offset
	base_camera_offset = camera_offset
	base_camera_basis = camera.global_transform.basis
	base_camera_fov = camera.fov
	camera_override_fov = base_camera_fov
	interact_shape.radius = interact_radius
	interact_query_params.shape = interact_shape
	interact_query_params.collision_mask = INTERACT_MASK
	interact_query_params.collide_with_bodies = true
	interact_query_params.collide_with_areas = false
	interact_query_params.exclude = [self]

	looks.enable_wall_highlights(hunter_parts)
	looks.enable_wall_highlights(hider_parts)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(item):
		item = null

	forces.handle(delta)
	if not is_stunned and not is_dead and not GameState.is_paused:
		movement.handle(delta)
		interactions.handle(delta)
		actions.handle(delta)

	move_and_slide()
	_advance_temporary_camera_damping_time_constant(delta)
	var target_camera_position = _get_camera_target_position()
	var damping_time_constant = _get_active_camera_damping_time_constant()
	var camera_step = SmoothDamp.smooth_damp_vector3_step(camera.global_transform.origin, target_camera_position, camera_velocity, damping_time_constant, delta)
	camera.global_transform.origin = camera_step.value
	camera_velocity = camera_step.velocity
	_update_camera_orientation(camera_step.blend_factor)
	_update_camera_fov(camera_step.blend_factor)
	_update_portal_indicator(delta)

func set_dead(state: bool) -> void:
	forces.set_dead(state)

func _on_game_state_changed(state: GameState.State) -> void:
	if state == GameState.State.STARTED:
		_on_game_started(GameState.hunter_peer_id)

func _on_game_started(hunter_peer_id: int) -> void:
	is_hunter = peer_id == hunter_peer_id
	looks.sync_skin()

	if is_multiplayer_authority():
		var target_position = GameState.start_positions.get(peer_id, global_position)
		global_position = target_position

func _on_attacked(body: Node3D) -> void:
	actions.handle_attacked_body(body)

func _exit_tree() -> void:
	GameState.state_changed.disconnect(_on_game_state_changed)

func set_camera_override(target: Vector3, direction: Vector3, fov: float, damping_time_constant: float) -> void:
	camera_override_active = true
	camera_override_target = target
	var flattened_direction = Vector3(direction.x, 0.0, direction.z)
	if flattened_direction.length() == 0.0:
		camera_override_direction = Vector3.ZERO
	else:
		camera_override_direction = flattened_direction.normalized()
	camera_override_fov = maxf(fov, 1.0)
	camera_override_damping_time_constant = maxf(damping_time_constant, 0.0)
	camera_velocity = Vector3.ZERO

func clear_camera_override() -> void:
	camera_override_active = false
	camera_override_target = Vector3.ZERO
	camera_override_direction = Vector3.ZERO
	camera_override_fov = base_camera_fov
	camera_override_damping_time_constant = 0.0
	camera_velocity = Vector3.ZERO

func set_temporary_camera_damping_time_constant(damping_time_constant: float, duration: float) -> void:
	camera_temporary_damping_time_constant = maxf(damping_time_constant, 0.0)
	camera_temporary_damping_duration_remaining = maxf(duration, 0.0)

func _update_portal_indicator(delta: float) -> void:
	if not _should_show_portal_indicator():
		portal_indicator.visible = false
		return
	var portal_direction = GameState.portal_position - global_position
	portal_direction.y = 0.0
	if portal_direction.length_squared() == 0.0:
		portal_direction = Vector3.FORWARD
	var normalized_direction = portal_direction.normalized()
	var target_yaw = atan2(normalized_direction.x, normalized_direction.z)
	var rotation_blend = clampf(delta * portal_indicator_turn_speed, 0.0, 1.0)
	portal_indicator_yaw = lerp_angle(portal_indicator_yaw, target_yaw, rotation_blend)
	portal_indicator.rotation = Vector3(0.0, portal_indicator_yaw, 0.0)
	var base_position = _get_portal_indicator_base_position()
	portal_indicator.global_position = base_position + normalized_direction * portal_indicator_distance + Vector3(0.0, portal_indicator_height_offset, 0.0)
	portal_indicator.visible = true

func _should_show_portal_indicator() -> bool:
	if not GameState.portal_active:
		return false
	if camera_override_active:
		return false
	return true

func _get_portal_indicator_base_position() -> Vector3:
	var base_position = global_position
	surface_ray.force_raycast_update()
	if surface_ray.is_colliding():
		base_position = surface_ray.get_collision_point()
	return base_position

func _get_camera_target_position() -> Vector3:
	var focus_position = global_transform.origin
	var offset = camera_offset
	if camera_override_active:
		focus_position = camera_override_target
		offset = _get_camera_override_offset()
	return focus_position + offset

func _get_camera_override_offset() -> Vector3:
	var base_horizontal = Vector2(base_camera_offset.x, base_camera_offset.z)
	if base_horizontal.length() == 0.0:
		return base_camera_offset
	var horizontal_distance = base_horizontal.length()
	var direction = Vector2(camera_override_direction.x, camera_override_direction.z)
	if direction.length() == 0.0:
		direction = base_horizontal.normalized()
	else:
		direction = direction.normalized()
	return Vector3(direction.x * horizontal_distance, base_camera_offset.y, direction.y * horizontal_distance)

func _get_active_camera_damping_time_constant() -> float:
	if camera_override_active and camera_override_damping_time_constant > 0.0:
		return camera_override_damping_time_constant
	if camera_temporary_damping_duration_remaining > 0.0 and camera_temporary_damping_time_constant > 0.0:
		return camera_temporary_damping_time_constant
	return camera_damping_time_constant

func _advance_temporary_camera_damping_time_constant(delta: float) -> void:
	if camera_temporary_damping_duration_remaining <= 0.0:
		return
	camera_temporary_damping_duration_remaining = maxf(camera_temporary_damping_duration_remaining - delta, 0.0)

func _update_camera_orientation(smoothing_factor: float) -> void:
	var target_basis = base_camera_basis
	if camera_override_active:
		target_basis = camera.global_transform.looking_at(camera_override_target, Vector3.UP).basis
	camera.global_transform.basis = camera.global_transform.basis.slerp(target_basis, smoothing_factor)

func _update_camera_fov(smoothing_factor: float) -> void:
	var target_fov = base_camera_fov
	if camera_override_active:
		target_fov = camera_override_fov
	camera.fov = lerpf(camera.fov, target_fov, smoothing_factor)
