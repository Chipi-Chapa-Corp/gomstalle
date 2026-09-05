extends GutTest

func before_each() -> void:
	GameState.reset(GameState.State.IDLE)
	GameState.hunter_peer_id = 1
	GameState.participant_peer_ids = [1, 2, 3]

func after_each() -> void:
	GameState.reset(GameState.State.IDLE)

func _begin_hunt() -> void:
	GameState.game_state = GameState.State.STARTED
	GameState.remaining_seconds = GameState.HUNT_SECONDS

func test_hiding_grace_locks_only_knight_and_then_starts_full_hunt() -> void:
	GameState.game_state = GameState.State.HIDING
	GameState.remaining_seconds = GameState.HIDING_SECONDS
	assert_false(GameState.can_player_act(1))
	assert_true(GameState.can_player_act(2))
	GameState.advance_round(11.5)
	assert_eq(GameState.game_state, GameState.State.HIDING)
	GameState.advance_round(0.5)
	assert_eq(GameState.game_state, GameState.State.STARTED)
	assert_eq(GameState.remaining_seconds, GameState.HUNT_SECONDS)
	assert_true(GameState.can_player_act(1))

func test_capture_cannot_resolve_knight_unknown_player_or_grace_period() -> void:
	GameState.game_state = GameState.State.HIDING
	GameState.record_capture(2)
	assert_true(GameState.captured_peer_ids.is_empty())
	_begin_hunt()
	GameState.record_capture(1)
	GameState.record_capture(99)
	assert_true(GameState.captured_peer_ids.is_empty())

func test_all_captured_finishes_round_once_with_knight_victory() -> void:
	_begin_hunt()
	GameState.record_capture(2)
	GameState.record_capture(2)
	assert_eq(GameState.captured_peer_ids, [2])
	assert_eq(GameState.game_state, GameState.State.STARTED)
	GameState.record_capture(3)
	assert_eq(GameState.game_state, GameState.State.RESULTS)
	assert_eq(GameState.winner, 0)
	assert_false(GameState.can_player_act(1))

func test_portal_required_and_escape_survives_remaining_capture() -> void:
	_begin_hunt()
	GameState.record_escape(2)
	assert_true(GameState.escaped_peer_ids.is_empty())
	GameState.portal_active = true
	GameState.record_escape(2)
	GameState.record_capture(2)
	assert_eq(GameState.escaped_peer_ids, [2])
	assert_true(GameState.captured_peer_ids.is_empty())
	assert_false(GameState.can_player_act(2))
	GameState.record_capture(3)
	assert_eq(GameState.game_state, GameState.State.RESULTS)
	assert_eq(GameState.winner, 1)

func test_timeout_resolves_survivors_without_counting_them_as_escaped() -> void:
	_begin_hunt()
	GameState.advance_round(GameState.HUNT_SECONDS)
	assert_eq(GameState.game_state, GameState.State.RESULTS)
	assert_eq(GameState.winner, 0)
	assert_true(GameState.escaped_peer_ids.is_empty())

func test_portal_reveal_does_not_consume_hunt_time() -> void:
	_begin_hunt()
	GameState.portal_cinematic_active = true
	GameState.advance_round(6.0)
	assert_eq(GameState.remaining_seconds, GameState.HUNT_SECONDS)

func test_departed_skeleton_is_resolved_and_departed_knight_concedes() -> void:
	_begin_hunt()
	GameState.player_departed(2)
	assert_eq(GameState.captured_peer_ids, [2])
	GameState.player_departed(1)
	assert_eq(GameState.game_state, GameState.State.RESULTS)
	assert_eq(GameState.winner, 1)
