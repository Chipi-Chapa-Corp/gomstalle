extends Node3D

@export var start_button: Button
@export var menu: Control
@export var hud: Control

func _ready():
	MultiplayerManager.peer_connected.connect(_on_peer_connected)
	var result = MultiplayerManager.join_multiplayer(multiplayer)
	if result != OK:
		push_error("Error: Failed to create or connect to server " + result)
		# TODO: Show error

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		start_button.visible = true
	Spawner.spawn_entity("player", {"peer_id": peer_id, "position": Vector3.ZERO})

func _on_start_pressed():
	if not MultiplayerManager.is_host:
		return
	start_button.visible = false
	MultiplayerManager.sync_connected_peers(multiplayer)
	var result = GameState.start_game()
	if result != OK:
		push_error("Error: Failed to start game " + result)
		# TODO: Show error

func _unhandled_input(event: InputEvent) -> void:
	if GameState.game_state != "idle" and event.is_action_pressed("menu"):
		menu.visible = not menu.visible
		hud.visible = not hud.visible
		GameState.set_local_paused(menu.visible)

func _on_quit_pressed() -> void:
	GameState.quit()
