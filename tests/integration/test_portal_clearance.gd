extends GutTest

class RoundFixture extends RefCounted:
	var navigation: CastleNavigation

class PortalWorld extends Node3D:
	var grid_map: GridMap
	var player_container: Node3D
	var round_utils: RoundFixture

var world: PortalWorld
var portal: WorldPortalUtils

func before_each() -> void:
	world = PortalWorld.new()
	add_child_autofree(world)
	world.grid_map = GridMap.new()
	world.grid_map.cell_size = Vector3(4, 1, 4)
	world.grid_map.cell_center_x = false
	world.grid_map.cell_center_y = false
	world.grid_map.cell_center_z = false
	var library := MeshLibrary.new()
	library.create_item(0)
	library.set_item_name(0, "floor_fixture")
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(4, 0.1, 4)
	library.set_item_mesh(0, floor_mesh)
	var floor_shape := BoxShape3D.new()
	floor_shape.size = floor_mesh.size
	library.set_item_shapes(0, [floor_shape, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, 0))])
	world.grid_map.mesh_library = library
	for column in 4:
		world.grid_map.set_cell_item(Vector3i(column, 0, 0), 0)
	world.add_child(world.grid_map)
	world.player_container = Node3D.new()
	world.add_child(world.player_container)
	world.player_container.add_child(CharacterBody3D.new())
	world.round_utils = RoundFixture.new()
	world.round_utils.navigation = CastleNavigation.new(world)
	for column in 4:
		world.round_utils.navigation.graph.add_point(column, Vector3(column * 4, 0, 0))
		if column > 0:
			world.round_utils.navigation.graph.connect_points(column - 1, column)
	portal = WorldPortalUtils.new(world)
	world.add_child(portal)
	await get_tree().physics_frame
	await get_tree().physics_frame

func test_portal_skips_furniture_covering_the_farthest_tile() -> void:
	assert_eq(portal._select_portal_candidate_farthest_from_players().position, Vector3(12, 0, 0))
	var cabinet := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 1.4, 3)
	collider.shape = shape
	cabinet.add_child(collider)
	cabinet.position = Vector3(12, 0.7, 0)
	world.add_child(cabinet)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(portal._select_portal_candidate_farthest_from_players().position, Vector3(8, 0, 0), "The exit must use the next reachable standing space, not appear inside furniture")

func test_portal_skips_a_clear_but_disconnected_floor() -> void:
	world.round_utils.navigation.graph.disconnect_points(2, 3)
	world.round_utils.navigation._retain_reachable_floor()
	assert_eq(portal._select_portal_candidate_farthest_from_players().position, Vector3(8, 0, 0), "A clear floor outside the reachable castle component cannot become the exit")
