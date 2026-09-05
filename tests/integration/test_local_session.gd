extends GutTest

var _backend: LocalBackend
var _previous_peer: MultiplayerPeer

func before_each() -> void:
	_previous_peer = multiplayer.multiplayer_peer
	_backend = LocalBackend.new()
	add_child(_backend)

func after_each() -> void:
	_backend.leave_lobby()
	_backend.free()
	multiplayer.multiplayer_peer = _previous_peer

func test_failed_join_releases_peer_and_allows_retry() -> void:
	watch_signals(_backend)
	_backend.host_address = "127.0.0.1"
	_backend.join_lobby(1)
	assert_eq(_backend.current_lobby_id, 0, "A pending connection is not a joined lobby")
	_backend._on_connection_failed()
	assert_signal_emitted(_backend, "lobby_joined", "Connection failure reaches the menu callback")
	assert_eq(_backend._pending_join_lobby_id, 0)
	assert_null(_backend._peer, "The failed ENet peer must release its socket")
	assert_true(_backend._join_timeout.is_stopped())
	_backend.join_lobby(1)
	assert_ne(_backend._pending_join_lobby_id, 0, "The next attempt starts normally")
	_backend.leave_lobby()
	assert_true(_backend._join_timeout.is_stopped(), "Leaving cancels the pending timeout")

func test_player_metadata_uses_saved_local_name() -> void:
	var metadata := NetworkManager._build_player_metadata(multiplayer.get_unique_id())
	assert_eq(metadata.name, Settings.player_name)
	assert_eq(metadata.peer_id, multiplayer.get_unique_id())
