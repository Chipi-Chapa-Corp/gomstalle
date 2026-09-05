class_name CastleClearance
extends RefCounted

static func blockers(furniture_bounds: Array[AABB], position_value: Vector3) -> Array[AABB]:
	var standing_space := AABB(position_value + Vector3(-0.55, 0.1, -0.55), Vector3(1.1, 1.9, 1.1))
	var intersections: Array[AABB] = []
	for furniture in furniture_bounds:
		if furniture.intersects(standing_space):
			intersections.append(furniture)
	return intersections
