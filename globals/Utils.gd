extends Node

func resolve_node(value):
	if value is NodePath:
		return get_node_or_null(value)
	if value is EncodedObjectAsID:
		return instance_from_id(value.object_id)
	if value is Node:
		return value
	return null

func find_player_in_branch(peer_id: int, multiplayer_api: MultiplayerAPI) -> CharacterBody3D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate = node as CharacterBody3D
		if candidate == null:
			continue
		if candidate.get("peer_id") == peer_id and candidate.get_multiplayer() == multiplayer_api:
			return candidate
	return null

func is_wall_item(grid_map: GridMap, item_id: int) -> bool:
	var item_name = grid_map.mesh_library.get_item_name(item_id)
	return item_name.begins_with("wall")
