extends GutTest

const WorldPortalUtils = preload("res://scenes/world/portal.gd")

class CameraUtilsStub:
	var set_override_called = false
	var clear_override_called = false
	var temporary_damping_called = false
	var last_target: Vector3 = Vector3.ZERO
	var last_direction: Vector3 = Vector3.ZERO
	var last_fov: float = 0.0
	var last_damping: float = 0.0
	var last_duration: float = 0.0

	func set_camera_override(target: Vector3, direction: Vector3, fov: float, damping_time_constant: float) -> void:
		set_override_called = true
		last_target = target
		last_direction = direction
		last_fov = fov
		last_damping = damping_time_constant

	func clear_camera_override() -> void:
		clear_override_called = true

	func set_temporary_camera_damping_time_constant(damping_time_constant: float, duration: float) -> void:
		temporary_damping_called = true
		last_damping = damping_time_constant
		last_duration = duration

class TestPlayer:
	extends Node3D
	var camera_utils: CameraUtilsStub

	func is_multiplayer_authority() -> bool:
		return true

class TestWorld:
	extends Node3D
	var player_container: Node
	var grid_map: GridMap
	var portal_container: Node3D
	var portal_scene: PackedScene
	var portal_camera_focus_duration: float = 2.0
	var portal_tile_slide_duration: float = 1.0
	var portal_tile_slide_distance_multiplier: float = 1.0
	var portal_depth_offset: float = 0.05
	var portal_camera_zoom_fov: float = 55.0
	var portal_camera_return_duration: float = 1.5
	var portal_open_hold_duration: float = 1.0

	func _init() -> void:
		player_container = Node.new()
		add_child(player_container)

var _created_nodes: Array[Node] = []

func after_each() -> void:
	for node in _created_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_created_nodes.clear()
	GameState.portal_active = false
	GameState.portal_cinematic_active = false
	GameState.portal_position = Vector3.ZERO

func test_start_portal_camera_cinematic_uses_camera_utils() -> void:
	var world := TestWorld.new()
	add_child(world)
	_created_nodes.append(world)
	var portal_utils := WorldPortalUtils.new(world)
	_created_nodes.append(portal_utils)
	var player := TestPlayer.new()
	player.camera_utils = CameraUtilsStub.new()
	world.player_container.add_child(player)
	portal_utils._start_portal_camera_cinematic(player, Vector3(1.0, 2.0, 3.0), Vector3i.ZERO)
	assert_true(player.camera_utils.set_override_called, "Portal cinematic should set camera override.")
	assert_true(GameState.portal_cinematic_active, "Portal cinematic should be active when starting.")

func test_finish_portal_camera_cinematic_uses_camera_utils() -> void:
	var world := TestWorld.new()
	add_child(world)
	_created_nodes.append(world)
	var portal_utils := WorldPortalUtils.new(world)
	_created_nodes.append(portal_utils)
	var player := TestPlayer.new()
	player.camera_utils = CameraUtilsStub.new()
	world.player_container.add_child(player)
	portal_utils._finish_portal_camera_cinematic(player)
	assert_true(player.camera_utils.clear_override_called, "Portal cinematic should clear camera override.")
	assert_true(player.camera_utils.temporary_damping_called, "Portal cinematic should set temporary damping.")
	assert_eq(player.camera_utils.last_duration, world.portal_camera_return_duration, "Portal cinematic should use world return duration.")
