extends Object

class_name InputTestUtils

const PlayerScript = preload("res://scenes/player/script.gd")

static func apply_movement_input(input_vector: Vector2, run: bool) -> void:
	release_movement_inputs()
	var horizontal = clampf(input_vector.x, -1.0, 1.0)
	var vertical = clampf(input_vector.y, -1.0, 1.0)
	if horizontal < 0.0:
		Input.action_press("move_left", -horizontal)
	elif horizontal > 0.0:
		Input.action_press("move_right", horizontal)
	if vertical < 0.0:
		Input.action_press("move_forward", -vertical)
	elif vertical > 0.0:
		Input.action_press("move_backward", vertical)
	if run:
		Input.action_press("run")

static func release_movement_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("run")

static func release_input_actions() -> void:
	release_movement_inputs()
	Input.action_release("interact")

static func press_action(tree: SceneTree, action: StringName) -> void:
	Input.action_press(action)
	await tree.process_frame
	await tree.physics_frame
	Input.action_release(action)
	await tree.process_frame
	await tree.physics_frame

static func press_interact_for_player(tree: SceneTree, player: PlayerScript) -> void:
	Input.action_press("interact")
	await tree.physics_frame
	player.interactions.handle(0.0)
	Input.action_release("interact")
	await tree.physics_frame

static func input_vector_towards(player: PlayerScript, target_position: Vector3) -> Vector2:
	var offset = target_position - player.global_position
	offset.y = 0.0
	if offset.length() == 0.0:
		return Vector2.ZERO
	var direction = offset.normalized()
	var input_direction = direction.rotated(Vector3.UP, -player.camera_utils.camera_yaw_offset)
	return Vector2(input_direction.x, input_direction.z)

static func input_vector_for_direction(player: PlayerScript, direction: Vector3) -> Vector2:
	var planar = Vector3(direction.x, 0.0, direction.z)
	if planar.length() == 0.0:
		return Vector2.ZERO
	var input_direction = planar.normalized().rotated(Vector3.UP, -player.camera_utils.camera_yaw_offset)
	return Vector2(input_direction.x, input_direction.z)

static func pick_clear_direction(node: Node3D, origin: Vector3, exclude: Array = [], distance: float = 4.0) -> Vector3:
	var space = node.get_world_3d().direct_space_state
	var exclude_rids = resolve_exclude_rids(exclude)
	var directions = [
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(0, 0, -1),
	]
	for direction in directions:
		var from = origin + Vector3(0, 1.0, 0)
		var to = from + direction * distance
		var query = PhysicsRayQueryParameters3D.create(from, to)
		if not exclude_rids.is_empty():
			query.exclude = exclude_rids
		var hit = space.intersect_ray(query)
		if hit.is_empty():
			return direction
	return Vector3(0, 0, 1)

static func resolve_exclude_rids(exclude: Array) -> Array[RID]:
	var rids: Array[RID] = []
	for item in exclude:
		if typeof(item) == TYPE_RID:
			rids.append(item as RID)
		elif item is CollisionObject3D:
			rids.append((item as CollisionObject3D).get_rid())
	return rids

static func move_player_towards(tree: SceneTree, player: PlayerScript, target_position: Vector3, run: bool, target_distance: float, max_frames: int) -> float:
	var frames = 0
	var distance = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(target_position.x, target_position.z))
	while frames < max_frames and distance > target_distance:
		var input_vector = input_vector_towards(player, target_position)
		if input_vector == Vector2.ZERO:
			release_movement_inputs()
		else:
			apply_movement_input(input_vector, run)
		await tree.physics_frame
		distance = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(target_position.x, target_position.z))
		frames += 1
	release_movement_inputs()
	return distance
