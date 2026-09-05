extends RefCounted
class_name CastleNavigation

const GRID_SPACING: float = 1.0
const MAX_SLOPE_RISE: float = 1.1

var world: Node3D
var graph := AStar3D.new()
var points: Dictionary[Vector2i, Array] = {}
var excluded_bodies: Array[RID] = []
var _space: PhysicsDirectSpaceState3D

func _init(node: Node3D) -> void:
	world = node
	_space = world.get_world_3d().direct_space_state

func build() -> void:
	var build_started := Time.get_ticks_usec()
	var floor_cells := Utils.get_floor_cells(world.grid_map)
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for cell in floor_cells:
		var position: Vector3 = world.grid_map.to_global(world.grid_map.map_to_local(cell))
		minimum = minimum.min(position)
		maximum = maximum.max(position)
	for player in world.get_tree().get_nodes_in_group("players"):
		excluded_bodies.append(player.get_rid())
	for interaction in world.get_tree().get_nodes_in_group("interactible"):
		if interaction is Door:
			excluded_bodies.append(interaction.body.get_rid())
		elif interaction is RigidBody3D:
			excluded_bodies.append(interaction.get_rid())
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = capsule
	shape_query.collision_mask = 1
	shape_query.exclude = excluded_bodies
	for grid_x in range(floori(minimum.x) - 2, ceili(maximum.x) + 3):
		for grid_z in range(floori(minimum.z) - 2, ceili(maximum.z) + 3):
			var top := maximum.y + 1.5
			for layer in 3:
				var origin := Vector3((grid_x + 0.25) * GRID_SPACING, top, (grid_z + 0.25) * GRID_SPACING)
				var destination := Vector3(origin.x, minimum.y - 1.0, origin.z)
				var ray := PhysicsRayQueryParameters3D.create(origin, destination, 1, excluded_bodies)
				var hit := _space.intersect_ray(ray)
				if hit.is_empty():
					break
				var position: Vector3 = hit["position"]
				top = position.y - 0.35
				var normal: Vector3 = hit["normal"]
				if normal.y < 0.7:
					continue
				shape_query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.95)
				if not _space.intersect_shape(shape_query, 1).is_empty():
					continue
				var identifier := graph.get_available_point_id()
				graph.add_point(identifier, position)
				var coordinate := Vector2i(grid_x, grid_z)
				if not points.has(coordinate):
					points[coordinate] = []
				points[coordinate].append(identifier)
	var samples_finished := Time.get_ticks_usec()
	for coordinate in points:
		for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1)]:
			var neighbor: Vector2i = coordinate + offset
			if not points.has(neighbor):
				continue
			for start_id: int in points[coordinate]:
				for end_id: int in points[neighbor]:
					var start := graph.get_point_position(start_id)
					var finish := graph.get_point_position(end_id)
					if absf(start.y - finish.y) > MAX_SLOPE_RISE * GRID_SPACING:
						continue
					if not segment_clear(start, finish):
						continue
					graph.connect_points(start_id, end_id)
	var links_finished := Time.get_ticks_usec()
	_retain_reachable_floor()
	print("CASTLE_NAVIGATION points=%d samples_ms=%.1f links_ms=%.1f connected_ms=%.1f" % [graph.get_point_count(),
		float(samples_finished - build_started) / 1000.0, float(links_finished - samples_finished) / 1000.0,
		float(Time.get_ticks_usec() - links_finished) / 1000.0])

func _retain_reachable_floor() -> void:
	assert(graph.get_point_count() > 0, "The castle requires walkable floors.")
	var pending: Array[int] = [graph.get_closest_point(GameState.player_spawn_center)]
	var visited: Dictionary[int, bool] = {pending[0]: true}
	var cursor := 0
	while cursor < pending.size():
		var identifier := pending[cursor]
		cursor += 1
		for neighbor in graph.get_point_connections(identifier):
			if not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	for identifier in graph.get_point_ids():
		if not visited.has(identifier):
			graph.remove_point(identifier)

func find_path(origin: Vector3, destination: Vector3) -> PackedVector3Array:
	if graph.get_point_count() == 0:
		return PackedVector3Array()
	return graph.get_point_path(graph.get_closest_point(origin), graph.get_closest_point(destination), true)

func segment_clear(origin: Vector3, destination: Vector3) -> bool:
	for height in [0.4, 1.1]:
		var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * height, destination + Vector3.UP * height, 1, excluded_bodies)
		if not _space.intersect_ray(ray).is_empty():
			return false
	return true
