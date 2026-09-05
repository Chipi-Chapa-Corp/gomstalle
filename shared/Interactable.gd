extends PhysicsBody3D

class_name Interactable

const outline_src: ShaderMaterial = preload("res://materials/outline.tres")

var local_material: Material
var local_outline: ShaderMaterial
var _next_interaction_time: Dictionary[int, int] = {}

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
	var player := resolve_player(sender_id)
	if player == null:
		return
	_execute_player_request(player, enable, metadata)

func interact_for_player(player: CharacterBody3D, enable: bool) -> void:
	if multiplayer.is_server() and player.is_bot:
		_execute_player_request(player, enable, {})

func release_from(player: CharacterBody3D) -> void:
	if not multiplayer.is_server() or player.item != self:
		return
	var payload := _build_authoritative_payload(false, {}, player.peer_id)
	payload["linear_velocity"] = Vector3.ZERO
	payload["angular_velocity"] = Vector3.ZERO
	_execute_interaction.rpc(false, payload)

func _execute_player_request(player: CharacterBody3D, enable: bool, metadata: Dictionary) -> void:
	if not can_player_interact(player, enable):
		return
	var peer_id: int = player.peer_id
	var now := Time.get_ticks_msec()
	if now < _next_interaction_time.get(peer_id, 0):
		return
	var payload := _build_authoritative_payload(enable, metadata, peer_id)
	if not _can_interact(enable, payload):
		return
	_next_interaction_time[peer_id] = now + 300
	rpc("_execute_interaction", enable, payload)

func can_player_interact(player: CharacterBody3D, enable: bool) -> bool:
	if player.is_dead or player.is_stunned or not GameState.can_player_act(player.peer_id):
		return false
	if player.is_hunter and not get_hunter_can_interact():
		return false
	if not enable:
		return player.item == self
	if not get_is_static() and (player.item != null or get_is_carried()):
		return false
	var offset := global_position - player.global_position
	if absf(offset.y) > 2.0 or Vector2(offset.x, offset.z).length() > player.interact_radius + 0.75:
		return false
	var origin := player.global_position + Vector3.UP * 0.8
	var destination := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, [player.get_rid(), get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or get_parent().is_ancestor_of(hit["collider"])

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

func get_hunter_can_interact() -> bool:
	return false

func get_is_carried() -> bool:
	return false

func _build_authoritative_payload(_enable: bool, metadata: Dictionary, sender_id: int) -> Dictionary:
	var payload := metadata.duplicate(true)
	payload["peer_id"] = sender_id
	var player := resolve_player(sender_id)
	payload["position"] = player.global_position
	payload["direction"] = player.model.global_basis.z.normalized()
	payload["amount"] = 1
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
