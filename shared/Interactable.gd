extends PhysicsBody3D

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

func do_interact(_enable: bool, _payload: Dictionary) -> void:
	assert(false, "Interactable requires do_interact override")

# === INTERACTION (client requests, host decides, all execute) ===
func notice(enable: bool):
	set_show_outline(enable)

func interact(enable: bool, metadata: Dictionary):
	rpc_id(1, "_interact_request", enable, metadata)

@rpc("any_peer", "call_local", "reliable")
func _interact_request(enable: bool, metadata: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	var payload := _build_authoritative_payload(enable, metadata, sender_id)
	if not _can_interact(enable, payload):
		return
	rpc("_execute_interaction", enable, payload)

@rpc("authority", "call_local", "reliable")
func _execute_interaction(enable: bool, payload: Dictionary) -> void:
	if not get_is_static():
		set_show_outline(false)
	var local_payload := payload.duplicate(true)
	local_payload["caller"] = resolve_player(int(payload["peer_id"]))
	do_interact(enable, local_payload)

# === INTERACTION HOOKS ===
func _can_interact(_enable: bool, _payload: Dictionary) -> bool:
	return true

func _build_authoritative_payload(_enable: bool, metadata: Dictionary, sender_id: int) -> Dictionary:
	var payload := metadata.duplicate(true)
	payload["peer_id"] = sender_id
	payload.erase("hand")
	payload.erase("target")
	return payload

func resolve_player(peer_id: int) -> CharacterBody3D:
	for node in get_tree().get_nodes_in_group("players"):
		if node.get("peer_id") == peer_id:
			return node
	return null

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
