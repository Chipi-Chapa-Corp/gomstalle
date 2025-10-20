extends Node3D

@export var start_button: Button
@export var menu: Control
@export var hud: Control
@export var player_container: Node
@export var player_list: VBoxContainer
@export var player_list_item_sample: Control
@onready var player_list_item_sample_persistent: Control = player_list_item_sample.duplicate()

func _ready():
	player_list_item_sample_persistent.visible = true
	Spawner.set_path(player_container.get_path())
	MultiplayerManager.peer_connected.connect(_on_peer_connected)
	MultiplayerManager.peer_list_changed.connect(_on_peer_list_changed)
	var result := MultiplayerManager.join_multiplayer(multiplayer)
	if result != OK:
		push_error("Error: Failed to create or connect to server")
		# TODO: Show error

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		start_button.visible = true
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})

func _on_peer_list_changed(peers: Array[Dictionary]) -> void:
	for child in player_list.get_children():
		player_list.remove_child(child)
	for peer in peers:
		var item = player_list_item_sample_persistent.duplicate()
		item.get_node("Container/Label").text = peer["name"]
		player_list.add_child(item)

func _on_start_pressed():
	if not MultiplayerManager.is_host:
		return
	start_button.visible = false
	MultiplayerManager.sync_connected_peers(multiplayer)
	var result := GameState.start_game()
	if result != OK:
		push_error("Error: Failed to start game")
		# TODO: Show error

func _unhandled_input(event: InputEvent) -> void:
	if GameState.game_state != GameState.State.IDLE and event.is_action_pressed("menu"):
		menu.visible = not menu.visible
		hud.visible = not hud.visible
		GameState.set_local_paused(menu.visible)

func _on_quit_pressed() -> void:
	GameState.quit(multiplayer)

func _exit_tree() -> void:
	MultiplayerManager.peer_connected.disconnect(_on_peer_connected)
	MultiplayerManager.peer_list_changed.disconnect(_on_peer_list_changed)