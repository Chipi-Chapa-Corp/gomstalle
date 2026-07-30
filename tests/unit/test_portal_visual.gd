extends GutTest

const PORTAL_SCENE := preload("res://scenes/portal/scene.tscn")

func test_portal_fits_the_opened_floor_tile() -> void:
	var portal: EscapePortal = PORTAL_SCENE.instantiate()
	add_child_autofree(portal)
	await get_tree().process_frame
	portal.fit_to_size(1.75)
	assert_eq(portal.visuals.scale, Vector3.ONE * 1.75)

func test_portal_open_reveals_the_effect() -> void:
	var portal: EscapePortal = PORTAL_SCENE.instantiate()
	add_child_autofree(portal)
	await get_tree().process_frame
	assert_false(portal.steady_particles.emitting)
	assert_eq(portal.portal_light.light_energy, 0.0)
	await portal.open(0.01)
	var portal_material := portal.portal_surface.material_override as ShaderMaterial
	assert_true(portal.steady_particles.emitting)
	assert_eq(portal_material.get_shader_parameter("reveal_progress"), 1.0)
