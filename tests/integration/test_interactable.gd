extends GutTest

const TestInteractableScript = preload("res://tests/helpers/test_interactable.gd")
const TestInteractableNullScript = preload("res://tests/helpers/test_interactable_null.gd")

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

func test_notice_toggles_outline() -> void:
	var node := _make_interactable()
	node.call("init_outline")

	node.call("notice", true)
	var local_material := node.get("local_material")
	var local_outline := node.get("local_outline")
	assert_eq(local_material.next_pass, local_outline, "Notice should enable outline")

	node.call("notice", false)
	assert_eq(local_material.next_pass, null, "Notice should disable outline")

	node.queue_free()

func test_default_is_static() -> void:
	var node := _make_interactable()
	assert_true(node.call("get_is_static"), "Interactable should be static by default")
	node.queue_free()

func test_outline_no_target_is_safe() -> void:
	var node := StaticBody3D.new()
	node.set_script(TestInteractableNullScript)
	add_child(node)

	node.call("init_outline")

	assert_eq(node.get("local_outline"), null, "No target means no outline material")
	assert_eq(node.get("local_material"), null, "No target means no base material")

	node.call("set_show_outline", true)
	assert_eq(node.get("local_material"), null, "No target should keep materials unset")

	node.queue_free()
