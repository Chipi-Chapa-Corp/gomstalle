extends Node
class_name CharacterPortalIndicatorUtils

const Compass := preload("res://scenes/player/portal_compass.gd")

var character: CharacterBody3D
var compass: PortalCompass

func _init(node: CharacterBody3D) -> void:
	character = node

func _ready() -> void:
	if character.is_local_player():
		var canvas := CanvasLayer.new()
		canvas.layer = 4
		add_child(canvas)
		compass = Compass.new()
		canvas.add_child(compass)
		compass.hide()

func update_portal_indicator(_delta: float) -> void:
	character.portal_indicator.visible = false
	character.portal_indicator_through_walls.visible = false
	if not _should_show_portal_indicator():
		compass.hide()
		return
	compass.update_guidance(GameState.portal_position, character.global_position, character.camera)

# HELPERS

func _should_show_portal_indicator() -> bool:
	if not character.camera.current:
		return false
	if not GameState.portal_active:
		return false
	if character.camera_utils.camera_override_active:
		return false
	if character.is_dead or GameState.escaped_peer_ids.has(character.peer_id):
		return false
	return true
