extends Node

func resolve_node(value):
	if value is NodePath:
		return get_node_or_null(value)
	if value is EncodedObjectAsID:
		return instance_from_id(value.object_id)
	if value is Node:
		return value
	return null

const EXP_APPROX_CONSTANT_COEFF: float = 1.0
const EXP_APPROX_LINEAR_COEFF: float = 1.0
const EXP_APPROX_QUADRATIC_COEFF: float = 0.48
const EXP_APPROX_CUBIC_COEFF: float = 0.235

func exp_cubic_approx(value: float) -> float:
	return EXP_APPROX_CONSTANT_COEFF / (EXP_APPROX_CONSTANT_COEFF + EXP_APPROX_LINEAR_COEFF * value + EXP_APPROX_QUADRATIC_COEFF * value * value + EXP_APPROX_CUBIC_COEFF * value * value * value)

func smooth_damp_vector3(current: Vector3, target: Vector3, velocity: Vector3, smooth_time: float, delta: float) -> Array[Vector3]:
	var clamped_smooth_time: float = maxf(smooth_time, 0.0001)
	var omega: float = 2.0 / clamped_smooth_time
	var scaled_time: float = omega * delta
	var damping_factor: float = exp_cubic_approx(scaled_time)
	var change: Vector3 = current - target
	var temp: Vector3 = (velocity + omega * change) * delta
	var new_velocity: Vector3 = (velocity - omega * temp) * damping_factor
	var new_value: Vector3 = target + (change + temp) * damping_factor
	return [new_value, new_velocity]
