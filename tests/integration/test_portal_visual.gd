extends GutTest

const PortalScene := preload("res://scenes/portal/scene.tscn")

func test_portal_surround_supports_tile_corners_and_keeps_center_open() -> void:
	var portal: PortalVisual = PortalScene.instantiate()
	add_child_autofree(portal)
	portal.set_diameter(4.2)
	await get_tree().physics_frame
	var space := portal.get_world_3d().direct_space_state
	var corner := PhysicsRayQueryParameters3D.create(Vector3(1.95, 2, 1.95), Vector3(1.95, -2, 1.95), 1)
	var center := PhysicsRayQueryParameters3D.create(Vector3(0, 2, 0), Vector3(0, -2, 0), 1)
	assert_false(space.intersect_ray(corner).is_empty(), "The stone surround must replace the removed tile corners")
	assert_true(space.intersect_ray(center).is_empty(), "The escape aperture must remain open")

func test_portal_diameter_scales_surface_frame_and_light_together() -> void:
	var portal: PortalVisual = PortalScene.instantiate()
	add_child_autofree(portal)
	portal.set_diameter(4.2)
	var surface: MeshInstance3D = portal.get_node("PortalSurface")
	assert_almost_eq(surface.global_basis.get_scale().x, 4.2, 0.001)
	assert_almost_eq(portal.outer_ring.global_basis.get_scale().x, 4.2, 0.001)
	assert_almost_eq(portal.light.global_position.y, 0.756, 0.001)

func test_separate_portals_do_not_share_opening_animation() -> void:
	var first: PortalVisual = PortalScene.instantiate()
	var second: PortalVisual = PortalScene.instantiate()
	add_child_autofree(first)
	add_child_autofree(second)
	first.set_process(false)
	second.set_process(false)
	first._process(2.0)
	second._process(0.2)
	assert_ne(first.surface_material, second.surface_material)
	assert_eq(first.surface_material.get_shader_parameter("opening"), 1.0)
	assert_lt(second.surface_material.get_shader_parameter("opening"), 0.1)
	second.hide()
	second._process(10.0)
	assert_almost_eq(second.age, 0.2, 0.001)
	second.show()
	assert_eq(second.age, 0.0)
