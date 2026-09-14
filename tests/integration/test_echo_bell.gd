extends GutTest

const EchoBellScene := preload("res://scenes/echo_bell/scene.tscn")

class BellCarrier extends CharacterBody3D:
	var hand: RemoteTransform3D = RemoteTransform3D.new()
	var anim_tree: AnimationTree = AnimationTree.new()
	var item: PhysicsBody3D
	var peer_id: int = 1
	var is_bot: bool = true

	func _init() -> void:
		add_child(hand)
		add_child(anim_tree)

class WorldFixture extends Node3D:
	var player_container: Node3D = Node3D.new()

	func _init() -> void:
		add_child(player_container)

class BotActor extends CharacterBody3D:
	var peer_id: int = -1
	var is_hunter: bool = true

class StrikeActor extends CharacterBody3D:
	var peer_id: int = 1
	var is_hunter: bool = true
	var is_dead: bool = false
	var is_stunned: bool = false

	func can_reach_attack(_target: Node3D) -> bool:
		return true

var arena: Node3D
var bell: EchoBell

func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)
	_make_floor()
	var scene: Node3D = EchoBellScene.instantiate()
	arena.add_child(scene)
	bell = scene.get_node("Bell")
	bell.position = Vector3(0, 1.6, 0)
	await get_tree().physics_frame

func test_pickup_throw_landing_and_single_activation() -> void:
	var carrier := BellCarrier.new()
	carrier.position = Vector3(0, 1.0, 0)
	arena.add_child(carrier)
	var held_transform := bell.global_transform
	bell.do_interact(true, {"caller": carrier, "transform": held_transform})
	assert_eq(carrier.item, bell)
	assert_true(bell.freeze)
	bell.do_interact(false, {"caller": carrier, "transform": held_transform, "linear_velocity": Vector3(0, -1, 0), "angular_velocity": Vector3.ZERO})
	assert_null(carrier.item)
	assert_false(bell.freeze)
	for frame_index in 180:
		await get_tree().physics_frame
		if bell.is_ringing:
			break
	assert_true(bell.is_ringing, "A thrown bell must ring after its first valid landing")
	assert_true(bell._activated)
	var ring_time := bell.remaining_ring_time
	bell._activate_echo.rpc(bell.global_position)
	assert_almost_eq(bell.remaining_ring_time, ring_time, 0.05)

func test_ring_expires_and_consumes_bell() -> void:
	var bell_scene := bell.get_parent()
	bell._activate_echo(bell.global_position)
	assert_true(bell.is_ringing)
	for frame_index in 600:
		await get_tree().process_frame
		if not is_instance_valid(bell):
			break
	assert_false(is_instance_valid(bell_scene), "A used bell must consume its complete spawned scene")
	assert_false(is_instance_valid(bell), "A used bell must be consumed after its ring window")

func test_searching_bot_selects_nearest_active_bell_and_ignores_idle_bells() -> void:
	var carrier := BellCarrier.new()
	carrier.position = Vector3.ZERO
	arena.add_child(carrier)
	var controller := CastleBotController.new(carrier)
	assert_null(controller._nearest_echo_bell(arena))
	var far_scene: Node3D = EchoBellScene.instantiate()
	arena.add_child(far_scene)
	var far_bell: EchoBell = far_scene.get_node("Bell")
	far_bell.position = Vector3(8, 0.6, 0)
	bell.position = Vector3(2, 0.6, 0)
	bell._activate_echo(bell.global_position)
	far_bell._activate_echo(far_bell.global_position)
	assert_eq(controller._nearest_echo_bell(arena), bell)
	bell.is_ringing = false
	assert_eq(controller._nearest_echo_bell(arena), far_bell)
	far_bell.position = Vector3(30, 0.6, 0)
	assert_null(controller._nearest_echo_bell(arena), "The bell chime must have a bounded hearing radius")

func test_knight_strike_does_not_destroy_or_dereference_bell() -> void:
	var original_state := GameState.game_state
	GameState.game_state = GameState.State.LOBBY
	var attacker := StrikeActor.new()
	attacker.add_to_group("players")
	arena.add_child(attacker)
	bell._activate_from_strike(2)
	assert_false(bell._activated)
	bell.on_attacked()
	assert_true(bell.is_ringing)
	assert_true(is_instance_valid(bell))
	GameState.game_state = original_state

func test_pulse_rings_keep_independent_opacity_materials() -> void:
	var ring_a: MeshInstance3D = bell.pulse.get_node("RingA")
	var ring_b: MeshInstance3D = bell.pulse.get_node("RingB")
	assert_ne(ring_a.material_override, ring_b.material_override)
	var second_scene: Node3D = EchoBellScene.instantiate()
	arena.add_child(second_scene)
	var second_bell: EchoBell = second_scene.get_node("Bell")
	var second_ring: MeshInstance3D = second_bell.pulse.get_node("RingA")
	assert_ne(ring_a.material_override, second_ring.material_override)
	bell.pulse.start()
	bell.pulse._process(0.8)
	second_bell.pulse.start()
	second_bell.pulse._process(0.1)
	assert_ne(ring_a.material_override.get_shader_parameter("opacity"), second_ring.material_override.get_shader_parameter("opacity"))
	var ring_b_opacity: float = ring_b.material_override.get_shader_parameter("opacity")
	ring_a.material_override.set_shader_parameter("opacity", 0.8)
	assert_eq(ring_b.material_override.get_shader_parameter("opacity"), ring_b_opacity)

func test_pulse_stays_level_when_bell_lands_rotated() -> void:
	bell.rotation = Vector3(0.45, -0.7, 0.25)
	bell.pulse.start()
	var pulse_normal := bell.pulse.global_transform.basis.y.normalized()
	assert_almost_eq(pulse_normal.dot(Vector3.UP), 1.0, 0.001)
	assert_almost_eq(bell.pulse.global_position.y, bell.global_position.y + EchoBellPulse.FLOOR_CLEARANCE, 0.001)

func test_visible_player_keeps_priority_over_nearer_echo_bell() -> void:
	var original_state := GameState.game_state
	GameState.game_state = GameState.State.LOBBY
	var world := WorldFixture.new()
	arena.add_child(world)
	var bot := BotActor.new()
	bot.position = Vector3.ZERO
	arena.add_child(bot)
	var player := BotActor.new()
	player.peer_id = 2
	player.is_hunter = false
	player.position = Vector3(4, 0, 0)
	world.player_container.add_child(player)
	bell.position = Vector3(1, 0.6, 0)
	bell._activate_echo(bell.global_position)
	var controller := CastleBotController.new(bot)
	controller._choose_hunter_destination(world, null)
	assert_eq(controller._target_peer_id, player.peer_id)
	assert_eq(controller._destination, player.global_position)
	assert_null(controller._echo_bell)
	GameState.game_state = original_state

func test_activation_rejects_non_authority_sender() -> void:
	assert_false(EchoBell.is_valid_activation_sender(2, 1))
	assert_true(EchoBell.is_valid_activation_sender(1, 1))
	assert_true(EchoBell.is_valid_activation_sender(0, 1))

func test_deterministic_room_bells_are_outside_dressing_fixture_tree() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var dressing := CastleDressing.new()
	world.add_child(dressing)
	CastleDressing.spawn_echo_bells(world)
	var container := world.get_node("CastleEchoBells")
	var names: Array[String] = []
	for child in container.get_children():
		names.append(child.name)
	assert_eq(names, ["EchoBellLibrary", "EchoBellGallery", "EchoBellKitchen"])
	assert_eq(container.get_child(0).position, Vector3(-14.8, 0.04, 2.1))
	assert_eq(container.get_child(1).position, Vector3(-17.4, 0.04, 22.2))
	assert_eq(container.get_child(2).position, Vector3(20.0, 0.04, 35.4))
	for position_value in [Vector3(-14.8, 0, 2.1), Vector3(-17.4, 0, 22.2), Vector3(20.0, 0, 35.4)]:
		var blockers := CastleClearance.blockers(dressing.get_furniture_bounds(), position_value)
		assert_true(blockers.is_empty(), "Echo Bell placement intersects furniture at %s: %s" % [position_value, blockers])

func _make_floor() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12, 0.2, 12)
	collision.shape = shape
	floor.position = Vector3(0, -0.1, 0)
	floor.add_child(collision)
	arena.add_child(floor)
