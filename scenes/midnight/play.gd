extends Node
class_name MidnightPlay

signal return_to_film

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/scene.tscn")
const DISPLAY_FONT: FontFile = preload("res://assets/fonts/MedievalSharp-Regular.ttf")
const ROOM_BOUNDS := AABB(Vector3(-8.0, 0.0, -11.0), Vector3(16.0, 9.0, 22.0))
const PLAYER_SPAWN := Vector3(0.0, 0.2, 7.0)
const UPPER_GALLERY_WISP := Vector3(-5.8, 5.1, -6.0)
const SERVING_HATCH_WISP := Vector3(-4.2, 1.2, -2.5)
const CENTRAL_WISP := Vector3(0.0, 1.2, -2.0)
const WISP_POSITIONS: Array[Vector3] = [
	UPPER_GALLERY_WISP,
	SERVING_HATCH_WISP,
	CENTRAL_WISP,
]
const AWAKEN_POSITION := Vector3(0.0, 0.0, -3.0)
const WISP_REACH := 1.3
const AWAKEN_REACH := 1.7
const CAMERA_OFFSET := Vector3(0.0, 3.0, 5.5)
const CAMERA_FOCUS_HEIGHT := 1.1
const CAMERA_FOV := 62.0
const CAMERA_COLLISION_MARGIN := 0.2

var stage: Node3D
var camera: Camera3D
var player: CharacterBody3D
var actors: Node3D
var wisps: Array[Node3D] = []
var wisp_positions: Array[Vector3] = WISP_POSITIONS.duplicate()
var collected_wisps: Array[int] = []
var library_awake := false
var is_active := false

var ui: CanvasLayer
var status_label: Label
var controls_label: Label
var replay_control: Button

var _awakening_effect: Node3D
var _pulse_time := 0.0
var _collection_flash := 0.0
var _previous_game_state: GameState.State
var _previous_paused := false
var _previous_portal_cinematic := false
var _global_state_saved := false
var _previous_camera_transform := Transform3D.IDENTITY
var _previous_camera_fov := 0.0
var _previous_camera_current := false
var _camera_state_saved := false
var _previous_player_hud_visible := false

func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)

func begin(stage: Node3D, camera: Camera3D) -> void:
	if is_active:
		finish()
	self.stage = stage
	self.camera = camera
	_save_global_state()
	_save_camera_state()
	_prepare_global_state()
	actors = Node3D.new()
	actors.name = "MidnightPlayActors"
	stage.add_child(actors)
	_spawn_player()
	_spawn_wisps()
	_spawn_awakening_effect()
	_build_ui()
	is_active = true
	set_process(true)
	set_process_unhandled_input(true)
	_update_camera()
	_update_ui()

func finish() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	if is_instance_valid(replay_control) and replay_control.pressed.is_connected(_on_replay_pressed):
		replay_control.pressed.disconnect(_on_replay_pressed)
	if is_instance_valid(ui):
		ui.free()
	if is_instance_valid(player):
		player.camera.current = false
		player.hud.visible = _previous_player_hud_visible
	if is_instance_valid(actors):
		actors.free()
	if _camera_state_saved and is_instance_valid(camera):
		camera.global_transform = _previous_camera_transform
		camera.fov = _previous_camera_fov
		camera.current = _previous_camera_current
	if _global_state_saved:
		GameState.game_state = _previous_game_state
		GameState.is_paused = _previous_paused
		GameState.portal_cinematic_active = _previous_portal_cinematic
	is_active = false
	wisps.clear()
	collected_wisps.clear()
	library_awake = false
	_collection_flash = 0.0
	_global_state_saved = false
	_camera_state_saved = false

func _process(delta: float) -> void:
	if not is_active:
		return
	_pulse_time += delta
	_collection_flash = maxf(_collection_flash - delta, 0.0)
	_update_wisps()
	_update_camera()
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		return_to_film.emit()
		return
	if key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_try_interact()

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player._on_before_spawn({"peer_id": multiplayer.get_unique_id(), "position": PLAYER_SPAWN})
	actors.add_child(player)
	player.position = PLAYER_SPAWN
	player.is_hunter = false
	player.looks.sync_skin()
	_previous_player_hud_visible = player.hud.visible
	player.camera.current = false
	player.hud.visible = false
	player.camera_utils.camera_yaw_offset = 0.0
	player.camera.rotation.y = 0.0

func _spawn_wisps() -> void:
	for wisp_index in wisp_positions.size():
		var wisp := Node3D.new()
		wisp.name = "MidnightWisp%d" % (wisp_index + 1)
		wisp.position = wisp_positions[wisp_index]
		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.14
		sphere.height = 0.38
		sphere.radial_segments = 16
		sphere.rings = 8
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("73e8e2")
		material.emission_enabled = true
		material.emission = Color("4fdad8")
		material.emission_energy_multiplier = 3.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.mesh = sphere
		mesh_instance.material_override = material
		wisp.add_child(mesh_instance)
		var light := OmniLight3D.new()
		light.light_color = Color("5edbdc")
		light.light_energy = 0.65
		light.omni_range = 2.8
		wisp.add_child(light)
		actors.add_child(wisp)
		wisps.append(wisp)

func _spawn_awakening_effect() -> void:
	_awakening_effect = Node3D.new()
	_awakening_effect.name = "LibraryAwakening"
	_awakening_effect.position = AWAKEN_POSITION + Vector3.UP * 0.04
	_awakening_effect.visible = false
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.05
	cylinder.bottom_radius = 1.05
	cylinder.height = 0.025
	cylinder.radial_segments = 32
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4fc9d0")
	material.emission_enabled = true
	material.emission = Color("45d9e0")
	material.emission_energy_multiplier = 2.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.76
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material
	_awakening_effect.add_child(mesh_instance)
	var light := OmniLight3D.new()
	light.light_color = Color("55dce0")
	light.light_energy = 1.4
	light.omni_range = 4.0
	_awakening_effect.add_child(light)
	actors.add_child(_awakening_effect)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "MidnightPlayUI"
	ui.layer = 20
	add_child(ui)
	var panel := PanelContainer.new()
	panel.name = "StatusPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 32.0
	panel.offset_top = -178.0
	panel.offset_right = 430.0
	panel.offset_bottom = -32.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.08, 0.88)
	panel_style.border_color = Color(0.25, 0.79, 0.82, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var title := _make_label(tr("Midnight Library"), 28, Color("c5f6ed"))
	column.add_child(title)
	status_label = _make_label("", 21, Color("e6f4ef"))
	column.add_child(status_label)
	controls_label = _make_label(tr("WASD Move  ·  Shift Sprint  ·  Space Jump  ·  F Air slide (airborne)  ·  E Gather"), 16, Color("9ebbb8"))
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(controls_label)
	replay_control = Button.new()
	replay_control.name = "Replay"
	replay_control.text = tr("Replay")
	replay_control.custom_minimum_size.y = 34.0
	replay_control.visible = false
	replay_control.pressed.connect(_on_replay_pressed)
	column.add_child(replay_control)

func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _update_wisps() -> void:
	for wisp_index in wisps.size():
		if collected_wisps.has(wisp_index):
			continue
		var phase := _pulse_time * 2.4 + float(wisp_index) * 1.8
		var wisp := wisps[wisp_index]
		wisp.position = wisp_positions[wisp_index] + Vector3.UP * (sin(phase) * 0.12)
		var scale_value := 1.0 + sin(phase * 1.35) * 0.14
		wisp.scale = Vector3.ONE * scale_value

func _update_camera() -> void:
	var focus_position := player.global_position + Vector3.UP * CAMERA_FOCUS_HEIGHT
	var desired_position := player.global_position + CAMERA_OFFSET
	var safe_position := desired_position
	var query := PhysicsRayQueryParameters3D.create(focus_position, desired_position, 1)
	query.exclude = [player.get_rid()]
	var hit := stage.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position := hit["position"] as Vector3
		var distance_to_hit := focus_position.distance_to(hit_position) - CAMERA_COLLISION_MARGIN
		var camera_direction := focus_position.direction_to(desired_position)
		safe_position = focus_position + camera_direction * maxf(distance_to_hit, 0.6)
	camera.global_position = safe_position
	camera.look_at(focus_position, Vector3.UP)
	camera.fov = CAMERA_FOV
	if not camera.current:
		camera.make_current()

func _update_ui() -> void:
	if library_awake:
		status_label.text = tr("The library is awake.")
		controls_label.text = tr("Tab Return to film")
		replay_control.visible = true
		return
	if collected_wisps.size() == wisp_positions.size():
		status_label.text = tr("Wisps %d / %d · Reach the orrery") % [collected_wisps.size(), wisp_positions.size()]
		controls_label.text = tr("E Awaken the library")
	else:
		status_label.text = tr("Wisps %d / %d") % [collected_wisps.size(), wisp_positions.size()]
		controls_label.text = tr("WASD Move  ·  Shift Sprint  ·  Space Jump  ·  F Air slide (airborne)  ·  E Gather")
	replay_control.visible = false
	if _collection_flash > 0.0:
		status_label.modulate = Color(0.7, 1.0, 0.95, 1.0)
	else:
		status_label.modulate = Color.WHITE

func _try_interact() -> void:
	if library_awake:
		return
	var nearest_wisp_index := -1
	var nearest_distance := WISP_REACH
	for wisp_index in wisps.size():
		if collected_wisps.has(wisp_index):
			continue
		var distance := player.global_position.distance_to(wisp_positions[wisp_index])
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_wisp_index = wisp_index
	if nearest_wisp_index >= 0:
		_collect_wisp(nearest_wisp_index)
		return
	if collected_wisps.size() == wisp_positions.size() and player.global_position.distance_to(AWAKEN_POSITION) <= AWAKEN_REACH:
		_awaken_library()

func _collect_wisp(wisp_index: int) -> void:
	if collected_wisps.has(wisp_index):
		return
	collected_wisps.append(wisp_index)
	wisps[wisp_index].visible = false
	_collection_flash = 0.35

func _awaken_library() -> void:
	library_awake = true
	_awakening_effect.visible = true
	_update_ui()

func _on_replay_pressed() -> void:
	library_awake = false
	collected_wisps.clear()
	_pulse_time = 0.0
	_collection_flash = 0.0
	for wisp_index in wisps.size():
		wisps[wisp_index].visible = true
		wisps[wisp_index].position = wisp_positions[wisp_index]
		wisps[wisp_index].scale = Vector3.ONE
	_awakening_effect.visible = false
	player.position = PLAYER_SPAWN
	player.velocity = Vector3.ZERO
	player.movement.reset()
	player.camera_utils.camera_yaw_offset = 0.0
	_update_ui()

func _save_global_state() -> void:
	_previous_game_state = GameState.game_state
	_previous_paused = GameState.is_paused
	_previous_portal_cinematic = GameState.portal_cinematic_active
	_global_state_saved = true

func _prepare_global_state() -> void:
	if not GameState.can_player_act(multiplayer.get_unique_id()):
		GameState.game_state = GameState.State.LOBBY
	GameState.is_paused = false
	GameState.portal_cinematic_active = false

func _save_camera_state() -> void:
	_previous_camera_transform = camera.global_transform
	_previous_camera_fov = camera.fov
	_previous_camera_current = camera.current
	_camera_state_saved = true
