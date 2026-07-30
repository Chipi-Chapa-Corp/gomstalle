extends Interactable

const DIAL_COUNT := 3
const TARGET_WIDTH := 0.18
const SLIDER_SPEED := 2.6

@export var mesh: MeshInstance3D
@export var focus: Marker3D
@export var interaction_light: OmniLight3D
@export var preview_fov := 28.0
@export var preview_camera_offset := Vector3(3.8, 5.4, 6.4)
@export var zoom_duration := 0.55
@export var return_duration := 0.4

var is_previewing := false
var is_task_active := false
var is_completed := false
var current_dial_index := 0
var slider_time := 0.0
var displayed_target_center := 0.64
var input_enabled_at := 0
var local_caller: CharacterBody3D
var task_layer: CanvasLayer
var task_root: Control
var task_bar: ColorRect
var target_zone: ColorRect
var slider_marker: ColorRect
var task_label: Label
var dial_rotations := [0.42, -0.76, 0.68]
var target_centers := [0.64, 0.38, 0.72]
var highlight_tween: Tween

@onready var dials: Array[Node3D] = [$TopDial, $LeftDial, $RightDial]

func _ready() -> void:
	super._ready()
	for index in DIAL_COUNT:
		dials[index].rotation.z = dial_rotations[index]
		_set_dial_color(index, Color(0.03, 0.42, 0.53, 1.0))
	_create_task_ui()

func _process(delta: float) -> void:
	if not is_task_active:
		return
	slider_time += delta
	_update_task_ui()
	if Time.get_ticks_msec() < input_enabled_at:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_end_task()
	elif Input.is_action_just_pressed("interact"):
		_check_timing()

func get_outline_target() -> MeshInstance3D:
	return null

func notice(enable: bool) -> void:
	super.notice(false)
	if highlight_tween:
		highlight_tween.kill()
	highlight_tween = create_tween()
	highlight_tween.tween_property(interaction_light, "light_energy", 0.42 if enable else 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_set_ring_highlight(enable)

func get_is_static() -> bool:
	return true

func get_hunter_can_interact() -> bool:
	return false

func do_interact(_enable: bool, payload: Dictionary) -> void:
	var caller: CharacterBody3D = payload.get("caller")
	if caller == null or not caller.is_multiplayer_authority() or is_previewing or is_completed:
		return
	is_previewing = true
	local_caller = caller
	GameState.portal_cinematic_active = true
	var damping_time_constant := SmoothDamp.damping_time_constant_for_progress_fraction(zoom_duration)
	var camera_offset := global_transform.basis * preview_camera_offset
	caller.camera_utils.set_camera_override_with_offset(focus.global_position, camera_offset, preview_fov, damping_time_constant)
	await get_tree().create_timer(zoom_duration).timeout
	if is_previewing:
		_start_task()

func _start_task() -> void:
	is_task_active = true
	current_dial_index = 0
	slider_time = 0.0
	displayed_target_center = target_centers[current_dial_index]
	input_enabled_at = Time.get_ticks_msec() + 180
	task_root.visible = true
	_update_task_ui()

func _check_timing() -> void:
	var slider_position := _get_slider_position()
	if absf(slider_position - target_centers[current_dial_index]) <= TARGET_WIDTH * 0.5:
		_complete_dial()
	else:
		_fail_dial()

func _complete_dial() -> void:
	input_enabled_at = Time.get_ticks_msec() + 350
	_set_dial_color(current_dial_index, Color(0.08, 0.8, 1.0, 1.0))
	var dial := dials[current_dial_index]
	var tween := create_tween()
	tween.tween_property(dial, "rotation:z", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_dial_index += 1
	if current_dial_index < DIAL_COUNT:
		_move_target_to(target_centers[current_dial_index])
		_update_task_ui()
		return
	_finish_task()

func _fail_dial() -> void:
	input_enabled_at = Time.get_ticks_msec() + 480
	_set_dial_color(current_dial_index, Color(0.82, 0.18, 0.14, 1.0))
	var dial := dials[current_dial_index]
	dial_rotations[current_dial_index] += 0.22 if current_dial_index % 2 == 0 else -0.22
	var tween := create_tween()
	tween.tween_property(dial, "rotation:z", dial_rotations[current_dial_index], 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.4).timeout
	if is_task_active and current_dial_index < DIAL_COUNT:
		_set_dial_color(current_dial_index, Color(0.03, 0.42, 0.53, 1.0))

func _finish_task() -> void:
	task_label.text = "RUNE LOCK UNSEALED"
	await get_tree().create_timer(0.55).timeout
	if multiplayer.multiplayer_peer == null:
		_apply_completion()
	else:
		rpc_id(1, "_request_completion")
	_end_task()

@rpc("any_peer", "call_local", "reliable")
func _request_completion() -> void:
	if multiplayer.is_server():
		rpc("_apply_completion")

@rpc("authority", "call_local", "reliable")
func _apply_completion() -> void:
	is_completed = true
	for index in DIAL_COUNT:
		dials[index].rotation.z = 0.0
		_set_dial_color(index, Color(0.08, 0.8, 1.0, 1.0))

func _end_task() -> void:
	if not is_previewing:
		return
	is_task_active = false
	task_root.visible = false
	if local_caller != null:
		local_caller.camera_utils.clear_camera_override()
		local_caller.camera_utils.set_temporary_camera_damping_time_constant(SmoothDamp.damping_time_constant_for_progress_fraction(return_duration), return_duration)
	GameState.portal_cinematic_active = false
	is_previewing = false

func _get_slider_position() -> float:
	return 0.5 + sin(slider_time * SLIDER_SPEED) * 0.5

func _move_target_to(target_center: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_displayed_target_center, displayed_target_center, target_center, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_displayed_target_center(target_center: float) -> void:
	displayed_target_center = target_center

func _set_dial_color(index: int, color: Color) -> void:
	for child in dials[index].get_children():
		if child is MeshInstance3D and child.name != "Back" and child.name != "Ring":
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.emission_enabled = false
			material.roughness = 0.35
			child.set_surface_override_material(0, material)

func _set_ring_highlight(enable: bool) -> void:
	var ring_color := Color(0.17, 0.42, 0.5, 1.0) if enable else Color(0.105, 0.14, 0.145, 1.0)
	for dial in dials:
		var ring: MeshInstance3D = dial.get_node("Ring")
		var material := StandardMaterial3D.new()
		material.albedo_color = ring_color
		material.roughness = 0.5
		ring.set_surface_override_material(0, material)

func _create_task_ui() -> void:
	task_layer = CanvasLayer.new()
	task_layer.layer = 40
	add_child(task_layer)
	task_root = Control.new()
	task_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	task_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_layer.add_child(task_root)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -264.0
	panel.offset_top = -154.0
	panel.offset_right = 264.0
	panel.offset_bottom = -82.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.035, 0.055, 0.07, 0.96)
	frame_style.border_color = Color(0.37, 0.55, 0.6, 1.0)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", frame_style)
	task_root.add_child(panel)
	task_bar = ColorRect.new()
	task_bar.color = Color(0.01, 0.02, 0.03, 1.0)
	task_bar.position = Vector2(12.0, 12.0)
	task_bar.size = Vector2(504.0, 48.0)
	panel.add_child(task_bar)
	target_zone = ColorRect.new()
	target_zone.color = Color(0.08, 0.5, 0.68, 1.0)
	target_zone.size = Vector2(92.0, 48.0)
	task_bar.add_child(target_zone)
	slider_marker = ColorRect.new()
	slider_marker.color = Color(0.95, 0.8, 0.34, 1.0)
	slider_marker.size = Vector2(8.0, 60.0)
	slider_marker.position.y = -6.0
	task_bar.add_child(slider_marker)
	task_label = Label.new()
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	task_label.offset_left = -264.0
	task_label.offset_top = -194.0
	task_label.offset_right = 264.0
	task_label.offset_bottom = -164.0
	task_label.add_theme_font_size_override("font_size", 18)
	task_root.add_child(task_label)
	var task_hint := Label.new()
	task_hint.text = "PRESS [E] OR CLICK IN THE BLUE WINDOW"
	task_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	task_hint.offset_left = -264.0
	task_hint.offset_top = -76.0
	task_hint.offset_right = 264.0
	task_hint.offset_bottom = -52.0
	task_hint.modulate = Color(0.72, 0.8, 0.82, 1.0)
	task_hint.add_theme_font_size_override("font_size", 14)
	task_root.add_child(task_hint)
	task_root.visible = false

func _update_task_ui() -> void:
	if current_dial_index >= DIAL_COUNT:
		return
	target_zone.position.x = displayed_target_center * task_bar.size.x - target_zone.size.x * 0.5
	slider_marker.position.x = _get_slider_position() * task_bar.size.x - slider_marker.size.x * 0.5
	task_label.text = "RUNE LOCK  -  ALIGN %d / %d" % [current_dial_index + 1, DIAL_COUNT]
