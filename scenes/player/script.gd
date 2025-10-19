extends CharacterBody3D

@onready var forces := CharacterForces.new(self)
@onready var movement := CharacterMovement.new(self)
@onready var interactions := CharacterInteractions.new(self)
@onready var actions := CharacterActions.new(self)
@onready var looks := CharacterLooks.new(self)

@export var wall_through_material_override: Material
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
@export var ability_cooldown_timer: Timer
@export var attack_hitbox: Area3D
@export var stun_effect: Sprite3D
@export var regular_collider: CollisionShape3D
@export var dash_collider: CollisionShape3D

@onready var playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

@onready var space := get_world_3d().direct_space_state
@onready var player_name

@export var hunter_color: Color = Color(1, 0, 0, 1)
@export var hider_color: Color = Color(0, 0, 1, 1)
@export var dead_color: Color = Color(0, 0, 0, 1)
@export var interact_on_layer: int = 5
@export var interact_radius: float = 1.6
@export var max_interact_results: int = 8

var attack_time: float = 0.82
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
		label.text = Steam.getPersonaName()
		label.visible = false
	else:
		camera.current = false
		set_physics_process(false)
		set_process_input(false)

	print("player ready, process %s" % is_physics_processing())

	attack_hitbox.monitoring = false

	GameState.state_changed.connect(_on_game_state_changed)

	camera_offset = camera.global_transform.origin - global_transform.origin
	camera_offset = camera_offset.rotated(Vector3.UP, camera_yaw_offset)
	camera.rotation.y = camera_yaw_offset
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
	camera.global_transform.origin = global_transform.origin + camera_offset

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
