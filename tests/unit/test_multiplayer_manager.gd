extends GutTest

var _original_metadata: Array[Dictionary] = []
var _original_is_host := false

func before_each() -> void:
	_original_metadata = MultiplayerManager.connected_players_metadata.duplicate(true)
	_original_is_host = MultiplayerManager.is_host
	MultiplayerManager.connected_players_metadata.clear()

func after_each() -> void:
	MultiplayerManager.connected_players_metadata.clear()
	for metadata in _original_metadata:
		MultiplayerManager.connected_players_metadata.append(metadata)
	MultiplayerManager.is_host = _original_is_host

func test_get_connected_peer_ids_skips_missing() -> void:
	MultiplayerManager.connected_players_metadata.append({"peer_id": 10})
	MultiplayerManager.connected_players_metadata.append({"name": "no_id"})
	MultiplayerManager.connected_players_metadata.append({"peer_id": 42})

	var ids = MultiplayerManager.get_connected_peer_ids()
	assert_eq(ids, [10, 42], "Should ignore metadata without peer_id")

func test_get_connected_peer_ids_empty() -> void:
	var ids = MultiplayerManager.get_connected_peer_ids()
	assert_eq(ids.size(), 0, "Empty metadata should return empty list")

func test_has_and_remove_metadata() -> void:
	MultiplayerManager.connected_players_metadata.append({"peer_id": 1})
	MultiplayerManager.connected_players_metadata.append({"peer_id": 2})

	assert_true(MultiplayerManager._has_player_metadata(2), "Should find existing peer")
	MultiplayerManager._remove_player_metadata(2)
	assert_false(MultiplayerManager._has_player_metadata(2), "Should remove existing peer")
	assert_eq(MultiplayerManager.connected_players_metadata.size(), 1, "Only one peer should remain")

	MultiplayerManager._remove_player_metadata(999)
	assert_eq(MultiplayerManager.connected_players_metadata.size(), 1, "Removing missing peer should not change list")

func test_add_metadata_no_duplicates() -> void:
	MultiplayerManager._add_player_metadata(5)
	MultiplayerManager._add_player_metadata(5)
	assert_eq(MultiplayerManager.connected_players_metadata.size(), 1, "Should not duplicate same peer")

func test_remove_metadata_only_target() -> void:
	MultiplayerManager.connected_players_metadata.append({"peer_id": 1})
	MultiplayerManager.connected_players_metadata.append({"peer_id": 2})
	MultiplayerManager.connected_players_metadata.append({"peer_id": 3})

	MultiplayerManager._remove_player_metadata(2)

	assert_false(MultiplayerManager._has_player_metadata(2), "Removed peer should be gone")
	assert_true(MultiplayerManager._has_player_metadata(1), "Other peers should remain")
	assert_true(MultiplayerManager._has_player_metadata(3), "Other peers should remain")
