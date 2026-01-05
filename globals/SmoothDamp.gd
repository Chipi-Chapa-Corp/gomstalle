extends Node
class_name SmoothDamp

const MIN_DAMPING_TIME_CONSTANT: float = 0.0001
const MAX_PROGRESS_FRACTION: float = 0.9999
const SOLVER_MAX_NORMALIZED_TIME: float = 32.0
const SOLVER_ITERATIONS: int = 24
const EXP_DECAY_APPROX_DENOMINATOR_CONSTANT: float = 1.0
const EXP_DECAY_APPROX_DENOMINATOR_LINEAR: float = 1.0
const EXP_DECAY_APPROX_DENOMINATOR_QUADRATIC: float = 0.48
const EXP_DECAY_APPROX_DENOMINATOR_CUBIC: float = 0.235

class SmoothDampVector3Step:
	var value: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var blend_factor: float = 0.0

## Returns the damping time constant for smooth camera damping, so that camera reaches `progress_fraction` of the offset within `duration`
static func damping_time_constant_for_progress_fraction(duration: float, progress_fraction: float = 0.95) -> float:
	var clamped_duration = maxf(duration, 0.0)
	if clamped_duration == 0.0:
		return 0.0
	var clamped_progress_fraction = clampf(progress_fraction, 0.0, MAX_PROGRESS_FRACTION)
	var remaining_fraction = 1.0 - clamped_progress_fraction
	if remaining_fraction <= 0.0:
		return 0.0
	var normalized_time = _solve_normalized_time_for_remaining_fraction(remaining_fraction)
	if normalized_time <= 0.0:
		return 0.0
	return 2.0 * clamped_duration / normalized_time

static func smooth_damp_vector3_step(current: Vector3, target: Vector3, velocity: Vector3, damping_time_constant: float, delta: float) -> SmoothDampVector3Step:
	var omega: float = _damping_omega(damping_time_constant)
	var damping_factor: float = _exp_decay_cubic_approx(omega * delta)
	var change: Vector3 = current - target
	var temp: Vector3 = (velocity + omega * change) * delta
	var new_velocity: Vector3 = (velocity - omega * temp) * damping_factor
	var new_value: Vector3 = target + (change + temp) * damping_factor
	var step = SmoothDampVector3Step.new()
	step.value = new_value
	step.velocity = new_velocity
	step.blend_factor = 1.0 - damping_factor
	return step

static func _damping_omega(damping_time_constant: float) -> float:
	var clamped_damping_time_constant: float = maxf(damping_time_constant, MIN_DAMPING_TIME_CONSTANT)
	return 2.0 / clamped_damping_time_constant

static func _exp_decay_cubic_approx(value: float) -> float:
	return EXP_DECAY_APPROX_DENOMINATOR_CONSTANT / (EXP_DECAY_APPROX_DENOMINATOR_CONSTANT + EXP_DECAY_APPROX_DENOMINATOR_LINEAR * value + EXP_DECAY_APPROX_DENOMINATOR_QUADRATIC * value * value + EXP_DECAY_APPROX_DENOMINATOR_CUBIC * value * value * value)

static func _solve_normalized_time_for_remaining_fraction(remaining_fraction: float) -> float:
	var low = 0.0
	var high = SOLVER_MAX_NORMALIZED_TIME
	for _step in range(SOLVER_ITERATIONS):
		var mid = (low + high) * 0.5
		var value = (1.0 + mid) * _exp_decay_cubic_approx(mid)
		if value > remaining_fraction:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5
