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

@export var outline_material: ShaderMaterial
var outline_root: Node3D

var camera_offset: Vector3

var interactibles: Array[StaticBody3D] = []
var item: StaticBody3D
var closest_item: StaticBody3D

func _on_before_spawn(data: Dictionary) -> void:
	peer_id = data["peer_id"]
	set_multiplayer_authority(peer_id)
	global_position = data["position"]

func _ready() -> void:
	if is_multiplayer_authority():
		camera.make_current()
		label.visible = true
	else:
		label.text = "Player %d" % peer_id
		camera.current = false
		set_physics_process(false)
		set_process_input(false)
	camera_offset = camera.global_transform.origin - global_transform.origin

func _physics_process(delta: float) -> void:
	velocity.y += -gravity * delta
	get_move_input(delta)
	move_and_slide()

	var next_closest_item = interactibles.reduce(func(a, b):
		var dist_a = a.global_transform.origin.distance_to(global_transform.origin)
		var dist_b = b.global_transform.origin.distance_to(global_transform.origin)
		return a if dist_a < dist_b else b
	)
	if next_closest_item != null and next_closest_item != closest_item:
		if closest_item:
			closest_item.notice(false)
		closest_item = next_closest_item
		closest_item.notice(true)

	if Input.is_action_just_pressed("interact"):
		if closest_item == null or closest_item == item:
			return
		var metadata = {"position": global_transform.origin}
		if item != null:
			item.interact(false, metadata)
		item = closest_item
		item.interact(true, metadata)
		if item.is_static:
			item = null
		else:
			interactibles.erase(item)

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

func get_move_input(delta: float) -> void:
	var vy = velocity.y
	velocity.y = 0

	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
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
	var ground := Plane(Vector3.UP, global_transform.origin.y)
	var hit := ground.intersects_ray(ro, rd) as Vector3
	return hit if hit != null else Vector3.INF

func handle_interactible(body: StaticBody3D, enable: bool) -> void:
	if body.is_in_group("interactible"):
		if enable and not interactibles.has(body):
			interactibles.append(body)
		elif not enable and interactibles.has(body):
			interactibles.erase(body)
			body.notice(false)
			if body == closest_item:
				closest_item = null

func _on_interactor_body_entered(body: StaticBody3D) -> void:
	handle_interactible(body, true)

func _on_interactor_body_exited(body: Node3D) -> void:
	handle_interactible(body, false)
