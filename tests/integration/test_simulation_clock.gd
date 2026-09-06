extends GutTest

const PlayerScene := preload("res://scenes/player/scene.tscn")
var arena: Node3D
var original_state: GameState.State

func before_each() -> void:
	original_state = GameState.game_state
	GameState.reset(GameState.State.STARTED)
	GameState.participant_peer_ids = [1, 2, 3, 4]
	arena = Node3D.new()
	add_child_autofree(arena)

func after_each() -> void:
	GameState.reset(original_state)

func _player(peer_id: int, location: Vector3) -> CharacterBody3D:
	var player: CharacterBody3D = PlayerScene.instantiate()
	player._on_before_spawn({"peer_id": peer_id, "position": location})
	arena.add_child(player)
	player.set_physics_process(false)
	return player

func test_capture_and_second_swing_use_simulated_time() -> void:
	var knight := _player(1, Vector3.ZERO)
	var first_target := _player(2, Vector3(-0.6, 0, 1.5))
	var second_target := _player(3, Vector3(0.6, 0, 1.5))
	knight.is_hunter = true
	GameState.hunter_peer_id = 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	knight.play_action_animation(&"Attack")
	knight.request_kill(2)
	assert_false(first_target.is_dead, "Startup must reject an early hit even in an offline recording")
	GameState._physics_process(0.15)
	knight.request_kill(2)
	assert_true(first_target.is_dead, "A valid swing captures after simulated startup without waiting for wall time")
	GameState._physics_process(knight.attack_cooldown_timer.wait_time)
	knight.play_action_animation(&"Attack")
	GameState._physics_process(0.15)
	knight.request_kill(3)
	assert_true(second_target.is_dead, "The next swing becomes valid after the simulated cooldown")

func test_pickup_cooldown_uses_simulated_time() -> void:
	var skeleton := _player(1, Vector3.ZERO)
	var pile := Node3D.new()
	var receiver_body: Node = StaticBody3D.new()
	receiver_body.set_script(load("res://scenes/pile/script.gd"))
	var receiver := receiver_body as Interactable
	var label := Label3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.material = StandardMaterial3D.new()
	pile.add_child(label)
	pile.add_child(mesh)
	receiver.label = label
	receiver.mesh = mesh
	pile.add_child(receiver)
	pile.position = Vector3(0, 0, 1.5)
	arena.add_child(pile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	receiver.interact(true, {})
	receiver.interact(true, {})
	assert_eq(skeleton.inventory.items[CharacterInventory.InventoryItem.WOOD], 3, "Repeated input inside the same cooldown consumes fuel only once")
	GameState._physics_process(0.3)
	receiver.interact(true, {})
	assert_eq(skeleton.inventory.items[CharacterInventory.InventoryItem.WOOD], 6, "Pickup is available again after simulated time advances")
	assert_eq(receiver.current_amount, 4, "Both accepted pickups reduce the real pile")
