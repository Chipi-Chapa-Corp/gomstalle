extends GutTest

var dressing: CastleDressing

func before_all() -> void:
	dressing = CastleDressing.new()
	add_child(dressing)

func after_all() -> void:
	dressing.free()

func test_parlor_connects_all_three_doorways() -> void:
	for position_value in [Vector3(29.8, 0, 6), Vector3(32, 0, 6), Vector3(35, 0, 6), Vector3(38, 0, 6), Vector3(34, 0, 1.8), Vector3(34, 0, 3.2), Vector3(38, 0, 8), Vector3(38, 0, 10.2)]:
		_assert_clear(position_value, "Parlor connecting route")

func test_parlor_conversation_has_two_circulation_loops() -> void:
	for horizontal in [40.2, 46.0]:
		for depth in [3.7, 5.1, 6.4, 7.7, 9.05]:
			_assert_clear(Vector3(horizontal, 0, depth), "Parlor outside seating loop")
	for horizontal in [41.0, 43.0, 45.0]:
		for depth in [5.1, 7.7]:
			_assert_clear(Vector3(horizontal, 0, depth), "Parlor inside tea-service loop")

func test_gallery_preserves_main_aisle_shrine_and_south_turn() -> void:
	for horizontal in range(-22, 12, 2):
		_assert_clear(Vector3(horizontal, 0, 26), "Gallery main aisle")
	for depth in range(28, 42, 2):
		_assert_clear(Vector3(-18, 0, depth), "Gallery south turn")
	for position_value in [Vector3(-18, 0, 21.8), Vector3(-6, 0, 30.2), Vector3(-16, 0, 42.2), Vector3(5, 0, 23)]:
		_assert_clear(position_value, "Gallery doorway or shrine approach")

func _assert_clear(position_value: Vector3, context: String) -> void:
	var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), position_value)
	assert_true(blockers.is_empty(), "%s at %s intersects %s" % [context, position_value, blockers])
