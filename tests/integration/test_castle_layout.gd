extends GutTest

var dressing: CastleDressing

func before_all() -> void:
	dressing = CastleDressing.new()
	add_child(dressing)

func after_all() -> void:
	dressing.free()

func test_shrine_interaction_spaces_remain_clear() -> void:
	var shrines: Array[Vector3] = [Vector3(-34, 0, 18), Vector3(5, 0, 23), Vector3(-18, 0, 70), Vector3(11, 4, 91), Vector3(42, 0, 47), Vector3(46, 0, 14)]
	for shrine in shrines:
		_assert_clear(shrine, "Shrine at %s" % shrine)

func test_portal_and_arrival_spawn_remain_clear() -> void:
	var portal_space := AABB(Vector3(-2, 0.1, -2), Vector3(4, 2, 4))
	var blocked := false
	for furniture in dressing.get_furniture_bounds():
		blocked = blocked or furniture.intersects(portal_space)
	assert_false(blocked, "Arrival portal needs its full opening and spawn clearance")

func test_door_approaches_preserve_player_width() -> void:
	var east_west_doors: Array[Vector3] = [Vector3(-12, 0, 12), Vector3(-24, 0, 26), Vector3(-12, 0, 58), Vector3(-20, 0, 84), Vector3(-8, 0, 82), Vector3(36, 0, 58), Vector3(28, 0, 6)]
	var north_south_doors: Array[Vector3] = [Vector3(-18, 0, 20), Vector3(-16, 0, 44), Vector3(-26, 0, 68), Vector3(2, 0, 68), Vector3(22, 0, 44), Vector3(18, 0, 32), Vector3(18, 0, 20), Vector3(34, 0, 0)]
	for doorway in east_west_doors:
		for side in [-1.8, 1.8]:
			_assert_clear(doorway + Vector3(side, 0, 0), "Doorway approach at %s" % doorway)
	for doorway in north_south_doors:
		for side in [-1.8, 1.8]:
			_assert_clear(doorway + Vector3(0, 0, side), "Doorway approach at %s" % doorway)

func test_stair_run_and_mezzanine_arrival_remain_clear() -> void:
	for step_index in 10:
		var depth: float = 79.5 + step_index * 0.5
		var elevation: float = clampf(depth - 79.6, 0, 4.05)
		_assert_clear(Vector3(10, elevation, depth), "Existing observatory staircase at %s" % depth)

func test_room_names_cover_corridor_turn_and_upper_floor() -> void:
	assert_eq(CastleDressing.get_room_name(Vector3(-18, 0, 38)), "The Portrait Gallery")
	assert_eq(CastleDressing.get_room_name(Vector3(6, 4, 88)), "The Astronomer's Tower")
	assert_eq(CastleDressing.get_room_name(Vector3(70, 0, 20)), "Castle Grounds")

func _assert_clear(position_value: Vector3, context: String) -> void:
	var standing_space := AABB(position_value + Vector3(-0.55, 0.1, -0.55), Vector3(1.1, 1.9, 1.1))
	var blockers: Array[AABB] = []
	for furniture in dressing.get_furniture_bounds():
		if furniture.intersects(standing_space):
			blockers.append(furniture)
	assert_true(blockers.is_empty(), "%s intersects furniture %s" % [context, blockers])
