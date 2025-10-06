extends Node
class_name CharacterLooks

var character: CharacterBody3D

func _init(node: CharacterBody3D) -> void:
	character = node

func sync_skin() -> void:
	var new_parts = character.hunter_parts if character.is_hunter else character.hider_parts
	var old_parts = character.hunter_parts if not character.is_hunter else character.hider_parts
	old_parts.visible = false
	new_parts.visible = true
	character.label.modulate = character.hunter_color if character.is_hunter else character.hider_color

func enable_wall_highlights(parts: Node3D) -> void:
	if character.is_multiplayer_authority():
		for part in parts.get_children():
			if part is MeshInstance3D:
				var override = part.get_active_material(0).duplicate() as BaseMaterial3D
				override.next_pass = character.wall_through_material_override
				override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				part.set_surface_override_material(0, override)
			elif part is BoneAttachment3D:
				enable_wall_highlights(part)