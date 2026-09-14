extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/scene.tscn")
const STEP := 1.0 / 60.0

var arena: Node3D
var player: CharacterBody3D
var _original_state: GameState.State

func before_each() -> void:
	_original_state = GameState.game_state
	GameState.game_state = GameState.State.LOBBY
	arena = Node3D.new()
	add_child_autofree(arena)
	_make_floor()
	player = PLAYER_SCENE.instantiate()
	player._on_before_spawn({"peer_id": 1, "position": Vector3(0.0, 0.1, 0.0)})
	arena.add_child(player)
	player.set_physics_process(false)
	await _steps(3)

func after_each() -> void:
	GameState.game_state = _original_state

func _make_floor() -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 1.0, 40.0)
	collider.shape = shape
	body.add_child(collider)
	body.position.y = -0.5
	arena.add_child(body)

func _steps(count: int, movement_input := Vector2.ZERO) -> void:
	for frame_index in count:
		await get_tree().physics_frame
		player.forces.handle(STEP)
		player.actions.handle(STEP)
		player.movement._apply_movement(STEP, movement_input, false)
		player.move_and_slide()
		player.movement.finish_physics(STEP)

func test_lobby_spawn_starts_real_action_animation_state() -> void:
	assert_true(player.anim_tree.active)
	await _steps(2)
	assert_eq(player.playback.get_current_node(), &"IW", "Movement initializes the production animation state machine")
	player.play_action_animation(&"Jump")
	player.anim_tree.advance(0.0)
	assert_true(player.anim_tree.get("parameters/IW/Jump_OS/active"), "The real jump one-shot becomes active")

func test_real_model_faces_the_run_direction() -> void:
	await _steps(12, Vector2(1.0, 0.0))
	assert_gt(player.velocity.x, 4.0)
	assert_gt(player.model.global_basis.z.x, 0.75, "The model faces the direction of travel")
