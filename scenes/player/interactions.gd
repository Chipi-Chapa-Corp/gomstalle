extends Node
class_name CharacterInteractions

var character: CharacterBody3D

func _init(node: CharacterBody3D) -> void:
	character = node

func handle(_delta: float) -> void:
	_update_target()
	if not Input.is_action_just_pressed("interact") or character.cooldown_timer.time_left > 0.0:
		return
	if character.is_hunter and Input.is_action_just_pressed("attack"):
		return
	if character.item != null:
		character.cooldown_timer.start()
		character.item.interact(false, {})
		character.rpc("play_action_animation", &"Throw")
	elif character.closest_item != null:
		character.cooldown_timer.start()
		character.rpc("play_action_animation", &"Interact")
		character.closest_item.interact(true, {})

func _update_target() -> void:
	if character.item != null:
		return
	var next_closest_item: Interactable
	character.interact_query_params.transform = Transform3D(Basis.IDENTITY, character.global_position + Vector3.UP * 0.6)
	var hits: Array[Dictionary] = character.space.intersect_shape(character.interact_query_params, character.max_interact_results)
	var best_distance := INF
	for hit in hits:
		var collider := hit["collider"] as Interactable
		if collider == null or not collider.is_in_group("interactible"):
			continue
		if not collider.can_player_interact(character, true):
			continue
		var distance := character.global_position.distance_squared_to(collider.global_position)
		if distance < best_distance:
			best_distance = distance
			next_closest_item = collider
	if next_closest_item == character.closest_item:
		return
	if is_instance_valid(character.closest_item):
		character.closest_item.notice(false)
	character.closest_item = next_closest_item
	if character.closest_item != null:
		character.closest_item.notice(true)
