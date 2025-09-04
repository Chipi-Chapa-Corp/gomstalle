@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	iterate(scene)
	return scene

func iterate(node: Node) -> void:
	if node != null:
		for child in node.get_children():
			iterate(child)
			if child is MeshInstance3D:
				change_mesh(child)

func change_mesh(node: MeshInstance3D) -> void:
	var base_material = node.get_active_material(0) as BaseMaterial3D
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS