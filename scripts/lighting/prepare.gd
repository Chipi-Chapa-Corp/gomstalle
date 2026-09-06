extends SceneTree

const TEXEL_SIZE: float = 0.2

var _meshes: Dictionary[String, ArrayMesh] = {}
var _static_scene: Node3D
var _mesh_count: int = 0

func _initialize() -> void:
	_prepare.call_deferred()

func _prepare() -> void:
	OS.set_environment("GOMSTALLE_LIGHTING_MODE", "source")
	var scene_path := OS.get_environment("GOMSTALLE_LIGHTMAP_SCENE")
	assert(not scene_path.is_empty(), "GOMSTALLE_LIGHTMAP_SCENE must identify the output static scene.")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scene_path.get_base_dir()))
	var source: Node3D = load("res://scenes/world/scene.tscn").instantiate()
	source.set_script(null)
	for child in source.get_children():
		if child.name not in [&"GridMap", &"CastleDressing", &"Light", &"WorldEnvironment"]:
			child.free()
	root.add_child(source)
	await process_frame
	_static_scene = source.get_node("CastleDressing")
	_static_scene.set_meta("furniture_bounds", _static_scene.get_furniture_bounds())
	_static_scene.set_script(null)
	_static_scene.reparent(root)
	_static_scene.name = "StaticCastle"
	var grid: GridMap = source.get_node("GridMap")
	var architecture: GridMap = grid.duplicate()
	architecture.name = "Architecture"
	architecture.collision_layer = 0
	architecture.collision_mask = 0
	architecture.mesh_library = grid.mesh_library.duplicate()
	for item_id in architecture.mesh_library.get_item_list():
		architecture.mesh_library.set_item_shapes(item_id, [])
	_static_scene.add_child(architecture)
	var floor_root := Node3D.new()
	floor_root.name = "Floors"
	_static_scene.add_child(floor_root)
	for cell in grid.get_used_cells():
		var item_id := grid.get_cell_item(cell)
		if not grid.mesh_library.get_item_name(item_id).begins_with("floor_"):
			continue
		architecture.set_cell_item(cell, -1)
		var cell_basis := grid.get_basis_with_orthogonal_index(grid.get_cell_item_orientation(cell))
		var cell_transform := Transform3D(cell_basis, grid.map_to_local(cell)) * grid.mesh_library.get_item_mesh_transform(item_id)
		var floor_instance := MeshInstance3D.new()
		floor_instance.name = "Floor_%d_%d_%d" % [cell.x, cell.y, cell.z]
		floor_instance.mesh = grid.mesh_library.get_item_mesh(item_id)
		floor_instance.transform = grid.transform * cell_transform
		floor_root.add_child(floor_instance)
	print("LIGHTMAP_PREPARE floors=", floor_root.get_child_count())
	architecture.make_baked_meshes(true, TEXEL_SIZE)
	_prepare_visuals(_static_scene)
	for original in source.get_node("Light").get_children():
		original.reparent(_static_scene)
	for light in _static_scene.find_children("*", "Light3D", true, false):
		light.light_bake_mode = Light3D.BAKE_DYNAMIC if light is DirectionalLight3D else Light3D.BAKE_STATIC
		light.distance_fade_enabled = false
		light.shadow_enabled = light is DirectionalLight3D
	var environment: WorldEnvironment = source.get_node("WorldEnvironment")
	environment.reparent(_static_scene)
	var lightmap := LightmapGI.new()
	lightmap.name = "LightmapGI"
	var quality := OS.get_environment("GOMSTALLE_LIGHTMAP_QUALITY")
	lightmap.quality = {"low": LightmapGI.BAKE_QUALITY_LOW, "medium": LightmapGI.BAKE_QUALITY_MEDIUM,
		"high": LightmapGI.BAKE_QUALITY_HIGH}.get(quality, LightmapGI.BAKE_QUALITY_MEDIUM)
	lightmap.bounces = 3
	lightmap.interior = true
	lightmap.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	lightmap.environment_custom_color = Color(0.35, 0.45, 0.65)
	lightmap.environment_custom_energy = 0.18
	lightmap.max_texture_size = 2048
	lightmap.light_data = LightmapGIData.new()
	var save_error := ResourceSaver.save(lightmap.light_data, scene_path.get_basename() + ".lmbake")
	assert(save_error == OK, "Lightmap data could not be prepared.")
	lightmap.light_data = ResourceLoader.load(scene_path.get_basename() + ".lmbake", "LightmapGIData", ResourceLoader.CACHE_MODE_REPLACE)
	assert(lightmap.light_data.get_user_count() == 0, "Prepared lightmap data must not reuse a previous bake.")
	_static_scene.add_child(lightmap)
	_assign_owners(_static_scene)
	var packed := PackedScene.new()
	assert(packed.pack(_static_scene) == OK, "Static castle could not be packed.")
	assert(ResourceSaver.save(packed, scene_path) == OK, "Static castle could not be saved.")
	print("LIGHTMAP_PREPARE_COMPLETE meshes=", _mesh_count, " file=", scene_path)
	source.queue_free()
	_static_scene.queue_free()
	await process_frame
	quit()

func _prepare_visuals(node: Node) -> void:
	if node is RigidBody3D or node is AnimatableBody3D:
		for visual in node.find_children("*", "GeometryInstance3D", true, false):
			visual.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		return
	if node is MeshInstance3D and node.mesh != null:
		node.mesh = _lightmap_mesh(node.mesh, node.global_basis.get_scale())
		node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		_mesh_count += 1
	elif node is MultiMeshInstance3D:
		var merged := ArrayMesh.new()
		for surface in node.multimesh.mesh.get_surface_count():
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for instance_index in node.multimesh.instance_count:
				builder.append_from(node.multimesh.mesh, surface, node.multimesh.get_instance_transform(instance_index))
			builder.set_material(node.multimesh.mesh.surface_get_material(surface))
			builder.commit(merged)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = _lightmap_mesh(merged, node.global_basis.get_scale())
		mesh_instance.transform = node.transform
		mesh_instance.visibility_range_end = node.visibility_range_end
		mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		var parent := node.get_parent()
		var node_name: StringName = node.name
		parent.remove_child(node)
		node.free()
		mesh_instance.name = node_name
		parent.add_child(mesh_instance)
		_mesh_count += 1
		return
	for child in node.get_children():
		_prepare_visuals(child)

func _assign_owners(node: Node) -> void:
	for child in node.get_children():
		child.scene_file_path = ""
		child.owner = _static_scene
		_assign_owners(child)

func _lightmap_mesh(source: Mesh, scale_value: Vector3) -> ArrayMesh:
	if source is ArrayMesh and source.get_lightmap_size_hint() != Vector2i.ZERO:
		return source
	var key := "%d:%s" % [source.get_instance_id(), scale_value]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	var unwrap_error := mesh.lightmap_unwrap(Transform3D(Basis.from_scale(scale_value), Vector3.ZERO), TEXEL_SIZE)
	assert(unwrap_error == OK, "Static mesh UV2 generation failed: %s" % source.resource_path)
	_meshes[key] = mesh
	return mesh
