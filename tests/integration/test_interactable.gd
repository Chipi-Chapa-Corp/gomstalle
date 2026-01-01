extends GutTest

const TestInteractableScript = preload("res://tests/helpers/test_interactable.gd")

func _make_interactable() -> Node:
	var node := StaticBody3D.new()
	node.set_script(TestInteractableScript)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.material = StandardMaterial3D.new()
	mesh_instance.mesh = mesh

	node.mesh_instance = mesh_instance
	node.add_child(mesh_instance)
	add_child(node)

	return node

func test_outline_toggle() -> void:
	var node := _make_interactable()
	node.call("init_outline")

	var local_outline := node.get("local_outline")
	var local_material := node.get("local_material")
	assert_not_null(local_outline, "Outline material should be created")
	assert_not_null(local_material, "Base material should be duplicated")

	node.call("set_show_outline", true)
	assert_eq(local_material.next_pass, local_outline, "Outline should be enabled")

	node.call("set_show_outline", false)
	assert_eq(local_material.next_pass, null, "Outline should be disabled")

	node.queue_free()
