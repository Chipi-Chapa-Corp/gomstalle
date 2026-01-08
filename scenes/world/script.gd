extends Node3D

@export var start_button: Button
@export var menu: Control
@export var hud: Control
@export var player_container: Node
@export var player_list: VBoxContainer
@export var player_list_item_sample: Control
@export var grid_map: GridMap
@export var portal_container: Node3D
@export var portal_scene: PackedScene
@export var portal_camera_focus_duration: float = 3.0
@export var portal_tile_slide_duration: float = 1.5
@export var portal_tile_slide_distance_multiplier: float = 1.0
@export var portal_depth_offset: float = 0.05
@export var portal_camera_zoom_fov: float = 55.0
@export var portal_camera_return_duration: float = 1.5
@export var portal_open_hold_duration: float = 1.0

var multiplayer_manager: Node
var spawner: Node
var player_list_utils: WorldPlayerListUtils
var portal_utils: WorldPortalUtils
var shrine_utils: WorldShrineUtils

func _ready():
	if multiplayer_manager == null:
		multiplayer_manager = MultiplayerManager
	if spawner == null:
		spawner = Spawner
	assert(multiplayer_manager != null)
	assert(spawner != null)
	player_list_utils = WorldPlayerListUtils.new(self, spawner)
	portal_utils = WorldPortalUtils.new(self)
	shrine_utils = WorldShrineUtils.new(self)
	player_list_utils.initialize()
	spawner.set_path(player_container.get_path())
	multiplayer_manager.peer_connected.connect(player_list_utils.handle_peer_connected)
	multiplayer_manager.peer_list_changed.connect(player_list_utils.handle_peer_list_changed)
	var result = multiplayer_manager.join_multiplayer(multiplayer)
	if result != OK:
		push_error("Error: Failed to create or connect to server")
	shrine_utils.register_shrines()

func _on_start_pressed():
	if not multiplayer.is_server():
		return
	start_button.visible = false
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
	multiplayer_manager.peer_connected.disconnect(player_list_utils.handle_peer_connected)
	multiplayer_manager.peer_list_changed.disconnect(player_list_utils.handle_peer_list_changed)
	shrine_utils.cleanup()

@rpc("any_peer", "call_local", "reliable")
func spawn_portal(cell: Vector3i, item_id: int) -> void:
	portal_utils.spawn_portal(cell, item_id)
