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
