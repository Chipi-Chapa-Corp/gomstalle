extends GutTest

var dressing: CastleDressing

func before_all() -> void:
	dressing = CastleDressing.new()
	add_child(dressing)

func after_all() -> void:
	dressing.free()

func test_treasury_uses_clean_stone_at_its_original_floor_elevation() -> void:
	var world := preload("res://scenes/world/scene.tscn").instantiate()
	var grid: GridMap = world.get_node("GridMap")
	var floor_count := 0
	for cell in grid.get_used_cells():
		var position_value := grid.map_to_local(cell) + grid.position
		var item_name := grid.mesh_library.get_item_name(grid.get_cell_item(cell))
		if item_name.begins_with("floor") and position_value.x > 36 and position_value.x < 48 and position_value.z > 44 and position_value.z < 68:
			assert_eq(item_name, "floor_tile_large")
			assert_eq(position_value.y, 0.0)
			floor_count += 1
	assert_eq(floor_count, 18, "Treasury retains its complete existing floor coverage")
	world.free()

func test_treasury_entrance_connects_to_the_shrine() -> void:
	for horizontal in [37.8, 39.5, 42, 44, 46]:
		_assert_clear(Vector3(horizontal, 0, 58), "Treasury entrance cross aisle")
	for depth in [47, 48.3, 49.6, 51, 52.4, 54, 56]:
		_assert_clear(Vector3(42, 0, depth), "Treasury central shrine route")
	for position_value in [Vector3(38.8, 0, 47.5), Vector3(45.4, 0, 47.5)]:
		_assert_clear(position_value, "Strongbox access")

func test_counting_counter_preserves_a_complete_circulation_loop() -> void:
	for horizontal in [38, 46]:
		for depth in [60.0, 62.1, 64.1, 65.3]:
			_assert_clear(Vector3(horizontal, 0, depth), "Counter end route")
	for horizontal in range(38, 47, 2):
		for depth in [59.6, 65.3]:
			_assert_clear(Vector3(horizontal, 0, depth), "Counter front and rear route")

func test_security_grilles_have_collision_while_the_gate_stays_open() -> void:
	assert_false(CastleClearance.blockers(dressing.get_furniture_bounds(), Vector3(38.5, 0, 51)).is_empty(), "Fixed grille excludes a standing actor")
	_assert_clear(Vector3(42, 0, 51), "Open strongroom gate")

func _assert_clear(position_value: Vector3, context: String) -> void:
	var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), position_value)
	assert_true(blockers.is_empty(), "%s at %s intersects %s" % [context, position_value, blockers])
