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

func test_resolve_node_with_node() -> void:
	var node := Node.new()
	_created_nodes.append(node)

	var resolved = Utils.resolve_node(node)
	assert_eq(resolved, node, "Node instance should return itself")

func test_resolve_node_with_unknown_type() -> void:
	var resolved = Utils.resolve_node(123)
	assert_eq(resolved, null, "Unknown type should resolve to null")
