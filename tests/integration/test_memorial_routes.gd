extends GutTest

class MemorialDressing extends CastleDressing:
	func _ready() -> void:
		_build_chapel()
		_build_crypt()
		_build_ossuary()

func test_memorial_rooms_keep_entrances_and_working_aisles_clear() -> void:
	var dressing := MemorialDressing.new()
	add_child_autofree(dressing)
	var positions: Array[Vector3] = []
	for depth in range(32, 45, 2):
		positions.append(Vector3(-6, 0, depth))
	for depth in range(44, 58, 2):
		positions.append(Vector3(-16, 0, depth))
	for horizontal in range(-28, -11, 2):
		positions.append(Vector3(horizontal, 0, 58))
	for depth in range(58, 85, 2):
		positions.append(Vector3(-26, 0, depth))
	for horizontal in range(-26, -19, 2):
		positions.append(Vector3(horizontal, 0, 84))
	for position_value in positions:
		var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), position_value)
		assert_true(blockers.is_empty(), "Memorial route at %s is blocked by %s" % [position_value, blockers])
