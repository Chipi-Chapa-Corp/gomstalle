extends GutTest

const PlayerScript = preload("res://scenes/player/script.gd")
const CameraUtils = preload("res://scenes/player/camera.gd")
const PortalIndicatorUtils = preload("res://scenes/player/portal.gd")

var _created_nodes: Array[Node] = []
var _portal_active: bool
var _escaped_peer_ids: Array[int]

func before_each() -> void:
	_portal_active = GameState.portal_active
	_escaped_peer_ids = GameState.escaped_peer_ids.duplicate()
	GameState.portal_active = false
	GameState.escaped_peer_ids.clear()

func after_each() -> void:
	GameState.portal_active = _portal_active
	GameState.escaped_peer_ids = _escaped_peer_ids
	for node in _created_nodes:
		if is_instance_valid(node):
			node.free()
	_created_nodes.clear()

func _create_camera_context() -> Dictionary:
	var player := PlayerScript.new()
	_created_nodes.append(player)
	player.camera = Camera3D.new()
	player.camera.current = true
	_created_nodes.append(player.camera)
	var camera_utils := CameraUtils.new(player)
	_created_nodes.append(camera_utils)
	player.camera_utils = camera_utils
	return {"player": player, "camera_utils": camera_utils}

func _create_portal_indicator_utils(player: CharacterBody3D) -> Node:
	var portal_utils := PortalIndicatorUtils.new(player)
	_created_nodes.append(portal_utils)
	return portal_utils

func test_camera_override_offset_uses_override_direction() -> void:
	var context = _create_camera_context()
	var camera_utils = context["camera_utils"]
	camera_utils.base_camera_offset = Vector3(10.0, 5.0, 0.0)
	camera_utils.camera_override_direction = Vector3(-1.0, 0.0, 0.0)
	var offset: Vector3 = camera_utils._get_camera_override_offset()
	assert_eq(offset, Vector3(-10.0, 5.0, 0.0), "Override direction should control camera offset sign")

func test_camera_override_offset_falls_back_to_base_direction() -> void:
	var context = _create_camera_context()
	var camera_utils = context["camera_utils"]
	camera_utils.base_camera_offset = Vector3(3.0, 2.0, 4.0)
	camera_utils.camera_override_direction = Vector3.ZERO
	var offset: Vector3 = camera_utils._get_camera_override_offset()
	assert_eq(offset, Vector3(3.0, 2.0, 4.0), "Zero override direction should keep base camera offset")

func test_active_camera_damping_time_constant_uses_override_value() -> void:
	var context = _create_camera_context()
	var player = context["player"]
	var camera_utils = context["camera_utils"]
	player.camera_damping_time_constant = 0.2
	camera_utils.set_camera_override(Vector3.ZERO, Vector3.RIGHT, 60.0, 2.5)
	assert_eq(camera_utils._get_active_camera_damping_time_constant(), 2.5, "Override damping time constant should be used when active")

func test_active_camera_damping_time_constant_falls_back_to_default() -> void:
	var context = _create_camera_context()
	var player = context["player"]
	var camera_utils = context["camera_utils"]
	player.camera_damping_time_constant = 0.3
	camera_utils.set_camera_override(Vector3.ZERO, Vector3.RIGHT, 60.0, 0.0)
	assert_eq(camera_utils._get_active_camera_damping_time_constant(), 0.3, "Default damping time constant should be used when override value is zero")

func test_active_camera_damping_time_constant_uses_temporary_value() -> void:
	var context = _create_camera_context()
	var player = context["player"]
	var camera_utils = context["camera_utils"]
	player.camera_damping_time_constant = 0.25
	camera_utils.set_temporary_camera_damping_time_constant(1.0, 0.5)
	assert_eq(camera_utils._get_active_camera_damping_time_constant(), 1.0, "Temporary damping time constant should be used while active")

func test_temporary_camera_damping_time_constant_expires() -> void:
	var context = _create_camera_context()
	var player = context["player"]
	var camera_utils = context["camera_utils"]
	player.camera_damping_time_constant = 0.4
	camera_utils.set_temporary_camera_damping_time_constant(1.0, 0.5)
	camera_utils._advance_temporary_camera_damping_time_constant(0.5)
	assert_eq(camera_utils._get_active_camera_damping_time_constant(), 0.4, "Temporary damping time constant should expire after duration")

func test_portal_indicator_hidden_during_camera_override() -> void:
	var context = _create_camera_context()
	var camera_utils = context["camera_utils"]
	var portal_utils = _create_portal_indicator_utils(context["player"])
	GameState.portal_active = true
	camera_utils.camera_override_active = true
	assert_false(portal_utils._should_show_portal_indicator(), "Indicator should stay hidden during camera override")
	GameState.portal_active = false

func test_portal_indicator_visible_after_override() -> void:
	var context = _create_camera_context()
	var camera_utils = context["camera_utils"]
	var portal_utils = _create_portal_indicator_utils(context["player"])
	GameState.portal_active = true
	camera_utils.camera_override_active = false
	assert_true(portal_utils._should_show_portal_indicator(), "Indicator should show after camera override ends")
	GameState.portal_active = false

func test_portal_indicator_hidden_when_another_camera_is_current() -> void:
	var context = _create_camera_context()
	var player = context["player"]
	var portal_utils = _create_portal_indicator_utils(player)
	GameState.portal_active = true
	player.camera.current = false
	assert_false(portal_utils._should_show_portal_indicator(), "Player compass should stay hidden during external camera shots")

func test_portal_indicator_hidden_for_captured_or_escaped_player() -> void:
	var context = _create_camera_context()
	var player = context["player"]
	var portal_utils = _create_portal_indicator_utils(player)
	GameState.portal_active = true
	player.is_dead = true
	assert_false(portal_utils._should_show_portal_indicator(), "Captured players should not receive escape guidance")
	player.is_dead = false
	GameState.escaped_peer_ids.append(player.peer_id)
	assert_false(portal_utils._should_show_portal_indicator(), "Escaped players should not receive escape guidance")
