class_name MidnightDirector
extends RefCounted

const DURATION := 38.0
const SHOT_STARTS := [0.0, 6.0, 11.0, 16.0, 21.0, 27.0, 32.0]
const SHOT_NAMES := ["The sleeping library", "A curious soul", "The keeper", "Borrowed time", "Awakening", "One last leap", "Midnight"]

var camera: Camera3D
var skeleton: MidnightActor
var knight: MidnightActor
var attributes := CameraAttributesPractical.new()
var magic_strength := 0.0
var title_opacity := 0.0
var shot_index := 0

func configure(film_camera: Camera3D, hider: MidnightActor, hunter: MidnightActor) -> void:
	camera = film_camera
	skeleton = hider
	knight = hunter
	attributes.dof_blur_near_enabled = true
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_amount = 0.1
	camera.attributes = attributes

func evaluate(time: float) -> void:
	skeleton.visible = true
	knight.visible = false
	magic_strength = 0.12
	title_opacity = 0.0
	shot_index = 0
	for index in SHOT_STARTS.size():
		if time >= SHOT_STARTS[index]:
			shot_index = index
	var local_time: float = time - SHOT_STARTS[shot_index]
	match shot_index:
		0: _library(local_time)
		1: _curiosity(local_time)
		2: _keeper(local_time)
		3: _chase(local_time)
		4: _awakening(local_time)
		5: _leap(local_time)
		6: _title(local_time)

func _camera(position: Vector3, target: Vector3, fov: float, focus: Vector3, softness: float = 0.1) -> void:
	camera.position = position
	camera.look_at(target)
	camera.fov = fov
	var distance := camera.position.distance_to(focus)
	attributes.dof_blur_near_distance = maxf(0.1, distance - 1.2)
	attributes.dof_blur_near_transition = 1.4
	attributes.dof_blur_far_distance = distance + 2.5
	attributes.dof_blur_far_transition = 7.0
	attributes.dof_blur_amount = softness

func _library(time: float) -> void:
	var progress := smoothstep(0.0, 6.0, time)
	skeleton.position = Vector3(1.2, 0.06, lerpf(2.0, -1.4, time / 6.0))
	skeleton.face(Vector3.FORWARD)
	skeleton.pose(&"Walking_D_Skeletons", time * 0.6)
	_camera(Vector3(-0.7, 4.0, 9.6).lerp(Vector3(0.9, 3.8, 8.8), progress), Vector3(0, 2.8, -5.7), 51.0, Vector3(0, 3, -4), 0.0)

func _curiosity(time: float) -> void:
	var progress := smoothstep(0.0, 5.0, time)
	skeleton.position = Vector3(0.15, 0.06, -1.5)
	skeleton.face(Vector3(-0.12, 0, -1))
	skeleton.pose(&"Idle_B", time * 0.7)
	var focus := skeleton.position + Vector3(0, 1.7, 0)
	_camera(Vector3(-2.6, 1.8, -4.2).lerp(Vector3(-1.9, 1.95, -3.7), progress), focus + Vector3(0.15, 0.0, 0), 37.0, focus, 0.19)
	magic_strength = 0.2 + 0.1 * sin(time)

func _keeper(time: float) -> void:
	skeleton.visible = false
	knight.visible = true
	knight.position = Vector3(-2.4, 0.06, lerpf(6.5, 3.6, smoothstep(0.0, 4.2, time)))
	knight.face(Vector3.FORWARD)
	knight.pose(&"Walking_A" if time < 4.2 else &"Idle", time * 0.65)
	var focus := knight.position + Vector3(0, 1.55, 0)
	_camera(Vector3(-0.35, 0.95, -0.7).lerp(Vector3(-0.85, 1.05, 0), time / 5.0), focus + Vector3(0, 0.1, 0), 40.0, focus, 0.16)

func _chase(time: float) -> void:
	knight.visible = true
	var progress := time / 5.0
	skeleton.position = Vector3(1.45 + 0.55 * sin(time * 1.1), 0.06, lerpf(5.0, -2.4, progress))
	knight.position = Vector3(0.4 + 0.35 * sin(time * 1.1), 0.06, lerpf(8.2, 0.8, progress))
	skeleton.face(Vector3(0.6 * cos(time * 1.1), 0, -1.48))
	knight.face(Vector3(0.385 * cos(time * 1.1), 0, -1.48))
	skeleton.pose(&"Running_A", time * 0.9)
	knight.pose(&"Running_A", time * 0.82)
	var focus := skeleton.position + Vector3(-0.35, 1.2, 0.65)
	_camera(skeleton.position + Vector3(1.0, 7.8, 7.0), focus, 55.0, focus, 0.0)
	magic_strength = 0.22

func _awakening(time: float) -> void:
	skeleton.position = Vector3(0.25, 0.06, -2.4)
	skeleton.face(Vector3.FORWARD)
	skeleton.pose(&"Spellcast_Raise" if time < 2.1 else &"Spellcasting", time)
	magic_strength = lerpf(0.2, 1.0, smoothstep(0.1, 4.0, time))
	var progress := smoothstep(0.0, 6.0, time)
	_camera(Vector3(-2.4, 3.5, 3.4).lerp(Vector3(-2.8, 4.6, 4.8), progress), Vector3(0, 1.95, -3.9), 54.0, Vector3(0, 2.2, -4), 0.05)

func _leap(time: float) -> void:
	knight.visible = true
	knight.position = Vector3(-0.6, 0.06, 0)
	knight.face(Vector3.BACK)
	knight.pose(&"Hit_A" if time < 0.7 else &"Idle", time)
	var progress := clampf(time / 3.8, 0, 1)
	skeleton.position = Vector3(1.25, 0.06, lerpf(-1.7, 8.9, progress))
	var jump := clampf((time - 1.0) / 1.2, 0, 1)
	if jump > 0 and jump < 1:
		skeleton.position.y += sin(jump * PI) * 1.2
		skeleton.pose(&"Jump_Full_Short", jump * 1.15)
	else:
		skeleton.pose(&"Running_A", time * 1.15)
	skeleton.face(Vector3.BACK)
	var focus := skeleton.position + Vector3(0, 1.25, 0)
	_camera(Vector3(4.2, 1.25, 6.0), Vector3(0.8, 1.6, 1.2).lerp(focus, minf(0.5, time / 8.0)), 58.0, focus, 0.1)
	magic_strength = 1.0

func _title(time: float) -> void:
	skeleton.visible = false
	knight.visible = false
	var progress := smoothstep(0.0, 6.0, time)
	_camera(Vector3(0, 3.5, 8.3).lerp(Vector3(0, 4, 9.4), progress), Vector3(0, 4.2, -7), 52.0, Vector3(0, 3, -5), 0.0)
	magic_strength = 0.8
	title_opacity = smoothstep(0.5, 2.0, time) * (1.0 - smoothstep(5.5, 6.0, time))
