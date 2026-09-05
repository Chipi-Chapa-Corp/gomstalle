extends GutTest

var dressing: CastleDressing

func before_all() -> void:
	dressing = CastleDressing.new()
	add_child(dressing)

func after_all() -> void:
	dressing.free()

func test_scriptorium_connects_library_arrival_and_gallery() -> void:
	for horizontal in range(-34, -11, 2):
		_assert_clear(Vector3(horizontal, 0, 12))
	for depth in range(4, 13, 2):
		_assert_clear(Vector3(-25, 0, depth))
	for depth in range(12, 21, 2):
		_assert_clear(Vector3(-18, 0, depth))
	_assert_clear(Vector3(-34, 0, 18))

func test_archive_reading_island_has_two_routes() -> void:
	for horizontal in [-16.3, -11.7]:
		for depth in range(72, 81, 2):
			_assert_clear(Vector3(horizontal, 0, depth))
	for depth in [82, 84]:
		for horizontal in range(-19, -8, 2):
			_assert_clear(Vector3(horizontal, 0, depth))
	_assert_clear(Vector3(-18, 0, 70))

func test_observatory_reaches_stairs_and_upper_shrine() -> void:
	for horizontal in range(-7, 11, 2):
		_assert_clear(Vector3(horizontal, 0, 82))
	for depth in range(69, 82, 2):
		_assert_clear(Vector3(5, 0, depth))
	for depth in range(85, 92, 2):
		_assert_clear(Vector3(10, 4, depth))
	_assert_clear(Vector3(11, 4, 91))

func _assert_clear(position_value: Vector3) -> void:
	var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), position_value)
	assert_true(blockers.is_empty(), "Scholar route at %s blocked by %s" % [position_value, blockers])
