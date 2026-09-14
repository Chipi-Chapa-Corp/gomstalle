extends GutTest

const MainScript := preload("res://scenes/main/script.gd")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/scene.tscn")

class WorldFixture extends Node3D:
	var player_container: Node

	func _init() -> void:
		player_container = Node.new()
		add_child(player_container)

class PlayerListFixture extends WorldPlayerListUtils:
	var spawned_peer_ids: Array[int] = []

	func _spawn_player(peer_id: int) -> void:
		if spawned_peer_ids.has(peer_id):
			return
		spawned_peer_ids.append(peer_id)

var _original_metadata: Array[Dictionary] = []
var _original_target_count := 6
var _original_state: GameState.State = GameState.State.IDLE
var _original_refuse_new_connections := false
var _original_loading_visible := false

func before_each() -> void:
	_original_metadata = NetworkManager.connected_players_metadata.duplicate(true)
	_original_target_count = GameState.target_player_count
	_original_state = GameState.game_state
	_original_refuse_new_connections = multiplayer.multiplayer_peer.refuse_new_connections
	_original_loading_visible = SceneLoading.visible

func after_each() -> void:
	NetworkManager.connected_players_metadata.clear()
	for metadata in _original_metadata:
		NetworkManager.connected_players_metadata.append(metadata)
	GameState.target_player_count = _original_target_count
	GameState.game_state = _original_state
	multiplayer.multiplayer_peer.refuse_new_connections = _original_refuse_new_connections
	SceneLoading.visible = _original_loading_visible

func _set_peers(peer_ids: Array[int]) -> void:
	NetworkManager.connected_players_metadata.clear()
	for peer_id in peer_ids:
		NetworkManager.connected_players_metadata.append({"peer_id": peer_id})

func test_party_selector_offers_four_five_six_and_survives_reset() -> void:
	var menu := MainScript.new() as Control
	add_child_autofree(menu)
	await get_tree().process_frame

	assert_eq(menu._party_size_buttons.size(), 3, "Lobby menu offers three party sizes")
	assert_eq(menu._party_size_buttons[0].text, "4")
	assert_eq(menu._party_size_buttons[1].text, "5")
	assert_eq(menu._party_size_buttons[2].text, "6")
	var midnight_entry_count := 0
	for button: Button in menu._main.find_children("*", "Button", true, false):
		if button.text == "Midnight Library":
			midnight_entry_count += 1
	assert_eq(midnight_entry_count, 1, "Main menu exposes the Midnight Library entry")
	menu._select_party_size(4)
	assert_eq(GameState.target_player_count, 4, "Selecting four players updates the lobby target")
	menu._select_party_size(5)
	assert_eq(GameState.target_player_count, 5, "Selecting five players updates the lobby target")
	menu._select_party_size(6)
	assert_eq(GameState.target_player_count, 6, "Selecting six players updates the lobby target")
	menu._select_party_size(7)
	assert_eq(GameState.target_player_count, 6, "Unsupported party sizes leave the selected target unchanged")
	var lobby_root := Node.new()
	var lobby_scene := PackedScene.new()
	assert_eq(lobby_scene.pack(lobby_root), OK)
	lobby_root.free()
	GameState.enter_lobby(lobby_scene)
	await get_tree().process_frame
	assert_eq(GameState.target_player_count, 6, "Entering a lobby preserves the selected party size")

	GameState.reset(GameState.State.LOBBY)
	assert_eq(GameState.target_player_count, 6, "Round reset preserves the selected party size")

func test_six_player_target_fills_real_world_player_fixture() -> void:
	_set_peers([1])
	GameState.game_state = GameState.State.LOBBY
	GameState.target_player_count = 6
	var world := WorldFixture.new()
	add_child_autofree(world)
	var players := PlayerListFixture.new(world)
	world.add_child(players)

	players.ensure_bot_count(GameState.target_player_count)

	assert_eq(players.spawned_peer_ids.size(), 5, "One connected player receives five bot companions")
	assert_eq(players.spawned_peer_ids, [-2, -3, -4, -5, -6], "Bot peers fill the selected six-player roster")

	_set_peers([1, 2, 3, 4, 5, 6])
	players.ensure_bot_count(GameState.target_player_count)
	assert_eq(players.spawned_peer_ids, [-2, -3, -4, -5, -6], "A full human roster does not add another bot")

func test_six_production_actors_start_a_real_round() -> void:
	GameState.game_state = GameState.State.LOBBY
	GameState.target_player_count = 6
	var world := Node3D.new()
	add_child_autofree(world)
	for peer_id in range(1, 7):
		var player := PLAYER_SCENE.instantiate() as CharacterBody3D
		player._on_before_spawn({"peer_id": peer_id, "position": Vector3.ZERO})
		world.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var result := GameState.start_game(1)

	assert_eq(result, OK, "The selected six-player roster starts with production actors")
	assert_eq(GameState.participant_peer_ids, [1, 2, 3, 4, 5, 6])
	assert_eq(get_tree().get_nodes_in_group("players").size(), 6)
	assert_eq(GameState.game_state, GameState.State.HIDING)
