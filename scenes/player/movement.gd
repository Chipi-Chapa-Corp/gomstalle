extends Node
class_name CharacterMovement

var character: CharacterBody3D
var _step_time := 0.0
const STEP_INTERVAL_WALK := 0.58
const STEP_INTERVAL_RUN := 0.5

var _was_moving := false
var _was_grounded := false

func _init(node: CharacterBody3D) -> void:
	character = node

func _update_footsteps(delta: float, is_moving: bool, is_running: bool) -> void:
	var grounded := character.is_on_floor()

	if !grounded or !is_moving:
		_step_time = 0.0
		_was_moving = is_moving
		_was_grounded = grounded
		return

	var interval := STEP_INTERVAL_RUN if is_running else STEP_INTERVAL_WALK

	var just_started := is_moving and !_was_moving
	var just_landed := grounded and !_was_grounded

	if just_started or just_landed:
		character.movement_audio_player.play()
		_step_time = 0.0
	else:
		_step_time += delta
		if _step_time >= interval:
			_step_time = 0.0
			character.movement_audio_player.play()

	_was_moving = is_moving
	_was_grounded = grounded

func handle(delta: float) -> void:
	var vertical_velocity = character.velocity.y
	character.velocity.y = 0.0

	var run_requested = Input.is_action_pressed("run")
	var movement_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var movement_direction = Vector3.ZERO
	if movement_input != Vector2.ZERO:
		var input_vector = Vector3(movement_input.x, 0.0, movement_input.y)
		movement_direction = input_vector.rotated(Vector3.UP, character.camera_yaw_offset)
	if movement_direction.length() > 1.0:
		movement_direction = movement_direction.normalized()
	var is_moving := movement_direction.length() > 0.0
	var has_stamina = character.stamina > 0.0
	var is_running = run_requested and has_stamina and is_moving
	character.current_move_speed = character.run_move_speed if is_running else character.base_move_speed

	var horizontal_velocity = movement_direction * character.current_move_speed
	if character.dash > 0.0:
		var dash_dir = movement_direction if is_moving else character.model.global_transform.basis.z
		dash_dir.y = 0.0
		dash_dir = dash_dir.normalized()
		var new_velocity = horizontal_velocity + dash_dir * character.dash
		horizontal_velocity = new_velocity.limit_length(character.dash_speed)

	character.velocity.x = horizontal_velocity.x
	character.velocity.z = horizontal_velocity.z
	character.animation_velocity = character.animation_velocity.lerp(horizontal_velocity, 0.15)

	var local_velocity = character.model.global_transform.basis.inverse() * character.animation_velocity
	var local_plane_velocity = Vector2(local_velocity.x, -local_velocity.z)

	var walk_blend_position = local_plane_velocity / character.base_move_speed if character.base_move_speed != 0.0 else Vector2.ZERO
	walk_blend_position = walk_blend_position.limit_length(1.0)
	character.anim_tree.set("parameters/IW/Walk/blend_position", walk_blend_position)

	var run_blend_position = local_plane_velocity / character.run_move_speed if character.run_move_speed != 0.0 else Vector2.ZERO
	run_blend_position = run_blend_position.limit_length(1.0)
	character.anim_tree.set("parameters/IW/Run/blend_position", run_blend_position)

	var target_movement_state = 1.0 if is_running else 0.0
	character.movement_state_blend = lerp(character.movement_state_blend, target_movement_state, 0.15)
	character.anim_tree.set("parameters/IW/MovementState/blend_amount", character.movement_state_blend)

	if is_running:
		character.stamina = max(character.stamina - character.stamina_usage * delta, 0.0)
	elif not run_requested:
		character.stamina = min(character.stamina + character.stamina_regen * delta, character.max_stamina)
	if character.is_multiplayer_authority():
		character.stamina_bar.visible = character.stamina < character.max_stamina
		character.stamina_bar.value = character.stamina / character.max_stamina * 100.0

	character.dash = max(character.dash - (character.dash_speed / character.dash_duration) * delta, 0.0)
	character.velocity.y = vertical_velocity

	_update_footsteps(delta, is_moving, is_running)
