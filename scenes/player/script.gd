extends CharacterBody3D

var peer_id: int

@export var move_speed = 3.0
@export var acceleration = 3.0
@export var rotation_speed = 12.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var camera = $Camera3D
@onready var anim_tree = $AnimationTree
@onready var model = $Rig
@onready var label = $Label

@export var outline_material: ShaderMaterial # assign outline.tres in Inspector
var outline_root: Node3D

var camera_offset: Vector3

func _on_before_spawn(data: Dictionary) -> void:
	peer_id = data["peer_id"]
	set_multiplayer_authority(peer_id)
	global_position = data["position"]

func _ready() -> void:
	if is_multiplayer_authority():
		camera.make_current()
	else:
		camera.current = false
		set_physics_process(false)
		set_process_input(false)
	camera_offset = camera.global_transform.origin - global_transform.origin
	label.text = "Player %d" % peer_id

func _physics_process(delta: float) -> void:
	velocity.y += -gravity * delta
	get_move_input(delta)
	move_and_slide()

	if Input.is_action_just_pressed("emote"):
		anim_tree.set("parameters/IW/Cheer_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# --- rotate the visual model ---
	if Input.is_action_pressed("aim"): # bind RMB to "aim" in Input Map
		var hit := _mouse_ground_hit()
		if hit != Vector3.INF:
			var to := hit - model.global_transform.origin as Vector3
			to.y = 0.0
			if to.length() > 0.001:
				var target_yaw := atan2(-to.x, -to.z) + PI
				model.rotation.y = lerp_angle(model.rotation.y, target_yaw, rotation_speed * delta)
	else:
		# original "face movement direction"
		if velocity.length() > 0.1:
			var h := velocity; h.y = 0.0
			var target_yaw := atan2(-h.x, -h.z) + PI
			model.rotation.y = lerp_angle(model.rotation.y, target_yaw, rotation_speed * delta)

	camera.global_transform.origin = global_transform.origin + camera_offset

	label.look_at(camera.global_transform.origin, Vector3.DOWN)
	var label_dist = camera.global_transform.origin.distance_to(label.global_transform.origin)
	label.scale = label_dist * 0.01 * Vector3.ONE

func get_move_input(delta: float) -> void:
	var vy = velocity.y
	velocity.y = 0

	var input_vec = Input.get_vector("move_right", "move_left", "move_backward", "move_forward")
	var dir = Vector3(input_vec.x, 0, input_vec.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = lerp(velocity, dir * move_speed, acceleration * delta)
	
	var local_velocity = model.global_transform.basis.inverse() * velocity
	var blend_position = Vector2(local_velocity.x, -local_velocity.z) / move_speed
	anim_tree.set("parameters/IW/Locomotion/blend_position", blend_position)

	velocity.y = vy
	
func _mouse_ground_hit() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var ro := camera.project_ray_origin(mp) as Vector3
	var rd := camera.project_ray_normal(mp) as Vector3
	# Plane at the character's current Y (XZ ground)
	var ground := Plane(Vector3.UP, global_transform.origin.y)
	var hit := ground.intersects_ray(ro, rd) as Vector3
	return hit if hit != null else Vector3.INF
