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
@export var portal_camera_focus_duration: float = 2.5
@export var portal_tile_slide_duration: float = 1.5
@export var portal_tile_slide_distance_multiplier: float = 1.0
@export var portal_depth_offset: float = 0.05
@onready var player_list_item_sample_persistent: Control = player_list_item_sample.duplicate()

class PortalCandidate:
	var cell: Vector3i
	var item_id: int
	var position: Vector3

	func _init(cell: Vector3i, item_id: int, position: Vector3) -> void:
		self.cell = cell
		self.item_id = item_id
		self.position = position

var shrine_nodes: Array[Node] = []
var shrine_total := 0
var shrine_filled := 0
var portal_triggered := false

func _ready():
	player_list_item_sample_persistent.visible = true
	Spawner.set_path(player_container.get_path())
	MultiplayerManager.peer_connected.connect(_on_peer_connected)
	MultiplayerManager.peer_list_changed.connect(_on_peer_list_changed)
	var result := MultiplayerManager.join_multiplayer(multiplayer)
	if result != OK:
		push_error("Error: Failed to create or connect to server")
		# TODO: Show error
	_register_shrines()

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
	for shrine in shrine_nodes:
		if is_instance_valid(shrine) and shrine.has_signal("filled"):
			if shrine.is_connected("filled", _on_shrine_filled):
				shrine.disconnect("filled", _on_shrine_filled)

func _register_shrines() -> void:
	shrine_nodes = get_tree().get_nodes_in_group("shrine")
	shrine_total = shrine_nodes.size()
	shrine_filled = 0
	for shrine in shrine_nodes:
		if shrine.has_signal("filled") and not shrine.is_connected("filled", _on_shrine_filled):
			shrine.connect("filled", _on_shrine_filled)

func _on_shrine_filled(_shrine: Node) -> void:
	shrine_filled += 1
	if shrine_filled != shrine_total:
		return
	if multiplayer.is_server():
		_trigger_portal()

func _trigger_portal() -> void:
	if portal_triggered or grid_map == null or grid_map.mesh_library == null:
		return
	var candidates = _collect_floor_candidates()
	if candidates.is_empty():
		return
	var player_positions = _get_player_positions()
	var candidate_positions: Array[Vector3] = []
	for candidate in candidates:
		candidate_positions.append(candidate.position)
	var best_index = Utils.select_farthest_candidate_index(candidate_positions, player_positions)
	if best_index < 0:
		return
	var chosen = candidates[best_index]
	spawn_portal.rpc(chosen.cell, chosen.item_id)

@rpc("any_peer", "call_local", "reliable")
func spawn_portal(cell: Vector3i, item_id: int) -> void:
	if portal_triggered:
		return
	portal_triggered = true
	if grid_map == null or grid_map.mesh_library == null or portal_scene == null:
		return
	if portal_container == null:
		portal_container = self
	var tile_mesh = grid_map.mesh_library.get_item_mesh(item_id)
	if tile_mesh == null:
		return
	var cell_transform = _get_cell_global_transform(cell)
	var tile_instance := MeshInstance3D.new()
	tile_instance.mesh = tile_mesh
	tile_instance.global_transform = cell_transform
	portal_container.add_child(tile_instance)
	grid_map.set_cell_item(cell, -1)
	var portal_instance = portal_scene.instantiate()
	portal_container.add_child(portal_instance)
	if portal_instance is Node3D:
		var portal_node: Node3D = portal_instance
		portal_node.visible = false
		portal_node.global_position = cell_transform.origin + Vector3(0, -portal_depth_offset, 0)
		await _run_portal_sequence(tile_instance, portal_node, cell_transform.origin)

func _run_portal_sequence(tile_instance: Node3D, portal_instance: Node3D, portal_position: Vector3) -> void:
	var local_player = _get_local_player()
	if local_player != null:
		local_player.set_camera_override(portal_position)
	await get_tree().create_timer(portal_camera_focus_duration).timeout
	var slide_offset = _get_portal_slide_offset()
	var tween = create_tween()
	tween.tween_property(tile_instance, "global_position", tile_instance.global_position + slide_offset, portal_tile_slide_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	portal_instance.visible = true
	GameState.portal_position = portal_position
	GameState.portal_active = true
	if local_player != null:
		local_player.clear_camera_override()

func _collect_floor_candidates() -> Array[PortalCandidate]:
	var candidates: Array[PortalCandidate] = []
	if grid_map == null or grid_map.mesh_library == null:
		return candidates
	var used_cells: Array[Vector3i] = grid_map.get_used_cells()
	for cell in used_cells:
		var item_id = grid_map.get_cell_item(cell)
		if item_id < 0:
			continue
		var item_name = grid_map.mesh_library.get_item_name(item_id)
		if not item_name.begins_with("floor_"):
			continue
		var position = grid_map.to_global(grid_map.map_to_local(cell))
		candidates.append(PortalCandidate.new(cell, item_id, position))
	return candidates

func _get_player_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for player in player_container.get_children():
		if player is Node3D:
			positions.append(player.global_position)
	return positions

func _get_local_player() -> Node:
	for player in player_container.get_children():
		if player.has_method("is_multiplayer_authority") and player.is_multiplayer_authority():
			return player
	return null

func _get_cell_global_transform(cell: Vector3i) -> Transform3D:
	var local_position = grid_map.map_to_local(cell)
	var local_basis = grid_map.get_cell_item_basis(cell)
	var global_basis = grid_map.global_transform.basis * local_basis
	var global_position = grid_map.to_global(local_position)
	return Transform3D(global_basis, global_position)

func _get_portal_slide_offset() -> Vector3:
	if grid_map == null:
		return Vector3.ZERO
	var direction = grid_map.global_transform.basis.x
	if direction.length() == 0.0:
		direction = Vector3.RIGHT
	return direction.normalized() * grid_map.cell_size.x * portal_tile_slide_distance_multiplier
