extends Node
class_name CharacterForces

var character: CharacterBody3D

func _init(node: CharacterBody3D) -> void:
	character = node

func handle(delta: float) -> void:
	var gravity_scale := 0.25 if character.movement.is_air_sliding else 1.0
	character.velocity.y -= character.gravity * gravity_scale * delta

	for collision_index in range(character.get_slide_collision_count()):
		var collision = character.get_slide_collision(collision_index)
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		if collider != null and collider.is_in_group("stunning") and collider.get_can_stun(character, normal):
			var stun_time: float = collider.ally_stun_time if character.peer_id == GameState.hunter_peer_id else collider.enemy_stun_time
			character.request_stun(stun_time)
			collider.on_stun()

	if character.is_stunned or character.is_dead:
		character.velocity.x = 0.0
		character.velocity.z = 0.0

func set_dead(state: bool) -> void:
	character.is_dead = state
	character.actions.cancel_attack()
	if character.is_dead:
		character.playback.travel("Death_A", true)
	else:
		character.playback.travel("Ressurrect_A", true)
