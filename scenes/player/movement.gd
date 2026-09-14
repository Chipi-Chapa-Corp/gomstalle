extends Node
class_name CharacterMovement

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.14
const AIR_SLIDE_STAMINA := 12.0
const GROUND_ACCELERATION := 42.0
const AIR_ACCELERATION := 18.0
const STEP_INTERVAL_WALK := 0.42
const STEP_INTERVAL_RUN := 0.31

var character: CharacterBody3D
var is_air_sliding := false
var is_compact := false
var _air_slide_used := false
var _slide_direction := Vector3.ZERO
var _slide_time := 0.0
var _coyote_time := 0.0
var _jump_buffer_time := 0.0
var _step_time := 0.0
var _grounded_before_move := false
var _stamina_recovery_delay := 0.0
var _sprint_exhausted := false

func _init(node: CharacterBody3D) -> void:
	character = node

func reset() -> void:
	is_air_sliding = false
	_air_slide_used = false
	_slide_time = 0.0
	_coyote_time = 0.0
	_jump_buffer_time = 0.0
	character.dash = 0.0
	_sprint_exhausted = false
	_set_compact(false)

func request_jump() -> void:
	_jump_buffer_time = JUMP_BUFFER_TIME

func start_air_slide() -> bool:
	if character.is_hunter or character.is_on_floor() or _air_slide_used or is_compact:
		return false
	if character.is_dead or character.is_stunned or character.ability_cooldown_timer.time_left > 0.0 or character.stamina < AIR_SLIDE_STAMINA:
		return false
	_slide_direction = Vector3(character.velocity.x, 0.0, character.velocity.z).normalized()
	if _slide_direction == Vector3.ZERO:
		_slide_direction = character.model.global_basis.z.normalized()
	_slide_time = character.dash_duration
	_air_slide_used = true
	is_air_sliding = true
	_set_compact(true)
	character.dash = character.dash_speed
	character.velocity.y = clampf(character.velocity.y, -1.5, 1.5)
	character.stamina -= AIR_SLIDE_STAMINA
	_stamina_recovery_delay = 0.8
	character.ability_cooldown_timer.start()
	character.rpc("play_action_animation", &"Roll")
	return true

func handle(delta: float) -> void:
	_apply_movement(delta, Input.get_vector("move_left", "move_right", "move_forward", "move_backward"), Input.is_action_pressed("run"))

func handle_input_locked(delta: float) -> void:
	_jump_buffer_time = 0.0
	is_air_sliding = false
	_slide_time = 0.0
	character.dash = 0.0
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	_apply_movement(delta, Vector2.ZERO, false)

func _apply_movement(delta: float, movement_input: Vector2, run_requested: bool) -> void:
	_ensure_animation_state()
	_grounded_before_move = character.is_on_floor()
	_coyote_time = COYOTE_TIME if _grounded_before_move else maxf(_coyote_time - delta, 0.0)
	if _jump_buffer_time > 0.0 and _coyote_time > 0.0 and not is_compact:
		character.velocity.y = character.jump_height
		_jump_buffer_time = 0.0
		_coyote_time = 0.0
		character.rpc("play_action_animation", &"Jump")
	_jump_buffer_time = maxf(_jump_buffer_time - delta, 0.0)
	var movement_direction := Vector3(movement_input.x, 0.0, movement_input.y).rotated(Vector3.UP, character.camera_utils.camera_yaw_offset).limit_length(1.0)
	var is_moving := movement_direction.length_squared() > 0.01
	if character.stamina >= AIR_SLIDE_STAMINA:
		_sprint_exhausted = false
	var is_running: bool = run_requested and is_moving and character.stamina > 0.0 and not is_compact and not _sprint_exhausted
	character.current_move_speed = character.run_move_speed if is_running else character.base_move_speed
	var target_velocity: Vector3 = movement_direction * character.current_move_speed
	var horizontal_velocity := Vector3(character.velocity.x, 0.0, character.velocity.z)
	var acceleration := GROUND_ACCELERATION if _grounded_before_move else AIR_ACCELERATION
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	if is_air_sliding:
		_slide_time = maxf(_slide_time - delta, 0.0)
		character.dash = lerpf(character.run_move_speed, character.dash_speed, _slide_time / character.dash_duration)
		horizontal_velocity = _slide_direction * character.dash
		if _slide_time == 0.0 or character.is_on_wall():
			is_air_sliding = false
			character.dash = 0.0
	if is_compact and not is_air_sliding and _can_stand():
		_set_compact(false)
	character.anim_tree.set("parameters/IW/Compact_B/blend_amount", 1.0 if is_compact and not is_air_sliding else 0.0)
	character.velocity.x = horizontal_velocity.x
	character.velocity.z = horizontal_velocity.z
	_stamina_recovery_delay = maxf(_stamina_recovery_delay - delta, 0.0)
	if is_running and _grounded_before_move:
		character.stamina = maxf(character.stamina - character.stamina_usage * delta, 0.0)
		_stamina_recovery_delay = 0.6
		_sprint_exhausted = character.stamina == 0.0
	elif not is_air_sliding and _stamina_recovery_delay == 0.0:
		character.stamina = minf(character.stamina + character.stamina_regen * delta, character.max_stamina)
	character.stamina_bar.visible = character.stamina < character.max_stamina
	character.stamina_bar.value = character.stamina / character.max_stamina * 100.0
	_update_animation(delta, horizontal_velocity, is_running)

func finish_physics(delta: float) -> void:
	var grounded := character.is_on_floor()
	if grounded and not _grounded_before_move:
		_air_slide_used = false
		is_air_sliding = false
		character.dash = 0.0
		character.rpc("play_action_animation", &"Land")
		character.rpc("play_footstep")
		_step_time = 0.0
	character.anim_tree.set("parameters/IW/Falling_B/blend_amount", 0.0 if grounded else 1.0)
	var horizontal_speed := Vector2(character.velocity.x, character.velocity.z).length()
	if grounded and horizontal_speed > 0.5:
		_step_time += delta
		var interval := STEP_INTERVAL_RUN if horizontal_speed > character.base_move_speed + 0.5 else STEP_INTERVAL_WALK
		if _step_time >= interval:
			character.rpc("play_footstep")
			_step_time = 0.0
	else:
		_step_time = 0.0

func _update_animation(delta: float, horizontal_velocity: Vector3, is_running: bool) -> void:
	var blend_weight := 1.0 - exp(-12.0 * delta)
	character.animation_velocity = character.animation_velocity.lerp(horizontal_velocity, blend_weight)
	var local_velocity: Vector3 = character.model.global_basis.inverse() * character.animation_velocity
	var local_plane_velocity := Vector2(local_velocity.x, -local_velocity.z)
	character.anim_tree.set("parameters/IW/Walk/blend_position", (local_plane_velocity / character.base_move_speed).limit_length(1.0))
	character.anim_tree.set("parameters/IW/Run/blend_position", (local_plane_velocity / character.run_move_speed).limit_length(1.0))
	character.movement_state_blend = lerpf(character.movement_state_blend, 1.0 if is_running else 0.0, blend_weight)
	character.anim_tree.set("parameters/IW/MovementState/blend_amount", character.movement_state_blend)

func _ensure_animation_state() -> void:
	if character.playback.get_current_node().is_empty():
		character.playback.start("IW")
		character.anim_tree.advance(0.0)

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = character.regular_collider.shape
	query.transform = character.regular_collider.global_transform
	query.transform.origin.y += 0.03
	query.collision_mask = character.collision_mask
	query.exclude = [character.get_rid()]
	return character.space.intersect_shape(query, 1).is_empty()

func _set_compact(enabled: bool) -> void:
	is_compact = enabled
	character.regular_collider.set_deferred("disabled", enabled)
	character.dash_collider.set_deferred("disabled", not enabled)
