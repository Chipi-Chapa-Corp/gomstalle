extends GutTest

const SmoothDamp = preload("res://globals/SmoothDamp.gd")

func _simulate_progress(duration: float, progress_target: float) -> float:
	var damping_time_constant = SmoothDamp.damping_time_constant_for_progress_fraction(duration, progress_target)
	var current := Vector3.ZERO
	var target := Vector3(10.0, 0.0, 0.0)
	var velocity := Vector3.ZERO
	var elapsed := 0.0
	var step := 1.0 / 60.0
	while elapsed < duration:
		var delta = minf(step, duration - elapsed)
		var result = SmoothDamp.smooth_damp_vector3_step(current, target, velocity, damping_time_constant, delta)
		current = result.value
		velocity = result.velocity
		elapsed += delta
	var initial_distance = target.length()
	if initial_distance <= 0.0:
		return 0.0
	var remaining_distance = target.distance_to(current)
	return 1.0 - remaining_distance / initial_distance

func test_damping_time_constant_for_progress_fraction_scales_with_duration() -> void:
	var short_duration = 1.0
	var long_duration = 2.0
	var progress_target = 0.95
	var short_time = SmoothDamp.damping_time_constant_for_progress_fraction(short_duration, progress_target)
	var long_time = SmoothDamp.damping_time_constant_for_progress_fraction(long_duration, progress_target)
	assert_almost_eq(long_time, short_time * 2.0, 0.0001, "Damping time constant should scale with duration")

func test_damping_time_constant_for_progress_fraction_reaches_target_fraction() -> void:
	var duration = 2.0
	var progress_target = 0.95
	var progress = _simulate_progress(duration, progress_target)
	assert_true(progress >= progress_target - 0.01, "Smooth damp should reach target progress by duration")
