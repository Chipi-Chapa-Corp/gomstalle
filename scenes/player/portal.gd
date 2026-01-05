extends Node
class_name CharacterPortalIndicatorUtils

var character: CharacterBody3D

func _init(node: CharacterBody3D) -> void:
	character = node

func update_portal_indicator(delta: float) -> void:
	if not _should_show_portal_indicator():
		character.portal_indicator.visible = false
		return
	var portal_direction = GameState.portal_position - character.global_position
	portal_direction.y = 0.0
	if portal_direction.length_squared() == 0.0:
		portal_direction = Vector3.FORWARD
	var normalized_direction = portal_direction.normalized()
	var target_yaw = atan2(normalized_direction.x, normalized_direction.z)
	var rotation_blend = clampf(delta * character.portal_indicator_turn_speed, 0.0, 1.0)
	character.portal_indicator_yaw = lerp_angle(character.portal_indicator_yaw, target_yaw, rotation_blend)
	character.portal_indicator.rotation = Vector3(0.0, character.portal_indicator_yaw, 0.0)
	var base_position = _get_portal_indicator_base_position()
	var base = base_position + normalized_direction * character.portal_indicator_distance
	var offset = Vector3(0.0, character.portal_indicator_height_offset, 0.0)
	character.portal_indicator.global_position = base + offset
	character.portal_indicator.visible = true

# HELPERS

func _should_show_portal_indicator() -> bool:
	if not GameState.portal_active:
		return false
	if character.camera_override_active:
		return false
	return true

func _get_portal_indicator_base_position() -> Vector3:
	var base_position = character.global_position
	character.surface_ray.force_raycast_update()
	if character.surface_ray.is_colliding():
		base_position = character.surface_ray.get_collision_point()
	return base_position
