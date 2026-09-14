extends "res://scenes/chair/script.gd"
class_name EchoBell

const BELL_THROW_SPEED: float = 17.0
const RING_DURATION: float = 4.0
const LANDING_SPEED: float = 2.8
const LANDING_TIMEOUT: float = 3.0
const CHIME_HEARING_RADIUS: float = 24.0

@export var pulse: EchoBellPulse
@export var chime: AudioStreamPlayer3D

var is_ringing: bool = false
var remaining_ring_time: float = 0.0

var _pending_activation: bool = false
var _throw_age: float = 0.0
var _activated: bool = false

static func is_valid_activation_sender(sender_id: int, authority_id: int) -> bool:
	return sender_id == 0 or sender_id == authority_id

func _ready() -> void:
	super._ready()
	add_to_group("echo_bells")

func get_can_stun(_target: CharacterBody3D, _normal: Vector3) -> bool:
	return false

func on_stun() -> void:
	return

func on_attacked() -> void:
	if _activated:
		return
	if multiplayer.is_server():
		_activate_from_strike(multiplayer.get_unique_id())
		return
	_strike_request.rpc_id(1)

@rpc("authority", "call_local", "reliable")
func sync_on_attacked() -> void:
	return

@rpc("any_peer", "call_local", "reliable")
func _strike_request() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	_activate_from_strike(sender_id)

func _activate_from_strike(sender_id: int) -> void:
	var player := resolve_player(sender_id)
	if player == null or not player.is_hunter or player.is_dead or player.is_stunned:
		return
	if not GameState.can_player_act(player.peer_id) or not player.can_reach_attack(self):
		return
	_activate_echo.rpc(global_position)

func can_player_interact(player: CharacterBody3D, enable: bool) -> bool:
	if _activated:
		return false
	return super.can_player_interact(player, enable)

func _build_authoritative_payload(enable: bool, metadata: Dictionary, sender_id: int) -> Dictionary:
	var payload := super._build_authoritative_payload(enable, metadata, sender_id)
	if not enable:
		var throw_direction: Vector3 = payload.get("direction", Vector3.ZERO)
		payload["linear_velocity"] = throw_direction.normalized() * BELL_THROW_SPEED if throw_direction != Vector3.ZERO else Vector3.ZERO
		payload["angular_velocity"] = Vector3(randf_range(-3.2, 3.2), randf_range(-3.2, 3.2), randf_range(-3.2, 3.2))
	return payload

func do_interact(enable: bool, payload: Dictionary) -> void:
	var launched: bool = not enable and payload.get("linear_velocity", Vector3.ZERO).length_squared() > 0.25
	super.do_interact(enable, payload)
	can_stun = false
	if multiplayer.is_server() and launched and not _activated:
		_pending_activation = true
		_throw_age = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	can_stun = false
	if not multiplayer.is_server() or not _pending_activation or _activated:
		return
	_throw_age += delta
	if _throw_age > LANDING_TIMEOUT:
		_pending_activation = false
		return
	if _throw_age < 0.12 or chair.get_contact_count() == 0:
		return
	if not chair.sleeping and chair.linear_velocity.length_squared() > LANDING_SPEED * LANDING_SPEED:
		return
	_pending_activation = false
	_activate_echo.rpc(global_position)

func _process(delta: float) -> void:
	if not is_ringing:
		return
	remaining_ring_time = maxf(0.0, remaining_ring_time - delta)
	if remaining_ring_time == 0.0:
		is_ringing = false
		_finish_echo()

@rpc("authority", "call_local", "reliable")
func _activate_echo(world_position: Vector3) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if not is_valid_activation_sender(sender_id, get_multiplayer_authority()):
		return
	if _activated:
		return
	_activated = true
	_pending_activation = false
	global_position = world_position
	is_ringing = true
	remaining_ring_time = RING_DURATION
	chair.freeze = true
	chair.collision_layer = 0
	collision_shape.disabled = true
	set_show_outline(false)
	if pulse != null:
		pulse.start()
	if chime != null:
		chime.play()
	get_tree().create_timer(RING_DURATION).timeout.connect(_finish_echo)

func _finish_echo() -> void:
	var bell_scene := get_parent()
	if is_instance_valid(bell_scene):
		bell_scene.queue_free()
