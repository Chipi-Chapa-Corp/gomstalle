extends Node3D
class_name EscapePortal

@export var visuals: Node3D
@export var reveal_root: Node3D
@export var portal_surface: MeshInstance3D
@export var steady_particles: GPUParticles3D
@export var burst_particles: GPUParticles3D
@export var portal_light: OmniLight3D
@export var idle_light_energy := 0.85

var _portal_material: ShaderMaterial
var _is_open := false
var _is_settled := false
var _idle_time := 0.0

func _ready() -> void:
	assert(visuals != null)
	assert(reveal_root != null)
	assert(portal_surface != null)
	assert(steady_particles != null)
	assert(burst_particles != null)
	assert(portal_light != null)
	var surface_material := portal_surface.get_active_material(0)
	assert(surface_material is ShaderMaterial)
	_portal_material = (surface_material as ShaderMaterial).duplicate() as ShaderMaterial
	portal_surface.material_override = _portal_material
	_set_reveal_progress(0.0)
	reveal_root.position.y = -0.08
	reveal_root.scale = Vector3(0.82, 0.35, 0.82)
	steady_particles.emitting = false
	burst_particles.emitting = false
	portal_light.light_energy = 0.0

func _process(delta: float) -> void:
	if not _is_settled:
		return
	_idle_time += delta
	portal_light.light_energy = idle_light_energy * (1.0 + sin(_idle_time * 1.8) * 0.08)

func fit_to_size(portal_size: float) -> void:
	var surface_mesh := portal_surface.mesh as QuadMesh
	assert(surface_mesh != null)
	var base_size := maxf(surface_mesh.size.x, surface_mesh.size.y)
	visuals.scale = Vector3.ONE * portal_size / base_size

func open(duration: float) -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	steady_particles.emitting = true
	burst_particles.emitting = true
	burst_particles.restart()

	var reveal_tween := create_tween().set_parallel(true)
	reveal_tween.tween_method(_set_reveal_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(reveal_root, "position:y", 0.0, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(reveal_root, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	var light_tween := create_tween()
	light_tween.tween_property(portal_light, "light_energy", idle_light_energy * 1.8, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	light_tween.tween_property(portal_light, "light_energy", idle_light_energy, duration * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await reveal_tween.finished
	_is_settled = true

func _set_reveal_progress(progress: float) -> void:
	_portal_material.set_shader_parameter("reveal_progress", progress)
