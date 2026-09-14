extends Node3D
class_name EchoBellPulse

@export var duration: float = 4.0

const FLOOR_CLEARANCE: float = 0.08

var _elapsed: float = -1.0

func start() -> void:
	var bell := get_parent() as Node3D
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY, bell.global_position + Vector3.UP * FLOOR_CLEARANCE)
	_elapsed = 0.0
	visible = true
	for ring in get_children():
		var mesh := ring as MeshInstance3D
		if mesh == null:
			continue
		mesh.scale = Vector3.ONE * 0.35
		mesh.material_override.set_shader_parameter("opacity", 0.0)

func _ready() -> void:
	for ring in get_children():
		var mesh := ring as MeshInstance3D
		if mesh == null or mesh.material_override == null:
			continue
		mesh.material_override = mesh.material_override.duplicate()
	visible = false

func _process(delta: float) -> void:
	if _elapsed < 0.0:
		return
	_elapsed += delta
	var progress := _elapsed / duration
	if progress >= 1.0:
		_elapsed = -1.0
		visible = false
		return
	for index in get_child_count():
		var mesh := get_child(index) as MeshInstance3D
		if mesh == null:
			continue
		var phase := fmod(progress + float(index) * 0.25, 1.0)
		mesh.scale = Vector3.ONE * lerpf(0.35, 5.5, phase)
		var fade := (1.0 - phase) * (1.0 - phase)
		mesh.material_override.set_shader_parameter("opacity", fade * 0.74)
