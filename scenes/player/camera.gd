extends Node
class_name CharacterCameraUtils

var character: CharacterBody3D

func _init(node: CharacterBody3D) -> void:
	character = node

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

func initialize(rotation_angle: float) -> void:
	camera_yaw_offset = rotation_angle
	camera_offset = character.camera.global_transform.origin - character.global_transform.origin
	camera_offset = camera_offset.rotated(Vector3.UP, camera_yaw_offset)
	character.camera.rotation.y = camera_yaw_offset
	base_camera_offset = camera_offset
	base_camera_basis = character.camera.global_transform.basis
	base_camera_fov = character.camera.fov
	camera_override_fov = base_camera_fov

func update(delta: float) -> void:
	_advance_temporary_camera_damping_time_constant(delta)
	var target_camera_position = _get_camera_target_position()
	var damping_time_constant = _get_active_camera_damping_time_constant()
	var camera_step = SmoothDamp.smooth_damp_vector3_step(character.camera.global_transform.origin, target_camera_position, camera_velocity, damping_time_constant, delta)
	character.camera.global_transform.origin = camera_step.value
	camera_velocity = camera_step.velocity
	_update_camera_orientation(camera_step.blend_factor)
	_update_camera_fov(camera_step.blend_factor)
	character.portal_indicator_utils.update_portal_indicator(delta)

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

# HELPERS

func _get_camera_target_position() -> Vector3:
	var focus_position = character.global_transform.origin
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
	return character.camera_damping_time_constant

func _advance_temporary_camera_damping_time_constant(delta: float) -> void:
	if camera_temporary_damping_duration_remaining <= 0.0:
		return
	camera_temporary_damping_duration_remaining = maxf(camera_temporary_damping_duration_remaining - delta, 0.0)

func _update_camera_orientation(smoothing_factor: float) -> void:
	var target_basis = base_camera_basis
	if camera_override_active:
		target_basis = character.camera.global_transform.looking_at(camera_override_target, Vector3.UP).basis
	character.camera.global_transform.basis = character.camera.global_transform.basis.slerp(target_basis, smoothing_factor)

func _update_camera_fov(smoothing_factor: float) -> void:
	var target_fov = base_camera_fov
	if camera_override_active:
		target_fov = camera_override_fov
	character.camera.fov = lerpf(character.camera.fov, target_fov, smoothing_factor)
