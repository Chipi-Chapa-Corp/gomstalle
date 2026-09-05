extends RefCounted
class_name CastleBotController

const SIGHT_DISTANCE: float = 18.0
const FLEE_DISTANCE: float = 11.0
const INTERACTION_DISTANCE: float = 1.8

var character: CharacterBody3D
var _destination := Vector3.ZERO
var _path := PackedVector3Array()
var _path_index: int = 0
var _decision_time: float = 0.0
var _path_time: float = 0.0
var _stuck_time: float = 0.0
var _last_position := Vector3.ZERO
var _memory_time: float = 0.0
var _target_peer_id: int = 0
var _interaction: Interactable
var _fleeing: bool = false
var _delivering: bool = false
var _avoidance_target := Vector3.ZERO
var _avoidance_time: float = 0.0
var _random := RandomNumberGenerator.new()

func _init(player: CharacterBody3D) -> void:
	character = player
	_last_position = character.position
	_random.seed = absi(character.peer_id) * 7919

func handle(delta: float) -> void:
	character.actions.advance_attack(delta)
	if GameState.game_state not in [GameState.State.HIDING, GameState.State.STARTED]:
		character.movement._apply_movement(delta, Vector2.ZERO, false)
		return
	var world: Node3D = character.get_tree().current_scene
	var navigation: CastleNavigation = world.round_utils.navigation
	_decision_time -= delta
	_path_time -= delta
	_memory_time = maxf(0.0, _memory_time - delta)
	if _decision_time <= 0.0:
		_decision_time = 0.35
		_choose_destination(world, navigation)
	if _path_time <= 0.0 or _path.is_empty():
		_path_time = 0.8
		_path = navigation.find_path(character.global_position, _destination)
		_path_index = 0
	while _path_index < _path.size() and _horizontal_distance(character.global_position, _path[_path_index]) < 0.55:
		_path_index += 1
	var direction := Vector3.ZERO
	if _path_index < _path.size():
		direction = _path[_path_index] - character.global_position
		direction.y = 0.0
		direction = direction.normalized()
	if is_instance_valid(_interaction) and _horizontal_distance(character.global_position, _interaction.global_position) <= INTERACTION_DISTANCE:
		_face(_interaction.global_position - character.global_position, delta)
		_interaction.interact_for_player(character, true)
		direction = Vector3.ZERO
	_open_nearby_door(direction)
	direction = _steer_around_moving_obstacles(direction, delta)
	if character.is_hunter:
		var target := _find_player(_target_peer_id)
		if target != null and _horizontal_distance(character.global_position, target.global_position) < 3.0:
			_face(target.global_position - character.global_position, delta)
			if character.can_reach_attack(target):
				character.actions.start_attack()
				direction *= 0.25
	if direction != Vector3.ZERO:
		_face(direction, delta)
		_stuck_time += delta
		if _stuck_time >= 1.2:
			if _horizontal_distance(character.global_position, _last_position) < 0.4:
				character.movement.request_jump()
				_path_time = 0.0
				_decision_time = 0.0
				_destination += Vector3(direction.z, 0.0, -direction.x) * 2.0
			_last_position = character.global_position
			_stuck_time = 0.0
	if _fleeing and character.ability_cooldown_timer.time_left <= 0.0:
		if character.is_on_floor():
			character.movement.request_jump()
		else:
			character.movement.start_air_slide()
	var local_direction := direction.rotated(Vector3.UP, -character.camera_utils.camera_yaw_offset)
	var sprint: bool = (_fleeing or character.is_hunter and _memory_time > 0.0) and character.stamina > 8.0
	character.movement._apply_movement(delta, Vector2(local_direction.x, local_direction.z), sprint)

func _choose_destination(world: Node3D, navigation: CastleNavigation) -> void:
	_interaction = null
	_fleeing = false
	if character.is_hunter:
		_choose_hunter_destination(world, navigation)
		return
	var hunter := _find_player(GameState.hunter_peer_id)
	if GameState.game_state == GameState.State.STARTED and hunter != null \
		and _horizontal_distance(character.global_position, hunter.global_position) < FLEE_DISTANCE and _can_see(hunter):
		_fleeing = true
		_destination = _flee_destination(hunter.global_position, navigation)
		return
	if GameState.portal_active:
		_destination = GameState.portal_position
		return
	var wood_count: int = character.inventory.items[CharacterInventory.InventoryItem.WOOD]
	if wood_count >= 6 or wood_count >= 3 and GameState.shrines_completed == GameState.shrines_total - 1:
		_delivering = true
	elif wood_count < 3:
		_delivering = false
	var best_distance := INF
	for candidate in world.get_tree().get_nodes_in_group("interactible"):
		if not candidate is Interactable:
			continue
		var usable: bool
		if _delivering:
			usable = candidate.is_in_group("shrine") and candidate.is_active and not candidate.is_filled
		else:
			usable = candidate.get_script() == preload("res://scenes/pile/script.gd") and candidate.current_amount > 0
		if not usable:
			continue
		var distance := character.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			_interaction = candidate
	if is_instance_valid(_interaction):
		_destination = _interaction.global_position
	elif _path_index >= _path.size():
		_destination = _patrol_destination(navigation)

func _choose_hunter_destination(world: Node3D, navigation: CastleNavigation) -> void:
	var closest: CharacterBody3D
	var nearest_distance := SIGHT_DISTANCE
	for player in world.player_container.get_children():
		if player.is_hunter or not GameState.can_player_act(player.peer_id):
			continue
		var distance := character.global_position.distance_to(player.global_position)
		if distance < nearest_distance and _can_see(player):
			nearest_distance = distance
			closest = player
	if closest != null:
		_target_peer_id = closest.peer_id
		_destination = closest.global_position
		_memory_time = 4.0
		return
	if _memory_time <= 0.0:
		_target_peer_id = 0
		if _path_index >= _path.size() or _horizontal_distance(character.global_position, _destination) < 1.5:
			_destination = _patrol_destination(navigation)

func _patrol_destination(navigation: CastleNavigation) -> Vector3:
	var identifiers := navigation.graph.get_point_ids()
	var identifier := identifiers[_random.randi_range(0, identifiers.size() - 1)]
	return navigation.graph.get_point_position(identifier)

func _flee_destination(hunter_position: Vector3, navigation: CastleNavigation) -> Vector3:
	var best_position := character.global_position
	var best_score := -INF
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var candidate := character.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 12.0
		var path := navigation.find_path(character.global_position, candidate)
		if path.is_empty():
			continue
		var destination := path[path.size() - 1]
		var score := _horizontal_distance(destination, hunter_position) - _horizontal_distance(destination, character.global_position) * 0.2
		if score > best_score:
			best_score = score
			best_position = destination
	return best_position

func _open_nearby_door(direction: Vector3) -> void:
	if direction == Vector3.ZERO:
		return
	for interaction in character.get_tree().get_nodes_in_group("interactible"):
		if not interaction is Door or not is_zero_approx(interaction.open_target_degrees):
			continue
		var offset: Vector3 = interaction.global_position - character.global_position
		offset.y = 0.0
		if offset.length() < 2.2 and offset.normalized().dot(direction) > 0.25:
			interaction.interact_for_player(character, true)

func _steer_around_moving_obstacles(direction: Vector3, delta: float) -> Vector3:
	_avoidance_time = maxf(0.0, _avoidance_time - delta)
	if _avoidance_time > 0.0 and _horizontal_distance(character.global_position, _avoidance_target) > 0.45:
		var detour := _avoidance_target - character.global_position
		detour.y = 0.0
		return detour.normalized()
	if _avoidance_time > 0.0:
		_avoidance_time = 0.0
		_path_time = 0.0
	if direction == Vector3.ZERO:
		return direction
	var origin := character.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.2, 1, [character.get_rid()])
	var obstruction := character.get_world_3d().direct_space_state.intersect_ray(query)
	if obstruction.is_empty() or not (obstruction["collider"] is AnimatableBody3D or obstruction["collider"] is RigidBody3D):
		return direction
	for angle in [60.0, -60.0, 90.0, -90.0, 120.0, -120.0]:
		var candidate := direction.rotated(Vector3.UP, deg_to_rad(angle))
		var side := Vector3(candidate.z, 0.0, -candidate.x) * 0.3
		var clear := true
		for offset in [side, -side]:
			query.from = origin + offset
			query.to = origin + offset + candidate * 2.2
			if not character.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				clear = false
				break
		if clear:
			_avoidance_target = character.global_position + candidate * 2.2
			_avoidance_time = 1.2
			return candidate
	return direction

func _can_see(target: CharacterBody3D) -> bool:
	var origin := character.global_position + Vector3.UP
	var destination := target.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, [character.get_rid(), target.get_rid()])
	return character.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _find_player(peer_id: int) -> CharacterBody3D:
	for player in character.get_tree().get_nodes_in_group("players"):
		if player.peer_id == peer_id:
			return player
	return null

func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		var target_yaw := atan2(direction.x, direction.z)
		character.model.rotation.y = lerp_angle(character.model.rotation.y, target_yaw, minf(1.0, delta * 12.0))

func _horizontal_distance(origin: Vector3, destination: Vector3) -> float:
	return Vector2(origin.x - destination.x, origin.z - destination.z).length()
