extends GutTest

var _original_metadata: Array[Dictionary] = []

func before_each() -> void:
	_original_metadata = NetworkManager.connected_players_metadata.duplicate(true)
	NetworkManager.connected_players_metadata.clear()

func after_each() -> void:
	NetworkManager.connected_players_metadata.clear()
	for metadata in _original_metadata:
		NetworkManager.connected_players_metadata.append(metadata)

func test_get_connected_peer_ids_skips_missing() -> void:
	NetworkManager.connected_players_metadata.append({"peer_id": 10})
	NetworkManager.connected_players_metadata.append({"name": "no_id"})
	NetworkManager.connected_players_metadata.append({"peer_id": 42})

	var ids = NetworkManager.get_connected_peer_ids()
	assert_eq(ids, [10, 42], "Should ignore metadata without peer_id")

func test_get_connected_peer_ids_empty() -> void:
	var ids = NetworkManager.get_connected_peer_ids()
	assert_eq(ids.size(), 0, "Empty metadata should return empty list")

func test_has_and_remove_metadata() -> void:
	NetworkManager.connected_players_metadata.append({"peer_id": 1})
	NetworkManager.connected_players_metadata.append({"peer_id": 2})

	assert_true(NetworkManager._has_player_metadata(2), "Should find existing peer")
	NetworkManager._remove_player_metadata(2)
	assert_false(NetworkManager._has_player_metadata(2), "Should remove existing peer")
	assert_eq(NetworkManager.connected_players_metadata.size(), 1, "Only one peer should remain")

	NetworkManager._remove_player_metadata(999)
	assert_eq(NetworkManager.connected_players_metadata.size(), 1, "Removing missing peer should not change list")

func test_add_metadata_no_duplicates() -> void:
	NetworkManager._add_player_metadata(5)
	NetworkManager._add_player_metadata(5)
	assert_eq(NetworkManager.connected_players_metadata.size(), 1, "Should not duplicate same peer")

func test_remove_metadata_only_target() -> void:
	NetworkManager.connected_players_metadata.append({"peer_id": 1})
	NetworkManager.connected_players_metadata.append({"peer_id": 2})
	NetworkManager.connected_players_metadata.append({"peer_id": 3})

	NetworkManager._remove_player_metadata(2)

	assert_false(NetworkManager._has_player_metadata(2), "Removed peer should be gone")
	assert_true(NetworkManager._has_player_metadata(1), "Other peers should remain")
	assert_true(NetworkManager._has_player_metadata(3), "Other peers should remain")
