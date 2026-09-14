class_name MidnightActor
extends Node3D

var animation_player: AnimationPlayer
var visual: Node3D

func configure(knight: bool) -> void:
	var model_path := "res://assets/models/Knight.glb" if knight else "res://assets/models/Skeleton_Minion.glb"
	visual = load(model_path).instantiate()
	add_child(visual)
	animation_player = visual.get_node("AnimationPlayer")
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if knight and (mesh.name.ends_with("Shield") or mesh.name in [&"1H_Sword_Offhand", &"2H_Sword"]):
			mesh.hide()
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface).duplicate() as StandardMaterial3D
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if knight:
				var cloth := mesh.name == &"Knight_Cape"
				material.metallic = 0.0 if cloth else 0.65
				material.roughness = 0.85 if cloth else 0.3
			else:
				material.roughness = 0.68
				material.metallic_specular = 0.32
				if mesh.name == &"Skeleton_Minion_Eyes":
					material.emission_enabled = true
					material.emission = Color("8bf4dc")
					material.emission_energy_multiplier = 1.8
			mesh.set_surface_override_material(surface, material)
	pose(&"Idle", 0.0)

func pose(animation: StringName, time: float) -> void:
	if animation_player.current_animation != animation:
		animation_player.play(animation)
	animation_player.seek(fposmod(time, animation_player.get_animation(animation).length), true)

func face(direction: Vector3) -> void:
	rotation.y = atan2(direction.x, direction.z)
