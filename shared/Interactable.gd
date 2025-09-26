extends StaticBody3D

class_name Interactable

const outline_src: ShaderMaterial = preload("res://materials/outline.tres")

var local_material: Material
var local_outline: ShaderMaterial

func _ready():
	init_outline()

# === ABSTRACT ===
func get_outline_target() -> MeshInstance3D:
	return null

func get_is_static() -> bool:
	return true

func perform_interact(_enable: bool, _metadata: Dictionary) -> void:
	assert(false, "Interactable requires perform_interact override")

# === INTERACTION ===
func notice(enable: bool):
	set_show_outline(enable)

func interact(enable: bool, metadata: Dictionary):
	if not multiplayer.is_server():
		rpc_id(1, "request_interact", enable, metadata)
		return

	if not get_is_static():
		set_show_outline(false)

	perform_interact(enable, metadata)

@rpc("any_peer", "reliable")
func request_interact(enable: bool, metadata: Dictionary) -> void:
	if multiplayer.is_server():
		interact(enable, metadata)

# === OUTLINES ===
func init_outline():
	var instance := get_outline_target()
	if instance != null:
		local_outline = outline_src.duplicate(true)
		local_outline.resource_local_to_scene = true

		var base := instance.mesh.surface_get_material(0)
		local_material = base.duplicate(true)
		local_material.resource_local_to_scene = true
		instance.set_surface_override_material(0, local_material)

		local_outline.set_shader_parameter("outline_color", Color(1, 1, 1, .3))
		local_outline.set_shader_parameter("outline_width", 2)

func set_show_outline(enable: bool):
	if local_outline != null:
		local_material.next_pass = local_outline if enable else null