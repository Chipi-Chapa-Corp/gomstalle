extends GutTest

const PlayerScene := preload("res://scenes/player/scene.tscn")
const STEP := 1.0 / 60.0

var arena: Node3D
var player: CharacterBody3D

func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)
	_make_box(Vector3(0.0, -0.5, 0.0), Vector3(80.0, 1.0, 80.0))
	player = PlayerScene.instantiate()
	player._on_before_spawn({"peer_id": 1, "position": Vector3(0.0, 0.1, 0.0)})
	arena.add_child(player)
	player.set_physics_process(false)
	player.camera_utils.camera_yaw_offset = 0.0
	await _steps(15)
	assert_true(player.is_on_floor(), "Fixture must settle on the actual floor before testing input")

func _make_box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = position
	arena.add_child(body)
	return body

func _steps(count: int, movement_input := Vector2.ZERO, sprint := false) -> void:
	for frame_index in count:
		await get_tree().physics_frame
		player.forces.handle(STEP)
		player.movement._apply_movement(STEP, movement_input, sprint)
		player.move_and_slide()
		player.movement.finish_physics(STEP)

func test_jump_is_immediate_and_cannot_repeat_in_midair() -> void:
	assert_true(player.is_on_floor())
	player.movement.request_jump()
	await _steps(1)
	assert_gt(player.velocity.y, 6.0)
	await _steps(15)
	var falling_velocity: float = player.velocity.y
	player.movement.request_jump()
	await _steps(1)
	assert_lt(player.velocity.y, falling_velocity)
	await _steps(65)
	assert_true(player.is_on_floor())
	player.movement.request_jump()
	await _steps(1)
	assert_gt(player.velocity.y, 6.0)

func test_jump_buffer_fires_after_physical_landing() -> void:
	player.position.y = 0.15
	player.velocity.y = -3.0
	await _steps(1)
	player.movement.request_jump()
	await _steps(6)
	assert_gt(player.velocity.y, 4.0)
	assert_gt(player.position.y, 0.1)

func test_air_slide_is_airborne_hider_only_and_spends_stamina_once() -> void:
	assert_false(player.movement.start_air_slide())
	player.movement.request_jump()
	await _steps(4, Vector2(0.0, 1.0))
	player.is_hunter = true
	assert_false(player.movement.start_air_slide())
	player.is_hunter = false
	var initial_stamina: float = player.stamina
	assert_true(player.movement.start_air_slide())
	assert_almost_eq(player.stamina, initial_stamina - 12.0, 0.001)
	assert_false(player.movement.start_air_slide())
	await _steps(1)
	assert_gt(Vector2(player.velocity.x, player.velocity.z).length(), 12.0)
	assert_true(player.regular_collider.disabled)
	assert_false(player.dash_collider.disabled)
	await _steps(80)
	assert_false(player.movement.is_air_sliding)
	assert_false(player.movement.is_compact)
	assert_false(player.regular_collider.disabled)
	assert_true(player.dash_collider.disabled)

func test_compact_collider_waits_for_headroom_then_stands() -> void:
	var ceiling := _make_box(Vector3(0.0, 1.35, 0.0), Vector3(8.0, 0.5, 8.0))
	player.movement._set_compact(true)
	await _steps(3)
	assert_true(player.movement.is_compact)
	assert_true(player.regular_collider.disabled)
	ceiling.queue_free()
	await _steps(3)
	assert_false(player.movement.is_compact)
	assert_false(player.regular_collider.disabled)

func test_air_slide_crosses_a_low_opening_that_blocks_walking() -> void:
	_make_box(Vector3(0.0, 2.0, 2.0), Vector3(6.0, 1.3, 0.4))
	await _steps(35, Vector2(0.0, 1.0))
	assert_lt(player.position.z, 1.5)
	player.position = Vector3(0.0, 0.03, 0.0)
	player.velocity = Vector3.ZERO
	await _steps(3)
	player.movement.request_jump()
	await _steps(1, Vector2(0.0, 1.0))
	assert_true(player.movement.start_air_slide())
	await _steps(25, Vector2(0.0, 1.0))
	assert_gt(player.position.z, 2.5)

func test_input_lock_stops_horizontal_motion_but_preserves_falling() -> void:
	player.position.y = 3.0
	player.velocity = Vector3(8.0, -2.0, 0.0)
	player.forces.handle(STEP)
	player.movement.handle_input_locked(STEP)
	assert_eq(player.velocity.x, 0.0)
	assert_lt(player.velocity.y, -2.0)
	player.is_stunned = true
	player.forces.handle(STEP)
	assert_lt(player.velocity.y, -2.0)

func test_melee_has_startup_and_cooldown_and_cannot_reach_through_wall() -> void:
	player.is_hunter = true
	var target := _make_box(Vector3(0.0, 0.0, 1.8), Vector3(0.4, 1.0, 0.4))
	assert_true(player.can_reach_attack(target))
	_make_box(Vector3(0.0, 1.0, 0.9), Vector3(3.0, 2.0, 0.2))
	await _steps(2)
	assert_false(player.can_reach_attack(target))
	assert_true(player.actions.start_attack())
	assert_false(player.attack_hitbox.monitoring)
	assert_false(player.actions.start_attack())
	player.actions.advance_attack(0.13)
	assert_true(player.attack_hitbox.monitoring)
	player.actions.advance_attack(0.3)
	assert_false(player.attack_hitbox.monitoring)

func test_coyote_jump_survives_one_frame_after_losing_the_floor() -> void:
	arena.get_child(0).queue_free()
	await _steps(2)
	assert_false(player.is_on_floor())
	player.movement.request_jump()
	await _steps(1)
	assert_gt(player.velocity.y, 6.0)

func test_sprint_drains_fractional_stamina_and_resting_recovers_with_shift_held() -> void:
	await _steps(60, Vector2.ONE.normalized(), true)
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), 8.0, 0.01)
	assert_almost_eq(player.stamina, 40.0, 0.3)
	var tired_stamina: float = player.stamina
	await _steps(90, Vector2.ZERO, true)
	assert_gt(player.stamina, tired_stamina + 3.0)

func _make_interactable(position: Vector3) -> StaticBody3D:
	var container := Node3D.new()
	arena.add_child(container)
	var body := StaticBody3D.new()
	body.set_script(preload("res://tests/helpers/test_interactable_null.gd"))
	body.add_to_group("interactible")
	body.collision_layer = 16
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 1.0, 0.4)
	collider.shape = shape
	collider.position.y = 0.5
	body.add_child(collider)
	container.add_child(body)
	return body

func test_interaction_target_respects_walls_and_refreshes_after_removal() -> void:
	var original_state := GameState.game_state
	GameState.game_state = GameState.State.LOBBY
	var near_target := _make_interactable(Vector3(0.0, 0.0, 1.1))
	var far_target := _make_interactable(Vector3(1.4, 0.0, 0.0))
	var wall := _make_box(Vector3(0.0, 1.0, 0.6), Vector3(1.0, 2.0, 0.1))
	await _steps(2)
	player.interactions._update_target()
	assert_eq(player.closest_item, far_target)
	wall.queue_free()
	await _steps(2)
	player.interactions._update_target()
	assert_eq(player.closest_item, near_target)
	near_target.get_parent().queue_free()
	await _steps(2)
	player.interactions._update_target()
	assert_eq(player.closest_item, far_target)
	GameState.game_state = original_state

func test_sword_contact_records_capture_only_during_an_active_attack() -> void:
	var original_state := GameState.game_state
	var target: CharacterBody3D = PlayerScene.instantiate()
	target._on_before_spawn({"peer_id": 2, "position": Vector3(0.0, 0.0, 1.5)})
	arena.add_child(target)
	target.set_physics_process(false)
	GameState.game_state = GameState.State.STARTED
	GameState.hunter_peer_id = 1
	GameState.participant_peer_ids = [1, 2, 3]
	player.is_hunter = true
	await _steps(2)
	player.request_kill(2)
	assert_false(target.is_dead, "A kill request without a sword swing must not capture a player")
	assert_true(player.actions.start_attack())
	for frame_index in 25:
		await _steps(1)
		player.actions.advance_attack(STEP)
	assert_true(target.is_dead, "The physical sword hitbox should capture the nearby hider")
	assert_has(GameState.captured_peer_ids, 2)
	GameState.reset(original_state)

func test_escaped_player_remains_stationary_without_collision() -> void:
	var original_state := GameState.game_state
	GameState.escaped_peer_ids = [player.peer_id]
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3(4.0, -8.0, 3.0)
	var escape_position: Vector3 = player.global_position
	for frame_index in 10:
		await get_tree().physics_frame
		player._physics_process(STEP)
	assert_eq(player.global_position, escape_position)
	assert_eq(player.velocity, Vector3.ZERO)
	GameState.reset(original_state)
