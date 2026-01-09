extends Node

func resolve_node(value):
	if value is NodePath:
		return get_node_or_null(value)
	if value is EncodedObjectAsID:
		return instance_from_id(value.object_id)
	if value is Node:
		return value
	return null

func is_wall_item(grid_map: GridMap, item_id: int) -> bool:
	var item_name = grid_map.mesh_library.get_item_name(item_id)
	return item_name.begins_with("wall")

func get_floor_cells(grid_map: GridMap) -> Array[Vector3i]:
	var floor_cells: Array[Vector3i] = []
	assert(grid_map.mesh_library != null)
	var used_cells: Array[Vector3i] = grid_map.get_used_cells()
	for cell in used_cells:
		var item_id := grid_map.get_cell_item(cell)
		if item_id < 0:
			continue
		var item_name: StringName = grid_map.mesh_library.get_item_name(item_id)
		if not String(item_name).begins_with("floor_"):
			continue
		floor_cells.append(cell)
	return floor_cells

func get_wall_adjacent_floor_cells(grid_map: GridMap) -> Array[Vector3i]:
	var wall_adjacent_floor_cells: Array[Vector3i] = []
	var unique_cells: Dictionary = {}
	var wall_xz: Dictionary = {}
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	var used_cells: Array[Vector3i] = grid_map.get_used_cells()
	for wall_cell in used_cells:
		var wall_item_id := grid_map.get_cell_item(wall_cell)
		if wall_item_id < 0:
			continue
		if not is_wall_item(grid_map, wall_item_id):
			continue
		wall_xz[Vector2i(wall_cell.x, wall_cell.z)] = true
	var world = get_tree().current_scene
	if world != null:
		var wall_nodes := world.find_children("wall*", "", true, false)
		for wall_node in wall_nodes:
			if not wall_node is Node3D:
				continue
			var wall_cell := grid_map.local_to_map(grid_map.to_local(wall_node.global_position))
			wall_xz[Vector2i(wall_cell.x, wall_cell.z)] = true
	var floor_cells := get_floor_cells(grid_map)
	for floor_cell in floor_cells:
		var floor_xz := Vector2i(floor_cell.x, floor_cell.z)
		for neighbor_offset in neighbor_offsets:
			if not wall_xz.has(floor_xz + neighbor_offset):
				continue
			if unique_cells.has(floor_cell):
				break
			unique_cells[floor_cell] = true
			wall_adjacent_floor_cells.append(floor_cell)
			break
	return wall_adjacent_floor_cells
