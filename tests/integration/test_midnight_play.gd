extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/scene.tscn")
const MIDNIGHT_LIBRARY_SCENE: PackedScene = preload("res://assets/castle/midnight_library/midnight_library.glb")
const MIDNIGHT_PLAY_SCRIPT: Script = preload("res://scenes/midnight/play.gd")
const STEP := 1.0 / 60.0

var stage: Node3D
var camera: Camera3D
var play: MidnightPlay
var original_game_state: GameState.State
var original_paused := false
var original_portal_cinematic := false
var initial_camera_transform := Transform3D.IDENTITY
var initial_camera_fov := 0.0

func before_each() -> void:
	original_game_state = GameState.game_state
	original_paused = GameState.is_paused
	original_portal_cinematic = GameState.portal_cinematic_active
	GameState.game_state = GameState.State.IDLE
	GameState.is_paused = false
	GameState.portal_cinematic_active = false
	stage = Node3D.new()
	add_child_autofree(stage)
	_make_floor()
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	initial_camera_transform = camera.global_transform
	initial_camera_fov = camera.fov
	play = MIDNIGHT_PLAY_SCRIPT.new() as MidnightPlay
	add_child_autofree(play)
	play.begin(stage, camera)
	play.player.set_physics_process(false)
	await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(play) and play.is_active:
		play.finish()
	GameState.game_state = original_game_state
	GameState.is_paused = original_paused
	GameState.portal_cinematic_active = original_portal_cinematic

func test_begin_uses_production_player_and_real_floor_movement() -> void:
	assert_true(play.is_active)
	assert_eq(play.player.get_script().resource_path, "res://scenes/player/script.gd")
	assert_eq(play.player.camera_utils.camera_yaw_offset, 0.0)
	assert_false(play.player.camera.current)
	assert_false(play.player.hud.visible)
	assert_true(camera.current)
	assert_true(play.controls_label.text.contains("F Air slide (airborne)"))
	assert_eq(GameState.game_state, GameState.State.LOBBY)
	var initial_position := play.player.global_position
	await _advance_player(30, Vector2(0.0, -1.0), false)
	assert_true(play.player.is_on_floor())
	assert_lt(play.player.global_position.z, initial_position.z - 0.5)
	assert_lt(play.player.global_position.y, 0.1)

func test_wisps_require_proximity_and_are_collected_once() -> void:
	play.player.global_position = Vector3(0.0, 0.2, 7.0)
	_press_e()
	assert_eq(play.collected_wisps.size(), 0)
	play.player.global_position = play.wisp_positions[0]
	_press_e()
	assert_eq(play.collected_wisps, [0])
	assert_false(play.wisps[0].visible)
	_press_e()
	assert_eq(play.collected_wisps, [0])
	play.player.global_position = play.wisp_positions[1]
	_press_e()
	assert_eq(play.collected_wisps, [0, 1])

func test_library_awakens_only_after_three_wisps_and_replay_resets_goal() -> void:
	play.player.global_position = Vector3(0.0, 0.2, -3.0)
	_press_e()
	assert_false(play.library_awake)
	for wisp_index in [0, 1]:
		play.player.global_position = play.wisp_positions[wisp_index]
		_press_e()
	play.player.global_position = Vector3(0.0, 0.2, -3.0)
	_press_e()
	assert_false(play.library_awake)
	play.player.global_position = play.wisp_positions[2]
	_press_e()
	play._update_ui()
	assert_eq(play.status_label.text, "Wisps 3 / 3 · Reach the orrery")
	assert_eq(play.controls_label.text, "E Awaken the library")
	play.player.global_position = Vector3(0.0, 0.2, -3.0)
	_press_e()
	assert_true(play.library_awake)
	assert_true(play.replay_control.visible)
	play.replay_control.emit_signal("pressed")
	assert_false(play.library_awake)
	assert_eq(play.collected_wisps.size(), 0)
	assert_false(play.replay_control.visible)
	assert_eq(play.player.global_position, MidnightPlay.PLAYER_SPAWN)

func test_finish_removes_owned_nodes_and_restores_state_and_camera() -> void:
	var owned_player := play.player
	var owned_actors := play.actors
	var owned_ui := play.ui
	play.finish()
	assert_false(play.is_active)
	assert_false(is_instance_valid(owned_player))
	assert_false(is_instance_valid(owned_actors))
	assert_false(is_instance_valid(owned_ui))
	assert_eq(camera.global_transform, initial_camera_transform)
	assert_eq(camera.fov, initial_camera_fov)
	assert_true(camera.current)
	assert_eq(GameState.game_state, GameState.State.IDLE)
	assert_false(GameState.is_paused)
	assert_false(GameState.portal_cinematic_active)

func test_serving_hatch_wisp_is_reachable_with_production_air_slide() -> void:
	_add_library_fixture()
	play.player.global_position = Vector3(-4.2, 0.2, 1.25)
	await _advance_player(4, Vector2.ZERO, false)
	play.player.movement.request_jump()
	await _advance_player(1, Vector2(0.0, -1.0), false)
	assert_false(play.player.is_on_floor())
	assert_true(play.player.movement.start_air_slide())
	await _advance_player(24, Vector2(0.0, -1.0), false)
	assert_lt(play.player.global_position.z, -1.5)
	assert_lte(play.player.global_position.distance_to(play.wisp_positions[1]), MidnightPlay.WISP_REACH)
	_press_e()
	assert_eq(play.collected_wisps, [1])

func test_upper_gallery_wisp_is_reachable_via_stair_and_balconies() -> void:
	_add_library_fixture()
	play.player.global_position = Vector3(4.0, 0.2, 8.0)
	await _advance_player(4, Vector2.ZERO, false)
	await _advance_player(62, Vector2(0.0, -1.0), false)
	assert_gt(play.player.global_position.y, 3.2)
	await _advance_player(20, Vector2(1.0, 0.0), false)
	await _advance_player(128, Vector2(0.0, -1.0), false)
	await _advance_player(116, Vector2(-1.0, 0.0), false)
	play.player.movement.request_jump()
	await _advance_player(20, Vector2(-1.0, 0.0), true)
	assert_false(play.player.is_on_floor())
	assert_true(play.player.movement.start_air_slide())
	await _advance_player(30, Vector2(-1.0, 0.0), true)
	await _advance_player(15, Vector2(-1.0, 0.0), true)
	await _advance_player(43, Vector2(0.0, 1.0), false)
	assert_lt(absf(play.player.global_position.x - play.wisp_positions[0].x), 0.8)
	assert_lt(absf(play.player.global_position.z - play.wisp_positions[0].z), 0.8)
	assert_gt(play.player.global_position.y, 3.2)
	play._update_camera()
	var focus_position := play.player.global_position + Vector3.UP * MidnightPlay.CAMERA_FOCUS_HEIGHT
	assert_gt(play.camera.global_position.distance_to(focus_position), 5.5, "The gallery camera keeps a clear follow distance")
	play.player.movement.request_jump()
	await _advance_player(10, Vector2.ZERO, false)
	assert_lte(play.player.global_position.distance_to(play.wisp_positions[0]), MidnightPlay.WISP_REACH)
	_press_e()
	assert_eq(play.collected_wisps, [0])

func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	var floor_collider := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40.0, 1.0, 40.0)
	floor_collider.shape = floor_shape
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_collider)
	stage.add_child(floor_body)

func _add_library_fixture() -> void:
	var library := MIDNIGHT_LIBRARY_SCENE.instantiate() as Node3D
	stage.add_child(library)

func _advance_player(frame_count: int, movement_input: Vector2, sprint: bool) -> void:
	for frame_index in frame_count:
		await get_tree().physics_frame
		play.player.forces.handle(STEP)
		play.player.movement._apply_movement(STEP, movement_input, sprint)
		play.player.move_and_slide()
		play.player.movement.finish_physics(STEP)

func _press_e() -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_E
	key_event.physical_keycode = KEY_E
	key_event.pressed = true
	play._unhandled_input(key_event)
