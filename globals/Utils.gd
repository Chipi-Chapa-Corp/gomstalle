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

func smooth_time_for_progress(duration: float, progress: float) -> float:
	var clamped_duration = maxf(duration, 0.0)
	if clamped_duration == 0.0:
		return 0.0
	var clamped_progress = clampf(progress, 0.0, 0.9999)
	var remaining_fraction = 1.0 - clamped_progress
	if remaining_fraction <= 0.0:
		return 0.0
	var u = _solve_damping_for_remaining_fraction(remaining_fraction)
	if u <= 0.0:
		return 0.0
	return 2.0 * clamped_duration / u

func _solve_damping_for_remaining_fraction(remaining_fraction: float) -> float:
	var low = 0.0
	var high = 32.0
	for _step in range(24):
		var mid = (low + high) * 0.5
		var value = (1.0 + mid) * exp_cubic_approx(mid)
		if value > remaining_fraction:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5

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

func select_farthest_candidate_index(candidates: Array[Vector3], points: Array[Vector3]) -> int:
	if candidates.is_empty():
		return -1
	if points.is_empty():
		return 0
	var best_index := 0
	var best_score := -INF
	for index in candidates.size():
		var candidate: Vector3 = candidates[index]
		var min_distance := INF
		for point in points:
			var distance := candidate.distance_to(point)
			if distance < min_distance:
				min_distance = distance
		if min_distance > best_score:
			best_score = min_distance
			best_index = index
	return best_index
