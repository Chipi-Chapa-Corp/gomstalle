extends Node

const CAPTURE_FPS := 12.0
const LABEL_FONT_SIZE := 28

var _capture_enabled := false
var _e2e_enabled := false
var _label := ""
var _capture_dir := ""
var _result_path := ""
var _ready_path := ""
var _ready_written := false
var _frame_index := 0
var _capture_accumulator := 0.0
var _scenario_started := false
var _scenario_done := false

func _ready() -> void:
	var args := OS.get_cmdline_args()
	_capture_enabled = args.has("--capture")
	_e2e_enabled = args.has("--e2e")
	if not _capture_enabled and not _e2e_enabled:
		return

	var label_index := args.find("--label")
	if label_index != -1 and label_index + 1 < args.size():
		_label = args[label_index + 1]
	_capture_dir = OS.get_environment("GOMSTALLE_CAPTURE_DIR")
	_result_path = OS.get_environment("GOMSTALLE_E2E_RESULT")
	_ready_path = OS.get_environment("GOMSTALLE_E2E_READY")

	if _capture_enabled and not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		_add_label_overlay()

func _process(delta: float) -> void:
	if not _capture_enabled and not _e2e_enabled:
		return
	if _e2e_enabled and NetworkManager.is_host():
		if not _ready_written and not _ready_path.is_empty():
			_ready_written = true
			var ready_file := FileAccess.open(_ready_path, FileAccess.WRITE)
			if ready_file != null:
				ready_file.store_string("hosting")
				ready_file.close()
		if not _scenario_done:
			_advance_host_scenario()
	if _capture_enabled and not _capture_dir.is_empty():
		_capture_accumulator += delta
		if _capture_accumulator >= 1.0 / CAPTURE_FPS:
			_capture_accumulator = 0.0
			_capture_frame()

func _capture_frame() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	image.save_png(_capture_dir.path_join("frame_%06d.png" % _frame_index))
	_frame_index += 1

func _add_label_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(140, 44)
	var label := Label.new()
	label.text = _label
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	layer.add_child(panel)
	layer.add_child(label)
	add_child(layer)

func _advance_host_scenario() -> void:
	var world := _find_world()
	if world == null:
		return
	var player_container = world.get("player_container")
	if player_container == null or player_container.get_child_count() < 2:
		return
	if not _scenario_started:
		_scenario_started = true
		world.call("_on_start_pressed")
		return
	if GameState.game_state != GameState.State.STARTED:
		return
	_run_door_demo(world)
	_write_result(world, player_container.get_child_count())
	_scenario_done = true

func _run_door_demo(world: Node) -> void:
	var door := _find_door(world)
	if door == null:
		return
	var host_player := _host_player(world)
	var position = host_player.global_position if host_player != null else Vector3.ZERO
	door.interact(true, {"position": position, "direction": Vector3.FORWARD, "amount": 1})

func _write_result(world: Node, player_count: int) -> void:
	if _result_path.is_empty():
		return
	var door := _find_door(world)
	var summary := {
		"label": _label,
		"player_count": player_count,
		"game_started": GameState.game_state == GameState.State.STARTED,
		"door_opened": door != null and not is_equal_approx(door.get("open_target_degrees"), 0.0),
	}
	var file := FileAccess.open(_result_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary))
		file.close()

func _find_world() -> Node:
	var current := get_tree().current_scene
	if current != null and current.get("player_container") != null:
		return current
	return null

func _find_door(world: Node) -> Node:
	for node in get_tree().get_nodes_in_group("interactible"):
		if node.has_method("get_hunter_can_interact") and node.get_is_static() and node.has_method("do_interact") and "open_target_degrees" in node:
			return node
	return null

func _host_player(world: Node) -> Node3D:
	var host_id := get_tree().get_multiplayer().get_unique_id()
	for node in get_tree().get_nodes_in_group("players"):
		if node.get("peer_id") == host_id:
			return node
	return null
