extends GutTest

const PlayerScene := preload("res://scenes/player/scene.tscn")
var player: CharacterBody3D
var original_state: GameState.State

func before_each() -> void:
	original_state = GameState.game_state
	GameState.reset(GameState.State.LOBBY)
	player = PlayerScene.instantiate()
	player._on_before_spawn({"peer_id": 1, "position": Vector3(12, 0, 8)})
	add_child_autofree(player)
	player.set_physics_process(false)

func after_each() -> void:
	GameState.reset(original_state)

func test_listener_stays_near_character_when_camera_moves() -> void:
	player.camera_utils.update(0.1)
	assert_true(player.audio_listener.is_current())
	assert_almost_eq(player.audio_listener.global_position, player.global_position + Vector3.UP * 1.1, Vector3.ONE * 0.001)
	assert_gt(player.camera.global_position.distance_to(player.audio_listener.global_position), 5.0)
	assert_eq(player.audio_listener.global_basis, player.camera.global_basis)

func test_replicated_steps_and_actions_select_character_sounds() -> void:
	player.is_hunter = false
	player.play_footstep()
	assert_has(CastleAudio.WOOD_STEPS, player.movement_audio_player.stream)
	player.is_hunter = true
	player.play_footstep()
	assert_has(CastleAudio.ARMOR_STEPS, player.movement_audio_player.stream)
	player.play_action_animation(&"Attack")
	assert_eq(player.attack_audio_player.stream, CastleAudio.SOUNDS[&"swing"])
	player.play_action_animation(&"Roll")
	assert_eq(player.attack_audio_player.stream, CastleAudio.SOUNDS[&"roll"])
	assert_eq(player.movement_audio_player.bus, &"Master")
	assert_eq(player.attack_audio_player.bus, &"Master")

func test_repeated_ui_events_use_bounded_voices_and_master_mix() -> void:
	var child_count := CastleAudio.get_child_count()
	for index in 40:
		CastleAudio.play_ui(&"confirm")
		CastleAudio.play_at(&"fuel", player.global_position)
	assert_eq(CastleAudio.get_child_count(), child_count, "Overlapping cues reuse a fixed pool")
	assert_eq(CastleAudio.music.bus, &"Master")
	assert_eq(CastleAudio.ambience.bus, &"Master")
	assert_true(CastleAudio.MUSIC.loop)
	assert_true(CastleAudio.AMBIENCE.loop)
