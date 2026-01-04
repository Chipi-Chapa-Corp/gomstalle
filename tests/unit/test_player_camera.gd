extends GutTest

const PlayerScript = preload("res://scenes/player/script.gd")

var _created_nodes: Array[Node] = []

func after_each() -> void:
	for node in _created_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_created_nodes.clear()

func test_camera_override_offset_uses_override_direction() -> void:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.base_camera_offset = Vector3(10.0, 5.0, 0.0)
	player.camera_override_direction = Vector3(-1.0, 0.0, 0.0)
	var offset: Vector3 = player._get_camera_override_offset()
	assert_eq(offset, Vector3(-10.0, 5.0, 0.0), "Override direction should control camera offset sign")

func test_camera_override_offset_falls_back_to_base_direction() -> void:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.base_camera_offset = Vector3(3.0, 2.0, 4.0)
	player.camera_override_direction = Vector3.ZERO
	var offset: Vector3 = player._get_camera_override_offset()
	assert_eq(offset, Vector3(3.0, 2.0, 4.0), "Zero override direction should keep base camera offset")
