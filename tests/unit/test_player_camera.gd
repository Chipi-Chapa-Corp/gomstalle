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

func test_active_camera_follow_time_uses_override_value() -> void:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.camera_follow_time = 0.2
	player.set_camera_override(Vector3.ZERO, Vector3.RIGHT, 60.0, 2.5)
	assert_eq(player._get_active_camera_follow_time(), 2.5, "Override follow time should be used when active")

func test_active_camera_follow_time_falls_back_to_default() -> void:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.camera_follow_time = 0.3
	player.set_camera_override(Vector3.ZERO, Vector3.RIGHT, 60.0, 0.0)
	assert_eq(player._get_active_camera_follow_time(), 0.3, "Default follow time should be used when override follow time is zero")

func test_active_camera_follow_time_uses_temporary_value() -> void:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.camera_follow_time = 0.25
	player.set_temporary_camera_follow_time(1.0, 0.5)
	assert_eq(player._get_active_camera_follow_time(), 1.0, "Temporary follow time should be used while active")

func test_temporary_camera_follow_time_expires() -> void:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.camera_follow_time = 0.4
	player.set_temporary_camera_follow_time(1.0, 0.5)
	player._advance_temporary_camera_follow_time(0.5)
	assert_eq(player._get_active_camera_follow_time(), 0.4, "Temporary follow time should expire after duration")

func test_portal_arrow_hidden_during_camera_override() -> void:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.portal_arrow = Node2D.new()
	_created_nodes.append(player.portal_arrow)
	player.camera = Camera3D.new()
	_created_nodes.append(player.camera)
	GameState.portal_active = true
	player.set_camera_override(Vector3.ZERO, Vector3.RIGHT, 60.0, 1.0)
	assert_false(player._should_show_portal_arrow(), "Arrow should stay hidden during camera override")
	GameState.portal_active = false

func test_portal_arrow_visible_after_override() -> void:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.portal_arrow = Node2D.new()
	_created_nodes.append(player.portal_arrow)
	player.camera = Camera3D.new()
	_created_nodes.append(player.camera)
	GameState.portal_active = true
	player.camera_override_active = false
	assert_true(player._should_show_portal_arrow(), "Arrow should show after camera override ends")
	GameState.portal_active = false
