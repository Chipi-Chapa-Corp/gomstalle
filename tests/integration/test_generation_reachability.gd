extends GutTest

class GenerationWorld extends Node3D:
	var grid_map: GridMap

func test_generation_preserves_connected_floors_and_all_shrine_approaches() -> void:
	var world := GenerationWorld.new()
	var source: Node3D = load("res://scenes/world/scene.tscn").instantiate()
	source.set_script(null)
	world.grid_map = source.get_node("GridMap")
	world.grid_map.owner = null
	source.remove_child(world.grid_map)
	world.add_child(world.grid_map)
	var shrines := source.get_node("Shrines")
	shrines.owner = null
	source.remove_child(shrines)
	world.add_child(shrines)
	source.free()
	var dressing := CastleDressing.new()
	dressing.baked_scene = load("res://assets/lighting/castle.scn")
	world.add_child(dressing)
	add_child_autofree(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var navigation := CastleNavigation.new(world)
	navigation.build()
	var generator := preload("res://globals/Generator.gd").new()
	add_child_autofree(generator)
	generator._navigation = navigation
	generator._furniture_bounds = dressing.get_furniture_bounds()
	generator._protected_positions = [GameState.player_spawn_center]
	for shrine: Node3D in shrines.get_children():
		generator._protected_positions.append(shrine.global_position + Vector3.UP)
	var cells: Array[Vector3i] = generator._eligible_floor_cells(world.grid_map)
	for sealed_floor in [Vector3(6, 0, 90), Vector3(10, 0, 86)]:
		var cell := world.grid_map.local_to_map(world.grid_map.to_local(sealed_floor))
		assert_false(cells.has(cell), "The enclosed ground floor below the terrace must never hold fuel")
		assert_true(navigation.can_reach_floor(sealed_floor + Vector3.UP * 4), "Its reachable upper floor must remain available")
	var before_stair_block := navigation.graph.get_point_count()
	assert_false(navigation.try_reserve_obstacle(AABB(Vector3(8.5, 0, 79), Vector3(3, 5, 6)), Vector3(10, 0, 81), 1.8), "An obstacle severing the only staircase must be rejected")
	assert_eq(navigation.graph.get_point_count(), before_stair_block, "Rejected occupancy must restore navigation")
	assert_eq(navigation._reachable_points().size(), before_stair_block)
	var entries: Array[Dictionary] = generator._build_spawn_list(world.grid_map, cells, 94721)
	assert_eq(entries.size(), 40, "The safe placement constraints must still provide the full round's fuel")
	assert_eq(navigation._reachable_points().size(), navigation.graph.get_point_count(), "Accepted piles must leave every remaining floor connected")
	for entry in entries:
		var position: Vector3 = generator._cell_position(world.grid_map, entry["cell"])
		var approach := navigation.graph.get_point_position(navigation.graph.get_closest_point(position))
		assert_lt(approach.distance_to(position), CastleBotController.INTERACTION_DISTANCE, "Every pile must have a reachable interaction position")
		for protected in generator._protected_positions:
			assert_gte(position.distance_to(protected), 3.0, "Fuel must preserve shrine and spawn interaction space")
