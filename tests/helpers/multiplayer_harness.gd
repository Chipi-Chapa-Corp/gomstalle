extends Node

class_name MultiplayerHarness

const WorldScene = preload("res://scenes/world/scene.tscn")
const MultiplayerManagerScript = preload("res://globals/MultiplayerManager.gd")
const SpawnerScript = preload("res://globals/Spawner.gd")

const CAPTURE_WIDTH := 480
const CAPTURE_HEIGHT := 270
const CAPTURE_LABEL_HEIGHT := 72
const CAPTURE_LABEL_FONT_SIZE := 26

var host_root: Node
var client_root: Node
var host_world: Node
var client_world: Node
var host_manager: Node
var client_manager: Node
var host_spawner: Node
var client_spawner: Node
var host_multiplayer: SceneMultiplayer
var client_multiplayer: SceneMultiplayer
var host_player: Node3D
var client_player: Node3D
var host_peer_id: int
var client_peer_id: int
var host_remote_player: Node3D
var client_remote_player: Node3D
var visual_capture_enabled := false
var visual_capture_active := false
var visual_capture_root: Node
var visual_capture_host_viewport: SubViewport
var visual_capture_client_viewport: SubViewport
var visual_capture_label_viewport: SubViewport
var visual_capture_label: Label
var visual_capture_frames_dir := ""
var visual_capture_index := 0
var visual_capture_fps := 30
var visual_capture_accum := 0.0
var visual_capture_ui_max_percent := 0.2
var visual_capture_ui_pending := false
var visual_capture_pending_frame := false
var visual_capture_ui_pending_frames := 0
var visual_capture_ui_pending_limit := 10
var visual_capture_padding_seconds := 0.5

func setup(port: int) -> void:
	Settings.network_backend = NetworkConfig.BACKEND_LOCAL
	Settings.local_host = "127.0.0.1"
	Settings.local_port = port
	Settings.local_max_clients = 2

	host_root = Node.new()
	host_root.name = "HostRoot"
	client_root = Node.new()
	client_root.name = "ClientRoot"
	add_child(host_root)
	add_child(client_root)
	_setup_visual_capture()

	host_multiplayer = SceneMultiplayer.new()
	client_multiplayer = SceneMultiplayer.new()
	host_multiplayer.root_path = host_root.get_path()
	client_multiplayer.root_path = client_root.get_path()
	get_tree().set_multiplayer(host_multiplayer, host_root.get_path())
	get_tree().set_multiplayer(client_multiplayer, client_root.get_path())

	host_spawner = SpawnerScript.new()
	client_spawner = SpawnerScript.new()
	host_root.add_child(host_spawner)
	client_root.add_child(client_spawner)

	await get_tree().process_frame

	host_manager = MultiplayerManagerScript.new()
	host_manager.is_host = true
	host_root.add_child(host_manager)

	client_manager = MultiplayerManagerScript.new()
	client_manager.is_host = false
	client_root.add_child(client_manager)

	host_world = WorldScene.instantiate()
	_strip_scatter_nodes(host_world)
	host_world.set("spawner", host_spawner)
	host_world.set("multiplayer_manager", host_manager)
	host_root.add_child(host_world)

	await get_tree().process_frame

	client_world = WorldScene.instantiate()
	_strip_scatter_nodes(client_world)
	client_world.set("spawner", client_spawner)
	client_world.set("multiplayer_manager", client_manager)
	client_root.add_child(client_world)

func setup_with_players(port: int, frames: int) -> void:
	await setup(port)
	await wait_for_peer_count(2, frames)

	await wait_for_physics_condition(
		func():
			return (
				get_authority_player(host_world.player_container) != null
				and get_authority_player(client_world.player_container) != null
			),
		frames,
		"authority_players_ready"
	)

	host_player = get_authority_player(host_world.player_container)
	client_player = get_authority_player(client_world.player_container)
	assert(host_player != null)
	assert(client_player != null)

	host_peer_id = int(host_player.get("peer_id"))
	client_peer_id = int(client_player.get("peer_id"))

	await wait_for_physics_condition(
		func():
			return (
				get_player_by_peer_id(host_world.player_container, client_peer_id) != null
				and get_player_by_peer_id(client_world.player_container, host_peer_id) != null
			),
		frames,
		"replicated_players_ready"
	)

	host_remote_player = get_player_by_peer_id(host_world.player_container, client_peer_id)
	client_remote_player = get_player_by_peer_id(client_world.player_container, host_peer_id)
	assert(host_remote_player != null)
	assert(client_remote_player != null)

func wait_for_peer_count(expected_count: int, frames: int) -> void:
	var waited := 0
	var max_frames = _adjust_wait_frames(frames)
	while waited < max_frames:
		if host_manager.get_connected_peer_ids().size() == expected_count and client_manager.get_connected_peer_ids().size() == expected_count:
			return
		await get_tree().process_frame
		waited += 1
	assert(false, "Timed out waiting for peers")

func wait_for_condition(predicate: Callable, frames: int) -> void:
	var waited := 0
	var max_frames = _adjust_wait_frames(frames)
	while waited < max_frames:
		if predicate.call():
			return
		await get_tree().process_frame
		waited += 1
	assert(false, "Timed out waiting for condition")

func wait_for_physics_condition(predicate: Callable, frames: int, label: String) -> void:
	var waited := 0
	var max_frames = _adjust_wait_frames(frames)
	while waited < max_frames:
		if predicate.call():
			return
		await get_tree().physics_frame
		waited += 1
	assert(false, "Timed out waiting for condition: %s" % label)

func _adjust_wait_frames(frames: int) -> int:
	if not visual_capture_active:
		return frames
	return int(ceil(float(frames) * 3.0))

func get_player_by_peer_id(container: Node, peer_id: int) -> Node3D:
	for child in container.get_children():
		var candidate = child as Node3D
		if candidate == null:
			continue
		if candidate.get("peer_id") == peer_id:
			return candidate
	return null

func get_authority_player(container: Node) -> Node3D:
	for child in container.get_children():
		var candidate = child as Node3D
		if candidate == null:
			continue
		if candidate.is_multiplayer_authority():
			return candidate
	return null

func disable_player_physics(world: Node) -> void:
	var container = world.get("player_container") as Node
	assert(container != null)
	for child in container.get_children():
		child.set_physics_process(false)
		child.set_process_input(false)

func cleanup() -> void:
	var host_peer = host_multiplayer.multiplayer_peer
	var client_peer = client_multiplayer.multiplayer_peer
	assert(host_peer != null)
	assert(client_peer != null)
	visual_capture_active = false
	host_multiplayer.multiplayer_peer = null
	client_multiplayer.multiplayer_peer = null
	host_multiplayer = null
	client_multiplayer = null
	host_root.process_mode = Node.PROCESS_MODE_DISABLED
	client_root.process_mode = Node.PROCESS_MODE_DISABLED
	host_peer.close()
	client_peer.close()
	await get_tree().process_frame
	host_root.free()
	client_root.free()
	await get_tree().process_frame
	await _clear_orphan_nodes()

func _clear_orphan_nodes() -> void:
	var orphan_ids = Node.get_orphan_node_ids()
	for orphan_id in orphan_ids:
		var orphan = instance_from_id(orphan_id)
		if orphan != null:
			orphan.free()
	await get_tree().process_frame
func _strip_scatter_nodes(world: Node) -> void:
	var scatter = world.get_node_or_null("Background/ProtonScatter")
	if scatter != null:
		scatter.free()

func _process(delta: float) -> void:
	if not visual_capture_active:
		return
	if visual_capture_ui_pending:
		visual_capture_ui_pending_frames += 1
		visual_capture_ui_pending = _apply_capture_ui_scale()
		if visual_capture_ui_pending and visual_capture_ui_pending_frames < visual_capture_ui_pending_limit:
			return
		visual_capture_ui_pending = false
	if visual_capture_pending_frame:
		if _capture_frame():
			visual_capture_pending_frame = false
	visual_capture_accum += delta
	var interval = 1.0 / float(visual_capture_fps)
	if visual_capture_accum < interval:
		return
	visual_capture_accum -= interval
	_capture_frame()

func start_visual_capture(test_name: String, fps: int = 30) -> void:
	if not visual_capture_enabled:
		return
	visual_capture_active = true
	visual_capture_fps = fps if fps > 0 else _get_capture_fps()
	visual_capture_accum = 0.0
	visual_capture_index = 0
	visual_capture_frames_dir = _prepare_capture_dirs(test_name)
	_set_label_text(test_name)
	visual_capture_ui_max_percent = _get_capture_ui_max_percent()
	visual_capture_ui_pending = _apply_capture_ui_scale()
	visual_capture_pending_frame = true
	visual_capture_ui_pending_frames = 0
	visual_capture_padding_seconds = _get_capture_padding_seconds()

func stop_visual_capture() -> void:
	visual_capture_active = false

func is_visual_capture_enabled() -> bool:
	return visual_capture_enabled

func _is_visual_capture_enabled() -> bool:
	var value = OS.get_environment("GOMSTALLE_TEST_VIDEO").strip_edges().to_lower()
	return value == "1" or value == "true"

func _get_capture_fps() -> int:
	var value = OS.get_environment("GOMSTALLE_TEST_VIDEO_FPS")
	var fps = int(value)
	return fps if fps > 0 else 30

func _get_capture_ui_max_percent() -> float:
	var value = OS.get_environment("GOMSTALLE_TEST_VIDEO_UI_MAX_PERCENT")
	var percent = float(value)
	if percent <= 0.0 or percent > 1.0:
		return 0.2
	return percent

func _get_capture_padding_seconds() -> float:
	var value = OS.get_environment("GOMSTALLE_TEST_VIDEO_PADDING_SECONDS")
	var seconds = float(value)
	if seconds <= 0.0:
		return 0.5
	return seconds

func wait_for_visual_capture_padding(seconds: float = -1.0) -> void:
	if not visual_capture_active:
		return
	var padding = seconds if seconds >= 0.0 else visual_capture_padding_seconds
	if padding <= 0.0:
		return
	var target_frames = int(ceil(padding * float(visual_capture_fps)))
	var start_index = visual_capture_index
	var waited = 0
	var max_frames = _adjust_wait_frames(target_frames + 60)
	while waited < max_frames:
		if visual_capture_index - start_index >= target_frames:
			return
		await get_tree().process_frame
		waited += 1

func _setup_visual_capture() -> void:
	if not _is_visual_capture_enabled():
		return
	visual_capture_enabled = true
	visual_capture_root = Node.new()
	visual_capture_root.name = "VisualCapture"
	add_child(visual_capture_root)
	visual_capture_host_viewport = _create_capture_viewport("HostViewport", CAPTURE_WIDTH, CAPTURE_HEIGHT)
	visual_capture_client_viewport = _create_capture_viewport("ClientViewport", CAPTURE_WIDTH, CAPTURE_HEIGHT)
	visual_capture_label_viewport = _create_label_viewport("LabelViewport", CAPTURE_WIDTH, CAPTURE_LABEL_HEIGHT)
	visual_capture_root.add_child(visual_capture_host_viewport)
	visual_capture_root.add_child(visual_capture_client_viewport)
	visual_capture_root.add_child(visual_capture_label_viewport)
	if host_root.get_parent() != null:
		host_root.get_parent().remove_child(host_root)
	visual_capture_host_viewport.add_child(host_root)
	if client_root.get_parent() != null:
		client_root.get_parent().remove_child(client_root)
	visual_capture_client_viewport.add_child(client_root)

func _create_capture_viewport(name: String, width: int, height: int) -> SubViewport:
	var viewport = SubViewport.new()
	viewport.name = name
	viewport.size = Vector2i(width, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.transparent_bg = false
	viewport.own_world_3d = true
	return viewport

func _create_label_viewport(name: String, width: int, height: int) -> SubViewport:
	var viewport = SubViewport.new()
	viewport.name = name
	viewport.size = Vector2i(width, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.transparent_bg = false
	var root = Control.new()
	root.size = Vector2(width, height)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	var background = ColorRect.new()
	background.size = Vector2(width, height)
	background.color = Color(0, 0, 0, 1)
	root.add_child(background)
	visual_capture_label = Label.new()
	visual_capture_label.text = ""
	visual_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_capture_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visual_capture_label.add_theme_font_size_override("font_size", CAPTURE_LABEL_FONT_SIZE)
	visual_capture_label.size = Vector2(width, height)
	visual_capture_label.anchor_right = 1.0
	visual_capture_label.anchor_bottom = 1.0
	root.add_child(visual_capture_label)
	viewport.add_child(root)
	return viewport

func _set_label_text(text: String) -> void:
	if visual_capture_label != null:
		visual_capture_label.text = text

func _prepare_capture_dirs(test_name: String) -> String:
	var root = _get_capture_root_dir()
	DirAccess.make_dir_recursive_absolute(root)
	var test_dir = root.path_join(test_name)
	DirAccess.make_dir_recursive_absolute(test_dir)
	var frames_dir = test_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var dir = DirAccess.open(frames_dir)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return frames_dir

func _get_capture_root_dir() -> String:
	var root = OS.get_environment("GOMSTALLE_TEST_VIDEO_DIR")
	if root.is_empty():
		root = "user://test_videos"
	return ProjectSettings.globalize_path(root)

func _capture_frame() -> bool:
	if visual_capture_frames_dir.is_empty():
		return false
	var host_image = visual_capture_host_viewport.get_texture().get_image()
	var client_image = visual_capture_client_viewport.get_texture().get_image()
	var label_image = visual_capture_label_viewport.get_texture().get_image()
	if host_image == null or client_image == null or label_image == null:
		return false
	host_image.convert(Image.FORMAT_RGBA8)
	client_image.convert(Image.FORMAT_RGBA8)
	label_image.convert(Image.FORMAT_RGBA8)
	var total_height = CAPTURE_HEIGHT * 2 + CAPTURE_LABEL_HEIGHT
	var final_image = Image.create(CAPTURE_WIDTH, total_height, false, Image.FORMAT_RGBA8)
	final_image.blit_rect(host_image, Rect2i(0, 0, CAPTURE_WIDTH, CAPTURE_HEIGHT), Vector2i(0, 0))
	final_image.blit_rect(client_image, Rect2i(0, 0, CAPTURE_WIDTH, CAPTURE_HEIGHT), Vector2i(0, CAPTURE_HEIGHT))
	final_image.blit_rect(label_image, Rect2i(0, 0, CAPTURE_WIDTH, CAPTURE_LABEL_HEIGHT), Vector2i(0, CAPTURE_HEIGHT * 2))
	var file_name = "frame_%06d.png" % visual_capture_index
	var output_path = visual_capture_frames_dir.path_join(file_name)
	final_image.save_png(output_path)
	visual_capture_index += 1
	return true

func _apply_capture_ui_scale() -> bool:
	var pending = false
	var viewport_size = Vector2(float(CAPTURE_WIDTH), float(CAPTURE_HEIGHT))
	if host_world != null:
		pending = _scale_control_to_percent(host_world.get("start_button") as Control, viewport_size) or pending
		pending = _scale_control_to_percent(host_world.get("player_list") as Control, viewport_size) or pending
	if client_world != null:
		pending = _scale_control_to_percent(client_world.get("start_button") as Control, viewport_size) or pending
		pending = _scale_control_to_percent(client_world.get("player_list") as Control, viewport_size) or pending
	if host_player != null:
		pending = _scale_control_to_percent(host_player.get("stamina_bar") as Control, viewport_size) or pending
		pending = _scale_control_to_percent(host_player.get("inventory_wood_label") as Control, viewport_size) or pending
	if client_player != null:
		pending = _scale_control_to_percent(client_player.get("stamina_bar") as Control, viewport_size) or pending
		pending = _scale_control_to_percent(client_player.get("inventory_wood_label") as Control, viewport_size) or pending
	return pending

func _scale_control_to_percent(control: Control, viewport_size: Vector2) -> bool:
	if control == null:
		return false
	var size = _get_control_size(control)
	if size.x <= 0.0 or size.y <= 0.0:
		return true
	var max_width = viewport_size.x * visual_capture_ui_max_percent
	var max_height = viewport_size.y * visual_capture_ui_max_percent
	var scale = 1.0
	if size.x > 0.0:
		scale = minf(scale, max_width / size.x)
	if size.y > 0.0:
		scale = minf(scale, max_height / size.y)
	_apply_control_scale(control, scale)
	return false

func _get_control_size(control: Control) -> Vector2:
	var size = control.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = control.get_combined_minimum_size()
	return size

func _apply_control_scale(control: Control, scale: float) -> void:
	if is_equal_approx(scale, 1.0):
		control.scale = Vector2.ONE
		return
	var reference_point = _get_reference_point(control)
	var original_transform = control.get_global_transform()
	var reference_global = original_transform * reference_point
	control.scale = Vector2(scale, scale)
	var scaled_transform = control.get_global_transform()
	var scaled_reference_global = scaled_transform * reference_point
	var delta = reference_global - scaled_reference_global
	control.global_position += delta

func _get_reference_point(control: Control) -> Vector2:
	var size = _get_control_size(control)
	return Vector2(
		_get_reference_component(control.anchor_left, control.anchor_right, size.x),
		_get_reference_component(control.anchor_top, control.anchor_bottom, size.y)
	)

func _get_reference_component(anchor_min: float, anchor_max: float, size: float) -> float:
	if not is_equal_approx(anchor_min, anchor_max):
		return 0.0
	if anchor_min <= 0.0:
		return 0.0
	if anchor_min >= 1.0:
		return size
	return size * 0.5
