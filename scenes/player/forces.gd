extends Node
class_name CharacterForces

var character: CharacterBody3D

func _init(node: CharacterBody3D) -> void:
	character = node

func handle(delta: float) -> void:
	character.velocity.y += -character.gravity * delta

	for i in range(character.get_slide_collision_count()):
		var collision = character.get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		if collider != null and collider.is_in_group("stunning") and collider.get_can_stun(character, normal):
			_stun(collider.ally_stun_time if character.peer_id == GameState.hunter_peer_id else collider.enemy_stun_time)
			collider.on_stun()

	if character.is_stunned or character.is_dead:
		character.velocity = Vector3.ZERO

func _stun(timeout: float) -> void:
	if character.is_dead or character.is_stunned:
		return
	rpc("_sync_stun", timeout)

@rpc("any_peer", "call_local", "reliable")
func _sync_stun(timeout: float) -> void:
	if character.is_dead or character.is_stunned:
		return
	character.stun_effect.play()
	character.is_stunned = true
	character.anim_tree.set("parameters/IW/Walk/blend_position", Vector2.ZERO)
	character.anim_tree.set("parameters/IW/Run/blend_position", Vector2.ZERO)
	character.anim_tree.set("parameters/IW/MovementState/blend_amount", 0.0)
	character.anim_tree.set("parameters/IW/Stun_OS/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await character.get_tree().create_timer(timeout).timeout
	character.is_stunned = false

func set_dead(state: bool) -> void:
	character.is_dead = state
	if character.is_dead:
		character.playback.travel("Death_A", true)
	else:
		character.playback.travel("Ressurrect_A", true)
		await character.get_tree().create_timer(0.6).timeout