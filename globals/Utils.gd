extends Node

func resolve_node(value):
	if value is NodePath:
		return get_node_or_null(value)
	if value is EncodedObjectAsID:
		return instance_from_id(value.object_id)
	if value is Node:
		return value
	return null

func smooth_damp_vector3(current: Vector3, target: Vector3, velocity: Vector3, smooth_time: float, delta: float) -> Array[Vector3]:
	var clamped_smooth_time: float = maxf(smooth_time, 0.0001)
	var omega: float = 2.0 / clamped_smooth_time
	var x: float = omega * delta
	var exp: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: Vector3 = current - target
	var temp: Vector3 = (velocity + omega * change) * delta
	var new_velocity: Vector3 = (velocity - omega * temp) * exp
	var new_value: Vector3 = target + (change + temp) * exp
	return [new_value, new_velocity]
