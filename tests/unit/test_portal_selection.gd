extends GutTest

const WorldScript = preload("res://scenes/world/script.gd")

var _created_nodes: Array[Node] = []

func after_each() -> void:
	for node in _created_nodes:
		if is_instance_valid(node):
			node.free()
	_created_nodes.clear()

func test_select_portal_candidate_index_with_empty_players() -> void:
	var world := WorldScript.new()
	_created_nodes.append(world)
	var candidates: Array[WorldScript.PortalCandidate] = [
		WorldScript.PortalCandidate.new(Vector3i.ZERO, 0, Vector3.ZERO),
		WorldScript.PortalCandidate.new(Vector3i.ONE, 1, Vector3.ONE)
	]
	var result := world._find_candidate_index_farthest_from_players(candidates, [])
	assert_eq(result, 0, "Empty player list should pick first candidate")

func test_select_portal_candidate_index_farthest_from_players() -> void:
	var world := WorldScript.new()
	_created_nodes.append(world)
	var candidates: Array[WorldScript.PortalCandidate] = [
		WorldScript.PortalCandidate.new(Vector3i.ZERO, 0, Vector3.ZERO),
		WorldScript.PortalCandidate.new(Vector3i.ONE, 1, Vector3(10.0, 0.0, 0.0)),
		WorldScript.PortalCandidate.new(Vector3i(2, 0, 0), 2, Vector3(20.0, 0.0, 0.0))
	]
	var players: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(18.0, 0.0, 0.0)
	]
	var result := world._find_candidate_index_farthest_from_players(candidates, players)
	assert_eq(result, 1, "Should pick candidate with the greatest nearest-player distance")
