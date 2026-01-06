extends GutTest

const WorldPortalUtils = preload("res://scenes/world/portal.gd")

var _created_nodes: Array[Node] = []

func after_each() -> void:
	for node in _created_nodes:
		if is_instance_valid(node):
			node.free()
	_created_nodes.clear()

func test_select_portal_candidate_index_with_empty_players() -> void:
	var world := Node3D.new()
	_created_nodes.append(world)
	var portal_utils := WorldPortalUtils.new(world)
	_created_nodes.append(portal_utils)
	var candidates: Array[WorldPortalUtils.PortalCandidate] = [
		WorldPortalUtils.PortalCandidate.new(Vector3i.ZERO, 0, Vector3.ZERO),
		WorldPortalUtils.PortalCandidate.new(Vector3i.ONE, 1, Vector3.ONE)
	]
	var result := portal_utils._find_candidate_index_farthest_from_players(candidates, [])
	assert_eq(result, 0, "Empty player list should pick first candidate")

func test_select_portal_candidate_index_farthest_from_players() -> void:
	var world := Node3D.new()
	_created_nodes.append(world)
	var portal_utils := WorldPortalUtils.new(world)
	_created_nodes.append(portal_utils)
	var candidates: Array[WorldPortalUtils.PortalCandidate] = [
		WorldPortalUtils.PortalCandidate.new(Vector3i.ZERO, 0, Vector3.ZERO),
		WorldPortalUtils.PortalCandidate.new(Vector3i.ONE, 1, Vector3(10.0, 0.0, 0.0)),
		WorldPortalUtils.PortalCandidate.new(Vector3i(2, 0, 0), 2, Vector3(20.0, 0.0, 0.0))
	]
	var players: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(18.0, 0.0, 0.0)
	]
	var result := portal_utils._find_candidate_index_farthest_from_players(candidates, players)
	assert_eq(result, 1, "Should pick candidate with the greatest nearest-player distance")
