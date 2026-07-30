extends Node
class_name WorldPortalUtils

const MIN_PORTAL_WALL_DISTANCE := 3.0
const PORTAL_CLEARANCE_FACTOR := 1.1

class PortalCandidate:
	var cell: Vector3i
	var item_id: int
	var position: Vector3

	func _init(cell_value: Vector3i, item_id_value: int, position_value: Vector3) -> void:
		cell = cell_value
		item_id = item_id_value
		position = position_value

var world: Node3D
var portal_triggered := false

func _init(node: Node3D) -> void:
	world = node

func trigger_portal() -> void:
	if portal_triggered or world.grid_map == null or world.grid_map.mesh_library == null:
		return
	var chosen = _select_portal_candidate_farthest_from_players()
	world.spawn_portal.rpc(chosen.cell, chosen.item_id)

func spawn_portal(cell: Vector3i, item_id: int) -> void:
	if portal_triggered:
		return
	portal_triggered = true
	if world.grid_map == null or world.grid_map.mesh_library == null or world.portal_scene == null:
		return
	var container = world.portal_container
	if container == null:
		container = world
	var tile_mesh = world.grid_map.mesh_library.get_item_mesh(item_id)
	if tile_mesh == null:
		return
	var cell_transform = _get_cell_global_transform(cell)
	var tile_instance := MeshInstance3D.new()
	tile_instance.mesh = tile_mesh
	tile_instance.global_transform = cell_transform
	container.add_child(tile_instance)
	world.grid_map.set_cell_item(cell, -1)
	var portal_instance: EscapePortal = world.portal_scene.instantiate()
	container.add_child(portal_instance)
	portal_instance.visible = false
	portal_instance.global_position = cell_transform.origin + Vector3(0, -world.portal_depth_offset, 0)
	_scale_portal(portal_instance, tile_instance)
	await _run_portal_sequence(tile_instance, portal_instance, cell_transform.origin, cell)

func _run_portal_sequence(tile_instance: MeshInstance3D, portal_instance: EscapePortal, portal_position: Vector3, portal_cell: Vector3i) -> void:
	var local_player = _get_local_player()
	_start_portal_camera_cinematic(local_player, portal_position, portal_cell)
	await world.get_tree().create_timer(world.portal_camera_focus_duration).timeout
	portal_instance.open(world.portal_tile_slide_duration)
	GameState.portal_position = portal_position
	GameState.portal_active = true
	var slide_offset = _get_portal_slide_offset(tile_instance)
	var lift_offset = _get_portal_lift_offset(tile_instance)
	var tile_start_position = tile_instance.global_position
	var tween = world.create_tween()
	tween.tween_property(tile_instance, "global_position", tile_start_position + lift_offset, world.portal_tile_slide_duration * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile_instance, "global_position", tile_start_position + slide_offset, world.portal_tile_slide_duration * 0.8).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await world.get_tree().create_timer(world.portal_open_hold_duration).timeout
	if local_player != null:
		_finish_portal_camera_cinematic(local_player)
		await world.get_tree().create_timer(world.portal_camera_return_duration).timeout
		GameState.portal_cinematic_active = false

func _collect_floor_candidates() -> Array[PortalCandidate]:
	var candidates: Array[PortalCandidate] = []
	if world.grid_map == null or world.grid_map.mesh_library == null:
		return candidates
	var blocker_positions = _get_portal_blocker_positions()
	var grid_bounds = _get_grid_bounds()
	var floor_cells = Utils.get_floor_cells(world.grid_map)
	for cell in floor_cells:
		var item_id = world.grid_map.get_cell_item(cell)
		var candidate_position = world.grid_map.to_global(world.grid_map.map_to_local(cell))
		var clearance = _get_portal_clearance(item_id)
		if not _is_position_clear_of_blockers(candidate_position, blocker_positions, clearance):
			continue
		if _get_nearest_wall_distance(cell, grid_bounds) < MIN_PORTAL_WALL_DISTANCE:
			continue
		candidates.append(PortalCandidate.new(cell, item_id, candidate_position))
	return candidates

func _get_portal_blocker_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for node in world.get_tree().get_nodes_in_group("portal_blocker"):
		assert(node is Node3D)
		var blocker := node as Node3D
		positions.append(blocker.global_position)
	return positions

func _get_portal_clearance(item_id: int) -> float:
	var tile_mesh = world.grid_map.mesh_library.get_item_mesh(item_id)
	var tile_size = tile_mesh.get_aabb().size
	return maxf(tile_size.x, tile_size.z) * PORTAL_CLEARANCE_FACTOR

func _is_position_clear_of_blockers(position: Vector3, blocker_positions: Array[Vector3], clearance: float) -> bool:
	var floor_position = Vector2(position.x, position.z)
	for blocker_position in blocker_positions:
		if floor_position.distance_to(Vector2(blocker_position.x, blocker_position.z)) < clearance:
			return false
	return true

func _get_nearest_wall_distance(cell: Vector3i, bounds: Dictionary) -> float:
	var nearest_distance := INF
	var directions: Array[Vector3i] = [
		Vector3i(1, 0, 0),
		Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1),
		Vector3i(0, 0, -1),
	]
	for direction in directions:
		nearest_distance = minf(nearest_distance, _distance_to_wall(cell, direction, bounds))
	return nearest_distance

func _select_portal_candidate_farthest_from_players() -> PortalCandidate:
	var candidates = _collect_floor_candidates()
	assert(not candidates.is_empty(), "Portal requires at least one floor tile candidate.")
	var player_positions = _get_player_positions()
	var best_index = _find_candidate_index_farthest_from_players(candidates, player_positions)
	assert(best_index >= 0, "Portal candidate selection returned an invalid index.")
	return candidates[best_index]

func _find_candidate_index_farthest_from_players(candidates: Array[PortalCandidate], player_positions: Array[Vector3]) -> int:
	if player_positions.is_empty():
		return 0
	var best_index := 0
	var best_min_distance := -INF
	for index in candidates.size():
		var candidate_position: Vector3 = candidates[index].position
		var closest_player_distance := INF
		for player_position in player_positions:
			var distance_to_player := candidate_position.distance_to(player_position)
			if distance_to_player < closest_player_distance:
				closest_player_distance = distance_to_player
		if closest_player_distance > best_min_distance:
			best_min_distance = closest_player_distance
			best_index = index
	return best_index

func _get_player_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for player in world.player_container.get_children():
		if player is Node3D:
			positions.append(player.global_position)
	return positions

func _get_local_player() -> Node:
	for player in world.player_container.get_children():
		if player.has_method("is_multiplayer_authority") and player.is_multiplayer_authority():
			return player
	return null

func _get_cell_global_transform(cell: Vector3i) -> Transform3D:
	var local_position = world.grid_map.map_to_local(cell)
	var local_basis = world.grid_map.get_cell_item_basis(cell)
	var cell_global_basis = world.grid_map.global_transform.basis * local_basis
	var cell_global_position = world.grid_map.to_global(local_position)
	return Transform3D(cell_global_basis, cell_global_position)

func _get_portal_slide_offset(tile_instance: MeshInstance3D) -> Vector3:
	if world.grid_map == null:
		return Vector3.ZERO
	var tile_size = world.grid_map.cell_size.x
	var tile_height = world.grid_map.cell_size.y
	if tile_instance != null:
		var tile_bounds = tile_instance.get_aabb().size
		tile_size = max(tile_size, max(tile_bounds.x, tile_bounds.z))
		tile_height = max(tile_height, tile_bounds.y)
	var direction = world.grid_map.global_transform.basis.x
	if direction.length() == 0.0:
		direction = Vector3.RIGHT
	var down = - world.grid_map.global_transform.basis.y
	if down.length() == 0.0:
		down = Vector3.DOWN
	return (direction.normalized() * tile_size + down.normalized() * tile_height * 0.25) * world.portal_tile_slide_distance_multiplier

func _get_portal_lift_offset(tile_instance: MeshInstance3D) -> Vector3:
	var tile_height = world.grid_map.cell_size.y
	if tile_instance != null:
		tile_height = max(tile_height, tile_instance.get_aabb().size.y)
	var up = world.grid_map.global_transform.basis.y
	return up.normalized() * tile_height * 0.12

func _start_portal_camera_cinematic(local_player: Node, portal_position: Vector3, portal_cell: Vector3i) -> void:
	assert(local_player != null)
	GameState.portal_cinematic_active = true
	var corner_direction = _get_portal_corner_direction(portal_cell)
	var approach_damping_time_constant = SmoothDamp.damping_time_constant_for_progress_fraction(world.portal_camera_focus_duration)
	local_player.camera_utils.set_camera_override(portal_position, corner_direction, world.portal_camera_zoom_fov, approach_damping_time_constant)

func _finish_portal_camera_cinematic(local_player: Node) -> void:
	var camera_utils = local_player.camera_utils
	camera_utils.clear_camera_override()
	var return_damping_time_constant = SmoothDamp.damping_time_constant_for_progress_fraction(world.portal_camera_return_duration)
	camera_utils.set_temporary_camera_damping_time_constant(return_damping_time_constant, world.portal_camera_return_duration)

func _scale_portal(portal: EscapePortal, tile_instance: MeshInstance3D) -> void:
	if tile_instance == null or world.grid_map == null:
		return
	var tile_bounds = tile_instance.get_aabb().size
	var cell_size = world.grid_map.cell_size
	var portal_size = maxf(maxf(tile_bounds.x, tile_bounds.z), maxf(cell_size.x, cell_size.z))
	if portal_size <= 0.0:
		return
	portal.fit_to_size(portal_size * 1.05)

func _get_portal_corner_direction(portal_cell: Vector3i) -> Vector3:
	if world.grid_map == null:
		return Vector3.ONE.normalized()
	var bounds = _get_grid_bounds()
	var x_sign = _get_nearest_wall_sign(portal_cell, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), bounds)
	var z_sign = _get_nearest_wall_sign(portal_cell, Vector3i(0, 0, 1), Vector3i(0, 0, -1), bounds)
	if x_sign == 0:
		x_sign = 1
	if z_sign == 0:
		z_sign = 1
	var local_direction = Vector3(float(x_sign), 0.0, float(z_sign))
	if local_direction.length() == 0.0:
		local_direction = Vector3(1.0, 0.0, 1.0)
	var world_direction = world.grid_map.global_transform.basis * local_direction
	if world_direction.length() == 0.0:
		return local_direction.normalized()
	return world_direction.normalized()

func _get_grid_bounds() -> Dictionary:
	var used_cells: Array[Vector3i] = world.grid_map.get_used_cells()
	if used_cells.is_empty():
		return {"min_x": 0, "max_x": 0, "min_z": 0, "max_z": 0}
	var min_x = used_cells[0].x
	var max_x = used_cells[0].x
	var min_z = used_cells[0].z
	var max_z = used_cells[0].z
	for cell in used_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_z = min(min_z, cell.z)
		max_z = max(max_z, cell.z)
	return {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}

func _get_nearest_wall_sign(portal_cell: Vector3i, positive_dir: Vector3i, negative_dir: Vector3i, bounds: Dictionary) -> int:
	var positive_distance = _distance_to_wall(portal_cell, positive_dir, bounds)
	var negative_distance = _distance_to_wall(portal_cell, negative_dir, bounds)
	if positive_distance == INF and negative_distance == INF:
		return 0
	if positive_distance <= negative_distance:
		return positive_dir.x + positive_dir.z
	return negative_dir.x + negative_dir.z

func _distance_to_wall(portal_cell: Vector3i, direction: Vector3i, bounds: Dictionary) -> float:
	var min_x: int = bounds["min_x"]
	var max_x: int = bounds["max_x"]
	var min_z: int = bounds["min_z"]
	var max_z: int = bounds["max_z"]
	var step := 1
	while true:
		var cell = portal_cell + direction * step
		if cell.x < min_x or cell.x > max_x or cell.z < min_z or cell.z > max_z:
			return INF
		var item_id = world.grid_map.get_cell_item(cell)
		if item_id >= 0 and Utils.is_wall_item(world.grid_map, item_id):
			return float(step)
		step += 1
	return INF
