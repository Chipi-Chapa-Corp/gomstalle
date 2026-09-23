extends GutTest

class ChapelDressing extends CastleDressing:
	func _ready() -> void:
		var room := _room(9, AMBER)
		_assembly(room, "res://assets/castle/chapel_v2/candle_chapel.glb", "SanctuaryOfTheLastWatch")

func test_chapel_v2_keeps_processional_route_and_altar_approach_clear() -> void:
	var dressing := ChapelDressing.new()
	add_child_autofree(dressing)
	assert_eq(dressing.get_furniture_bounds().size(), 7, "The authored chapel collision shapes were imported.")
	for depth in range(32, 45):
		var position_value := Vector3(-6, 0, depth)
		var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), position_value)
		assert_true(blockers.is_empty(), "Processional route at %s is blocked by %s" % [position_value, blockers])
	for depth in range(37, 43):
		var position_value := Vector3(3.5, 0, depth)
		var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), position_value)
		assert_true(blockers.is_empty(), "Altar approach at %s is blocked by %s" % [position_value, blockers])
