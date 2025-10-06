extends Node
class_name CharacterInteractions

var character: CharacterBody3D

func _init(node: CharacterBody3D) -> void:
	character = node

func handle(_delta: float) -> void:
	if character.is_dead:
		return
	if Input.is_action_just_pressed("interact") and character.cooldown_timer.time_left <= 0.0:
		var forward_direction: Vector3 = character.model.global_transform.basis.z.normalized()
		var metadata = {
			"position": character.global_transform.origin,
			"hand": character.hand.get_path(),
			"target": character.get_path(),
			"direction": forward_direction,
		}

		if character.item != null:
			character.item.interact(false, metadata)
			character.item = null
			character.anim_tree.set("parameters/IW/Hold_B/blend_amount", 0.0)
		elif character.closest_item != null:
			character.cooldown_timer.start()
			character.anim_tree.set("parameters/IW/Interact_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			character.closest_item.interact(true, metadata)
			if not character.closest_item.get_is_static():
				character.item = character.closest_item
				character.anim_tree.set("parameters/IW/Hold_B/blend_amount", 1.0)

	if character.item != null:
		return

	var next_closest_item: PhysicsBody3D = null
	character.interact_query_params.transform = Transform3D(Basis(), character.global_transform.origin)
	var hits: Array[Dictionary] = character.space.intersect_shape(character.interact_query_params, character.max_interact_results)
	var best_distance := INF
	var seen_bodies := {}
	for hit in hits:
		var collider: PhysicsBody3D = hit.get("collider")
		var is_collider_valid = collider != null and not seen_bodies.has(collider)
		var is_collider_interactible = collider.is_in_group("interactible")
		var is_collider_accessible = not character.is_hunter or (is_collider_interactible and collider.get_hunter_can_interact())
		if not is_collider_valid or not is_collider_interactible or not is_collider_accessible:
			continue
		seen_bodies[collider] = true
		var point: Vector3 = hit.get("point", Vector3.ZERO)
		if point == Vector3.ZERO:
			point = collider.global_transform.origin
		var distance := character.global_transform.origin.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			next_closest_item = collider

	if next_closest_item != character.closest_item:
		if character.closest_item:
			character.closest_item.notice(false)
		character.closest_item = next_closest_item
		if character.closest_item:
			character.closest_item.notice(true)