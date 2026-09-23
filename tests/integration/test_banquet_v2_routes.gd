extends GutTest

var banquet_world: Node3D
var dressing: CastleDressing

func before_all() -> void:
	var castle: Node3D = load("res://scenes/world/scene.tscn").instantiate()
	var grid: GridMap = castle.get_node("GridMap")
	castle.remove_child(grid)
	castle.free()
	banquet_world = Node3D.new()
	banquet_world.add_child(grid)
	dressing = CastleDressing.new()
	banquet_world.add_child(dressing)
	add_child(banquet_world)
	await get_tree().physics_frame
	await get_tree().physics_frame

func after_all() -> void:
	banquet_world.free()

func test_kitchen_hatch_exit_and_south_aisle_stay_clear() -> void:
	for horizontal in [37.6, 38.0, 38.4, 39.0, 40.0]:
		for depth in [29.8, 30.3, 30.7]:
			_assert_clear(Vector3(horizontal, 0.1, depth))

func test_gap_between_feast_tables_stays_open() -> void:
	for depth in [22.7, 24.0, 25.5, 27.0, 28.5, 30.0]:
		_assert_clear(Vector3(30, 0.1, depth))

func test_approach_to_royal_dais_stays_open() -> void:
	for depth in [23.0, 24.5, 26.0, 27.5, 29.0, 30.0]:
		_assert_clear(Vector3(40.8, 0.1, depth))

func _assert_clear(location: Vector3) -> void:
	var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), location)
	assert_true(blockers.is_empty(), "Banquet route at %s is blocked by %s" % [location, blockers])
