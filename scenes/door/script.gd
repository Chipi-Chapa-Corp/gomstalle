extends Interactable
class_name Door

const ANIMATION_DURATION := 0.45
const OPEN_DEGREES := 90.0

@onready var ORIENTATION := "horizontal" if get_parent().rotation.y == 0 else "vertical"

@export var mesh: MeshInstance3D
@export var body: AnimatableBody3D
@export var audio_player: AudioStreamPlayer3D

var _open_target_degrees := 0.0
@export var open_target_degrees: float:
	set(value):
		if is_equal_approx(_open_target_degrees, value):
			return
		_open_target_degrees = value
		if not is_node_ready():
			return
		_animate_to(value)
	get:
		return _open_target_degrees

var _rotation_tween: Tween

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _ready() -> void:
	super._ready()
	body.rotation_degrees.y = open_target_degrees

func get_outline_target() -> MeshInstance3D:
	return mesh

func get_is_static() -> bool:
	return true

func get_hunter_can_interact() -> bool:
	return true

func do_interact(_enable: bool, payload: Dictionary) -> void:
	if not is_multiplayer_authority():
		return
	var player_position: Vector3 = payload.get("position", Vector3.ZERO)
	var door_position: Vector3 = body.global_transform.origin
	var axis_value: float = (player_position.z - door_position.z) if ORIENTATION == "horizontal" else (player_position.x - door_position.x)
	var is_open := not is_equal_approx(open_target_degrees, 0.0)
	open_target_degrees = 0.0 if is_open else signf(axis_value) * OPEN_DEGREES

func _animate_to(target: float) -> void:
	audio_player.play()
	if _rotation_tween:
		_rotation_tween.kill()
	_rotation_tween = get_tree().create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_rotation_tween.tween_property(body, "rotation_degrees:y", target, ANIMATION_DURATION)
