extends Interactable

@export var mesh: MeshInstance3D
@export var transformer: RemoteTransform3D
@export var collision_shape: CollisionShape3D
@export var destroy_effect: GPUParticles3D

@onready var collision_shadow: CollisionShape3D = collision_shape.duplicate()
@onready var collision_layer_enabled := collision_layer
@onready var _chair = self
@onready var chair: RigidBody3D = _chair

@export var min_stun_impact: float = 6.0
@export var ally_stun_time: float = 0.2
@export var enemy_stun_time: float = 1.0

const THROW_SPEED := 18.0
const HOLDER_COLLISION_RELEASE_DISTANCE := 2.5
@export var can_stun := false

var collision_ignore_target: CharacterBody3D
var last_stun_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	super._ready()
	chair.contact_monitor = true
	chair.max_contacts_reported = 4
	chair.collision_mask |= 1 << 1
	chair.continuous_cd = true

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return false

func get_hunter_can_interact() -> bool:
	return false

func get_can_stun(target: CharacterBody3D, normal: Vector3) -> bool:
	var relative_velocity = chair.linear_velocity - target.velocity
	var impact = relative_velocity.dot(normal.normalized())
	return impact >= min_stun_impact

func _release_holder(target: CharacterBody3D) -> void:
	if target == null:
		return
	if collision_shadow.get_parent() == target:
		target.remove_child(collision_shadow)
	transformer.remote_path = ""
	collision_ignore_target = target

func on_stun() -> void:
	rpc("sync_on_stun")

@rpc("any_peer", "call_local", "reliable")
func sync_on_stun() -> void:
	get_parent().queue_free()

func on_attacked() -> void:
	rpc("sync_on_attacked")

@rpc("any_peer", "call_local", "reliable")
func sync_on_attacked() -> void:
	destroy_effect.emitting = true
	collision_shape.disabled = true
	mesh.visible = false
	await get_tree().create_timer(destroy_effect.lifetime).timeout
	get_parent().queue_free()

func _physics_process(_delta: float) -> void:
	_update_collision_ignore()
	if can_stun:
		_try_stun_collisions(last_stun_velocity)
		last_stun_velocity = chair.linear_velocity

func _update_collision_ignore() -> void:
	if collision_ignore_target == null:
		return
	if chair.global_position.distance_to(collision_ignore_target.global_position) <= HOLDER_COLLISION_RELEASE_DISTANCE:
		return
	remove_collision_exception_with(collision_ignore_target)
	collision_ignore_target = null

func _try_stun_collisions(previous_velocity: Vector3) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not multiplayer.is_server():
		return
	var impact_velocity = previous_velocity
	if chair.linear_velocity.length() > impact_velocity.length():
		impact_velocity = chair.linear_velocity
	var bodies = chair.get_colliding_bodies()
	for body in bodies:
		if body is not CharacterBody3D:
			continue
		var target = _resolve_collision_target(body as CharacterBody3D)
		if target == null:
			continue
		if collision_ignore_target != null and target == collision_ignore_target:
			continue
		var impact = (impact_velocity - target.velocity).length()
		if impact < min_stun_impact:
			continue
		var peer_id_value = target.get("peer_id")
		var peer_id = int(peer_id_value) if peer_id_value != null else target.get_multiplayer_authority()
		var is_hunter = peer_id == GameState.hunter_peer_id
		var stun_time = ally_stun_time if is_hunter else enemy_stun_time
		can_stun = false
		target.rpc("apply_stun", stun_time)
		on_stun()
		return

func _resolve_target(metadata: Dictionary) -> CharacterBody3D:
	var resolved = Utils.resolve_node(metadata.get("target")) as CharacterBody3D
	var peer_id_value = metadata.get("peer_id")
	if peer_id_value == null:
		return resolved
	var peer_id = int(peer_id_value)
	if resolved != null and resolved.get("peer_id") == peer_id and resolved.get_multiplayer() == multiplayer:
		return resolved
	var candidate = Utils.find_player_in_branch(peer_id, multiplayer)
	if candidate != null:
		return candidate
	assert(false, "Failed to resolve chair holder for peer")
	return null

func _resolve_collision_target(body: CharacterBody3D) -> CharacterBody3D:
	if body.get_multiplayer() == multiplayer:
		return body
	var peer_id_value = body.get("peer_id")
	if peer_id_value == null:
		return null
	return Utils.find_player_in_branch(int(peer_id_value), multiplayer)

func _resolve_hand(metadata: Dictionary, target: CharacterBody3D) -> RemoteTransform3D:
	if target != null:
		var target_hand = target.get("hand") as RemoteTransform3D
		if target_hand != null and target_hand.get_multiplayer() == multiplayer:
			return target_hand
	var resolved = Utils.resolve_node(metadata.get("hand")) as RemoteTransform3D
	if resolved != null and resolved.get_multiplayer() == multiplayer:
		return resolved
	assert(false, "Failed to resolve chair hand for peer")
	return null

func perform_interact(enable: bool, metadata: Dictionary):
	var interaction_data := metadata.duplicate(true)
	var target: CharacterBody3D = _resolve_target(interaction_data)
	var hand: RemoteTransform3D = _resolve_hand(interaction_data, target)
	if hand == null:
		return
	interaction_data["transform"] = chair.global_transform
	if not enable:
		var throw_direction: Vector3 = interaction_data.get("direction", Vector3.ZERO)
		var throw_velocity := Vector3.ZERO
		if throw_direction != Vector3.ZERO:
			throw_velocity = throw_direction.normalized() * THROW_SPEED
		interaction_data["linear_velocity"] = throw_velocity
		interaction_data["angular_velocity"] = Vector3(randf() * 4.0, randf() * 4.0, randf() * 4.0)
	_apply_interaction(enable, hand, target, interaction_data)
	rpc("sync_interaction", enable, interaction_data)

@rpc("any_peer", "reliable")
func sync_interaction(enable: bool, metadata: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var target: CharacterBody3D = _resolve_target(metadata)
	var hand: RemoteTransform3D = _resolve_hand(metadata, target)
	if hand == null:
		return
	_apply_interaction(enable, hand, target, metadata)

func _apply_interaction(enable: bool, hand: RemoteTransform3D, target: CharacterBody3D, metadata: Dictionary) -> void:
	var chair_transform: Transform3D = metadata.get("transform", chair.global_transform)
	chair.global_transform = chair_transform
	if enable:
		can_stun = false
		last_stun_velocity = Vector3.ZERO
		chair.freeze = true
		hand.remote_path = get_path()
		_set_collision_exclusion(target, true)
		chair.collision_layer = 1 << 0
		return
	chair.freeze = false
	hand.remote_path = ""
	_release_holder(target)
	chair.collision_layer = collision_layer_enabled
	chair.linear_velocity = metadata.get("linear_velocity", Vector3.ZERO)
	chair.angular_velocity = metadata.get("angular_velocity", Vector3.ZERO)
	can_stun = true
	last_stun_velocity = chair.linear_velocity
	_exclude_foreign_players()

func _set_collision_exclusion(target: CharacterBody3D, enable: bool) -> void:
	if target == null:
		return
	if enable:
		add_collision_exception_with(target)
		if collision_shadow.get_parent() != target:
			if collision_shadow.get_parent() != null:
				collision_shadow.get_parent().remove_child(collision_shadow)
			target.add_child(collision_shadow)
		transformer.remote_path = collision_shadow.get_path()
		return
	remove_collision_exception_with(target)
	if collision_shadow.get_parent() == target:
		target.remove_child(collision_shadow)
	transformer.remote_path = ""

func _exclude_foreign_players() -> void:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate = node as CharacterBody3D
		if candidate == null:
			continue
		if candidate.get_multiplayer() != multiplayer:
			add_collision_exception_with(candidate)
