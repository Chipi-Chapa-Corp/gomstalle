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
