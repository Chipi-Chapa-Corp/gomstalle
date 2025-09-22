extends Node

var outline_src: ShaderMaterial = preload("res://materials/outline.tres")

func init_outline(instance: MeshInstance3D):
	var local_outline = outline_src.duplicate(true)
	local_outline.resource_local_to_scene = true

	var base := instance.mesh.surface_get_material(0)
	var local_material = base.duplicate(true)
	local_material.resource_local_to_scene = true
	instance.set_surface_override_material(0, local_material)

	local_outline.set_shader_parameter("outline_color", Color(1, 1, 1, .3))
	local_outline.set_shader_parameter("outline_width", 2)

	return func(enable: bool):
		local_material.next_pass = local_outline if enable else null
