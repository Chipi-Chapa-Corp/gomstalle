extends GutTest

const Compass := preload("res://scenes/player/portal_compass.gd")

func test_visible_portal_keeps_marker_above_its_projection() -> void:
	var marker := Compass.place_projection(Vector2(500, 400), Vector2(1280, 800), false)
	assert_true(marker.on_screen)
	assert_eq(marker.position, Vector2(500, 352))

func test_distant_diagonal_portal_stays_inside_readable_screen_border() -> void:
	for viewport in [Vector2(1280, 800), Vector2(1920, 1080), Vector2(1080, 1920)]:
		var marker := Compass.place_projection(Vector2(5000, -2000), viewport, false)
		assert_false(marker.on_screen)
		assert_true(Rect2(Vector2(81, 103), viewport - Vector2(162, 206)).has_point(marker.position))
		assert_gt(marker.direction.x, 0.0)
		assert_lt(marker.direction.y, 0.0)

func test_behind_camera_reverses_projection_without_pointing_across_screen() -> void:
	var marker := Compass.place_projection(Vector2(2000, 400), Vector2(1280, 800), true)
	assert_false(marker.on_screen)
	assert_lt(marker.position.x, 640.0)
	assert_almost_eq(marker.position.y, 400.0, 0.001)

func test_directly_behind_camera_has_finite_marker() -> void:
	var marker := Compass.place_projection(Vector2(640, 400), Vector2(1280, 800), true)
	assert_true(marker.position.is_finite())
	assert_eq(marker.direction, Vector2.DOWN)

func test_marker_and_label_stay_clear_of_clock_and_interaction_prompt() -> void:
	var viewport := Vector2(1440, 900)
	var above := Compass.place_projection(Vector2(720, -500), viewport, false)
	var below := Compass.place_projection(Vector2(720, 1500), viewport, false)
	assert_gt(above.position.y - 35, 107.0, "The complete upper marker must clear the clock panel")
	assert_lt(below.position.y + 72, 788.0, "The lower label must clear the interaction prompt")
	var covered_portal := Compass.place_projection(Vector2(720, 145), viewport, false)
	assert_false(covered_portal.on_screen, "A portal covered by the clock should receive a clear edge marker")
