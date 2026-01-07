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
