extends GutTest

var _created_nodes: Array[Node] = []

func after_each() -> void:
	for node in _created_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_created_nodes.clear()

func test_resolve_node_with_nodepath() -> void:
	var node := Node.new()
	node.name = "Target"
	Utils.add_child(node)
	_created_nodes.append(node)

	var resolved = Utils.resolve_node(NodePath("Target"))
	assert_eq(resolved, node, "NodePath should resolve to child of Utils")

func test_resolve_node_with_encoded_object() -> void:
	var node := Node.new()
	Utils.add_child(node)
	_created_nodes.append(node)

	var encoded := EncodedObjectAsID.new()
	encoded.object_id = node.get_instance_id()

	var resolved = Utils.resolve_node(encoded)
	assert_eq(resolved, node, "EncodedObjectAsID should resolve to instance")

func test_resolve_node_with_node() -> void:
	var node := Node.new()
	_created_nodes.append(node)

	var resolved = Utils.resolve_node(node)
	assert_eq(resolved, node, "Node instance should return itself")

func test_resolve_node_with_missing_nodepath() -> void:
	var resolved = Utils.resolve_node(NodePath("Missing"))
	assert_eq(resolved, null, "Missing NodePath should resolve to null")

func test_resolve_node_with_unknown_type() -> void:
	var resolved = Utils.resolve_node(123)
	assert_eq(resolved, null, "Unknown type should resolve to null")

func test_smooth_damp_vector3_with_zero_delta() -> void:
	var current := Vector3(1.0, 2.0, 3.0)
	var target := Vector3(4.0, 5.0, 6.0)
	var velocity := Vector3(0.5, 0.25, 0.75)
	var result: Array[Vector3] = Utils.smooth_damp_vector3(current, target, velocity, 0.1, 0.0)
	assert_eq(result[0], current, "Zero delta should keep position")
	assert_eq(result[1], velocity, "Zero delta should keep velocity")

func test_smooth_damp_vector3_moves_towards_target() -> void:
	var current := Vector3.ZERO
	var target := Vector3(10.0, 0.0, 0.0)
	var velocity := Vector3.ZERO
	var result: Array[Vector3] = Utils.smooth_damp_vector3(current, target, velocity, 0.1, 0.1)
	var new_position: Vector3 = result[0]
	var new_velocity: Vector3 = result[1]
	assert_true(new_position.x > current.x, "Position should move towards target")
	assert_true(new_position.x < target.x, "Position should not overshoot target")
	assert_true(new_velocity.x > 0.0, "Velocity should move towards target")

func test_smooth_time_for_progress_matches_remaining_fraction() -> void:
	var duration := 2.5
	var progress := 0.95
	var smooth_time = Utils.smooth_time_for_progress(duration, progress)
	assert_true(smooth_time > 0.0, "Smooth time should be positive for valid inputs")
	var u = 2.0 * duration / smooth_time
	var remaining = (1.0 + u) * Utils.exp_cubic_approx(u)
	assert_almost_eq(remaining, 1.0 - progress, 0.001, "Remaining fraction should match target")

func test_smooth_time_for_progress_zero_duration() -> void:
	var smooth_time = Utils.smooth_time_for_progress(0.0, 0.95)
	assert_eq(smooth_time, 0.0, "Zero duration should return zero smooth time")

func test_select_farthest_candidate_index_with_empty_candidates() -> void:
	var result := Utils.select_farthest_candidate_index([], [Vector3.ZERO])
	assert_eq(result, -1, "Empty candidates should return -1")

func test_select_farthest_candidate_index_with_empty_points() -> void:
	var result := Utils.select_farthest_candidate_index([Vector3.ZERO, Vector3.ONE], [])
	assert_eq(result, 0, "Empty points should pick first candidate")

func test_select_farthest_candidate_index_maximizes_min_distance() -> void:
	var candidates: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(10.0, 0.0, 0.0),
		Vector3(20.0, 0.0, 0.0)
	]
	var points: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(18.0, 0.0, 0.0)
	]
	var result := Utils.select_farthest_candidate_index(candidates, points)
	assert_eq(result, 1, "Should pick candidate with largest minimal distance")
