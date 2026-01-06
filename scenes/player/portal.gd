extends Node
class_name CharacterPortalIndicatorUtils

var character: CharacterBody3D

func _init(node: CharacterBody3D) -> void:
	character = node

func update_portal_indicator(delta: float) -> void:
	if not _should_show_portal_indicator():
		character.portal_indicator.visible = false
		character.portal_indicator_through_walls.visible = false
		return
	var portal_direction = GameState.portal_position - character.global_position
	portal_direction.y = 0.0
	if portal_direction.length_squared() == 0.0:
		portal_direction = Vector3.FORWARD
	var normalized_direction = portal_direction.normalized()
	var target_yaw = atan2(normalized_direction.x, normalized_direction.z) + PI
	var rotation_blend = clampf(delta * character.portal_indicator_turn_speed, 0.0, 1.0)
	character.portal_indicator_yaw = lerp_angle(character.portal_indicator_yaw, target_yaw, rotation_blend)
	character.portal_indicator.rotation = Vector3(0.0, character.portal_indicator_yaw, 0.0)
	var base_position = _get_portal_indicator_base_position()
	var base = base_position + normalized_direction * character.portal_indicator_distance
	var offset = Vector3(0.0, character.portal_indicator_height_offset, 0.0)
	character.portal_indicator.global_position = base + offset
	character.portal_indicator.visible = true
	character.portal_indicator_through_walls.visible = _should_show_portal_indicator_through_walls()

# HELPERS

func _should_show_portal_indicator() -> bool:
	if not GameState.portal_active:
		return false
	if character.camera_utils.camera_override_active:
		return false
	return true

func _get_portal_indicator_base_position() -> Vector3:
	return character.global_position

func _should_show_portal_indicator_through_walls() -> bool:
	var camera = character.camera
	var origin = camera.global_position
	var target = character.portal_indicator.global_position + Vector3.UP * maxf(character.portal_indicator_height_offset, 0.1)
	if _is_portal_indicator_occluded_by_player(origin, target):
		return false
	return true

func _is_portal_indicator_occluded_by_player(origin: Vector3, target: Vector3) -> bool:
	var to_target = target - origin
	var target_distance = to_target.length()
	if target_distance <= 0.001:
		return false
	var direction = to_target / target_distance
	var player_position = character.position + Vector3.UP * character.portal_indicator_player_occlusion_radius
	var to_player = player_position - origin
	var projected = to_player.dot(direction)
	if projected <= 0.0 or projected >= target_distance:
		return false
	var closest = origin + direction * projected
	return closest.distance_to(player_position) <= character.portal_indicator_player_occlusion_radius
