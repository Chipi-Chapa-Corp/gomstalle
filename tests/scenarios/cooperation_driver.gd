extends "res://tests/scenarios/trailer_driver.gd"

const COOP_SHOTS: Array[String] = ["distraction", "parkour", "escape"]
const FIXTURE_SEED := 641
const FRAME_DELTA := 1.0 / 60.0
const MAXIMUM_SHOT_FRAMES := 2400
const ChairScript := preload("res://scenes/chair/script.gd")
const PileScene := preload("res://scenes/pile/scene.tscn")

var _cooperation_shot: String
var _lead: CharacterBody3D
var _support: CharacterBody3D
var _runner: CharacterBody3D
var _scout: CharacterBody3D
var _hiders: Array[CharacterBody3D] = []
var _actors: Array[CharacterBody3D] = []
var _chair: Interactable
var _chair_body: RigidBody3D
var _chair_throw_speed := 0.0
var _chair_max_travel := 0.0
var _chair_min_knight_distance := -1.0
var _chair_last_position := Vector3.ZERO
var _chair_closest_position := Vector3.ZERO
var _chair_start_position := Vector3.ZERO
var _knight_stunned_frame := -1
var _lead_compact_frames := 0
var _lead_airborne_frames := 0
var _knight_pursuit_frames := 0
var _escape_events: Array[int] = []
var _camera_target_position := Vector3.ZERO
var _camera_focus := Vector3.ZERO
var _camera_focus_target := Vector3.ZERO
var _camera_visible_frames: Dictionary = {}
var _camera_clear_frames: Dictionary = {}
var _visibility_checks: Array[Dictionary] = []
var _finished := false
var _knight_start_position := Vector3.ZERO

func _ready() -> void:
	_cooperation_shot = OS.get_environment("GOMSTALLE_COOP_SHOT")
	_shot = _cooperation_shot
	if not COOP_SHOTS.has(_cooperation_shot):
		_fail("Unknown cooperation shot: " + _cooperation_shot)
		return
	_run.call_deferred()

func _run() -> void:
	CastleAudio.music.stop()
	Generator._configs = []
	seed(FIXTURE_SEED)
	GameState.solo_session = false
	GameState.target_player_count = 5
	NetworkManager.use_local_backend()
	GameState.create_and_join_lobby(_on_lobby_created)

func _on_lobby_created(success: bool) -> void:
	if not _require(success, "A real local five-player game session starts"):
		return
	GameState.enter_lobby()
	for frame in 1800:
		await get_tree().process_frame
		_world = get_tree().current_scene
		if _world != null and _world.get("round_utils") != null and _world.round_utils.initialized \
			and _world.player_container.get_child_count() >= 5:
			break
	if not _require(_world != null and _world.round_utils.initialized, "Production castle navigation and resources initialize"):
		return
	if not _require(_world.player_container.get_child_count() >= 5, "One production knight and four production skeletons spawn"):
		return
	Generator._configs = Generator.SPAWN_CONFIGS
	Generator._protected_positions.append_array([
		Vector3(30, 0, 25),
		Vector3(30, 0, 30),
		Vector3(35, 0, 30),
		Vector3(38, 0, 35),
		Vector3(5, 0, 23),
	])
	Generator._spawn_list = Generator._build_spawn_list(_world.grid_map, Generator._eligible_floor_cells(_world.grid_map), FIXTURE_SEED)
	Generator._apply_spawn_list(Generator._spawn_list)
	await _frames(2)
	var preferred_hunter: CharacterBody3D
	for actor in _world.player_container.get_children():
		if actor.is_bot and preferred_hunter == null:
			preferred_hunter = actor
	if not _require(preferred_hunter != null, "A production knight bot is available"):
		return
	if not _require(GameState.start_game(preferred_hunter.peer_id) == OK, "Production round assigns one knight and four skeleton roles"):
		return
	GameState.advance_round(GameState.remaining_seconds)
	await _frames(3)
	_knight = preferred_hunter
	_skeleton = _world.player_container.get_node(str(multiplayer.get_unique_id()))
	for actor in _world.player_container.get_children():
		if actor == _knight:
			continue
		_hiders.append(actor)
	_hiders.sort_custom(func(first_actor: CharacterBody3D, second_actor: CharacterBody3D): return first_actor.peer_id < second_actor.peer_id)
	if not _require(_hiders.size() >= 4, "Four visible production skeleton participants are available"):
		return
	_lead = _skeleton
	var available_hiders: Array[CharacterBody3D] = []
	for actor in _hiders:
		if actor != _lead:
			available_hiders.append(actor)
	_support = available_hiders[0]
	_runner = available_hiders[1]
	_scout = available_hiders[2]
	_actors.assign(_hiders)
	_actors.append(_knight)
	for actor in _hiders:
		actor.camera_utils.camera_yaw_offset = 0
		actor.set_physics_process(false)
		actor.movement.reset()
	_knight.camera_utils.camera_yaw_offset = 0
	_knight.set_physics_process(false)
	_knight.bot_controller = CastleBotController.new(_knight)
	_camera = Camera3D.new()
	_camera.name = "CooperationCamera"
	_camera.fov = 56
	_camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_DISABLED
	_world.add_child(_camera)
	_camera.make_current()
	_world.get_node("UI").hide()
	_world.castle_hud.hide()
	for actor in _actors:
		actor.hud.hide()
		actor.label.hide()
	match _cooperation_shot:
		"distraction": await _distraction()
		"parkour": await _parkour()
		"escape": await _escape_cooperation()
	if not _failed:
		_finish()

func _distraction() -> void:
	_chair = _find_chair(Vector3(37.2, 0, 28.7))
	if not _require(_chair != null, "A production banquet chair is available for the distraction"):
		return
	var chair_node: Node = _chair
	_chair_body = chair_node as RigidBody3D
	var holder_position := _interaction_position_for(_support, _chair)
	if _failed:
		return
	var knight_position := _select_throw_target(holder_position, _chair.global_position)
	var lead_position := _navigation_point_near(Vector3(29.0, 0, 30.0))
	var runner_position := _navigation_point_near(Vector3(42.0, 0, 30.0))
	var lead_start := _navigation_point_near(Vector3(29.0, 0, 31.0))
	var runner_start := _navigation_point_near(Vector3(45.0, 0, 31.0))
	var scout_position := _navigation_point_near(holder_position + Vector3(0, 0, 5.0))
	_place_actors([
		{"actor": _lead, "position": lead_start, "facing": holder_position - lead_start},
		{"actor": _support, "position": _navigation_point_near(holder_position + Vector3(0, 0, 2.2)), "facing": _chair.global_position - holder_position},
		{"actor": _runner, "position": runner_start, "facing": holder_position - runner_start},
		{"actor": _scout, "position": scout_position, "facing": holder_position - scout_position},
		{"actor": _knight, "position": knight_position, "facing": holder_position - knight_position},
	], Vector3(43.0, 13.8, 37.5), (holder_position + knight_position) * 0.5 + Vector3.UP)
	_begin_cooperation_shot()
	await _walk_navigation_group([
		{"actor": _lead, "destination": lead_position, "sprint": true},
		{"actor": _support, "destination": holder_position, "sprint": false},
		{"actor": _runner, "destination": runner_position, "sprint": true},
	], 360)
	if _failed:
		return
	if not _require_camera_coverage("approach", [_lead, _support, _runner, _knight]):
		return
	_event("objective_approached")
	await _frames(12)
	if not _require(_support.global_position.distance_to(_chair.global_position) <= _support.interact_radius + 0.8, "Chair carrier reaches the real production interaction radius"):
		return
	_production_interact(_support, _chair, true)
	var pickup_animation := _trigger_action(_support, &"Interact")
	await _frames(20)
	if not _require(_support.item == _chair, "Nearby teammate actually holds the production chair"):
		return
	if not _require(pickup_animation, "Chair pickup uses the production interact animation"):
		return
	_event("chair_held")
	_knight.set_physics_process(true)
	await _frames(18)
	_knight.bot_controller._target_peer_id = 0
	_knight.bot_controller._destination = _support.global_position
	_knight.bot_controller._path = _world.round_utils.navigation.find_path(_knight.global_position, _support.global_position)
	_knight.bot_controller._path_index = 0
	_knight.bot_controller._decision_time = 10.0
	_knight.bot_controller._path_time = 10.0
	_face_actor(_support, _knight.global_position - _support.global_position)
	await _frames(2)
	_chair_start_position = _chair_body.global_position
	_production_interact(_support, _chair, false)
	var throw_animation := _trigger_action(_support, &"Throw")
	_chair_throw_speed = _chair_body.linear_velocity.length()
	_event("chair_thrown")
	_require(throw_animation, "Chair release uses the production throw animation")
	_require(_chair_throw_speed >= 12.0, "Thrown chair receives the production airborne impulse")
	for frame in 120:
		await _advance([])
		if _knight_stunned_frame >= 0:
			break
	if not _require(_knight_stunned_frame >= 0, "Chair contact stuns the production knight"):
		return
	if not _require(_chair_max_travel >= 1.0, "Chair travels through the shot before contact"):
		return
	if not _require_camera_coverage("chair_contact", [_support, _lead, _runner, _knight]):
		return
	_event("knight_stunned")
	await _walk_group([
		{"actor": _lead, "destination": _navigation_point_near(_knight.global_position + Vector3(2.7, 0, 0)), "sprint": true},
		{"actor": _runner, "destination": _navigation_point_near(_knight.global_position + Vector3(0, 0, 2.7)), "sprint": true},
	], 120)
	_require(_support.item == null, "Chair carrier releases the production object after throwing")
	_require(_knight_stunned_frame >= 0, "Knight stun contact remains recorded for the advancing teammate")
	_event("teammate_advanced")

func _parkour() -> void:
	var hatch_start := Vector3(38, 0.1, 35.3)
	var hatch_exit := Vector3(38, 0.1, 29.7)
	var camera_focus := Vector3(38, 1.0, 32.8)
	_place_actors([
		{"actor": _lead, "position": hatch_start, "facing": Vector3(0, 0, -1)},
		{"actor": _support, "position": Vector3(40.0, 0.1, 35.3), "facing": hatch_start - Vector3(40.0, 0.1, 35.3)},
		{"actor": _runner, "position": Vector3(36.0, 0.1, 35.3), "facing": hatch_start - Vector3(36.0, 0.1, 35.3)},
		{"actor": _scout, "position": Vector3(42.0, 0.1, 34.0), "facing": hatch_start - Vector3(42.0, 0.1, 34.0)},
		{"actor": _knight, "position": Vector3(40.0, 0.1, 39.3), "facing": hatch_start - Vector3(40.0, 0.1, 39.3)},
	], Vector3(44.0, 15.0, 43.0), camera_focus)
	_begin_cooperation_shot()
	_knight.set_physics_process(true)
	_knight.bot_controller._target_peer_id = _lead.peer_id
	_knight.bot_controller._destination = _lead.global_position
	_knight.bot_controller._path = _world.round_utils.navigation.find_path(_knight.global_position, _lead.global_position)
	_knight.bot_controller._path_index = 0
	_knight.bot_controller._decision_time = 10.0
	_knight.bot_controller._path_time = 10.0
	await _frames(12)
	_lead.movement.request_jump()
	_event("lead_jump_requested")
	for frame in 12:
		await _advance([{"actor": _lead, "direction": Vector3(0, 0, -1), "sprint": true}])
	if not _require(_lead_airborne_frames >= 8, "Lead skeleton is genuinely airborne before the hatch"):
		return
	var slide_started: bool = _lead.movement.start_air_slide()
	_require(slide_started, "Lead skeleton starts the production air-slide in flight")
	_event("lead_air_slide")
	for frame in 38:
		await _advance([
			{"actor": _lead, "direction": Vector3(0, 0, -1), "sprint": true},
			{"actor": _runner, "direction": Vector3(0, 0, -1), "sprint": true},
		])
	if not _require(_lead_compact_frames > 8, "Lead skeleton uses the compact production collider in the hatch"):
		return
	if not _require(_lead.position.z < 30.8, "Lead skeleton emerges from the actual serving hatch"):
		return
	var previous_camera_position := _camera.global_position
	var previous_camera_focus := _camera_focus
	var exit_focus := (_lead.global_position + _support.global_position + _runner.global_position + _knight.global_position) * 0.25 + Vector3.UP
	var exit_camera_position := _select_camera_position(previous_camera_position, exit_focus)
	_camera.global_position = previous_camera_position
	_camera_target_position = exit_camera_position
	_camera_focus = previous_camera_focus
	_camera_focus_target = exit_focus
	await _frames(24)
	if not _require_camera_coverage("hatch_crossed", [_lead, _support, _runner, _knight]):
		return
	_event("hatch_crossed")
	_knight.bot_controller._target_peer_id = 0
	_knight.bot_controller._destination = _knight.global_position
	_knight.bot_controller._path = PackedVector3Array([_knight.global_position])
	_knight.bot_controller._path_index = 0
	_knight.bot_controller._decision_time = 10.0
	_knight.bot_controller._path_time = 10.0
	for frame in 60:
		await _advance([])
	_require(_lead.is_on_floor(), "Lead skeleton lands on the banquet-room floor")
	_require(not _lead.movement.is_compact, "Lead skeleton stands after leaving the serving lintel")
	_require(_knight_pursuit_frames > 4, "Knight follows the lead through production navigation")
	_require(_knight.global_position.distance_to(_knight_start_position) > 2.0, "Knight commits to the detour around the serving wall")
	_require_camera_coverage("parkour_landing", [_lead, _support, _runner, _knight])
	_event("parkour_landed")

func _escape_cooperation() -> void:
	var shrine := _nearest_shrine(Vector3(5, 0, 23))
	if not _require(shrine != null, "A production shrine is available for shared activation"):
		return
	var active_shrines: Array[NodePath] = [shrine.get_path()]
	_world.shrine_utils.configure_active_shrines(active_shrines)
	var shrine_approach := _interaction_position_for(_support, shrine)
	if _failed:
		return
	var pile_root: Node3D = PileScene.instantiate()
	_world.add_child(pile_root)
	var navigation: CastleNavigation = _world.round_utils.navigation
	var pile_position := navigation.graph.get_point_position(navigation.graph.get_closest_point(shrine_approach + Vector3(-4, 0, 0)))
	pile_root.global_position = pile_position
	var receiver := pile_root.get_node("Receiver") as Interactable
	receiver.set("current_amount", 6)
	(pile_root.get_node("Label3D") as Label3D).text = "6"
	var pile_approach := _interaction_position_for(_support, receiver)
	if _failed:
		return
	_place_actors([
		{"actor": _lead, "position": _navigation_point_near(shrine_approach + Vector3(0, 0, 5.0)), "facing": shrine.global_position - shrine_approach},
		{"actor": _support, "position": pile_approach, "facing": receiver.global_position - pile_approach},
		{"actor": _runner, "position": _navigation_point_near(pile_approach + Vector3(2.5, 0, 1.5)), "facing": pile_approach - _runner.global_position},
		{"actor": _scout, "position": _navigation_point_near(shrine_approach + Vector3(-4.0, 0, 2.5)), "facing": shrine.global_position - shrine_approach},
		{"actor": _knight, "position": _navigation_point_near(shrine_approach + Vector3(6.0, 0, 5.0)), "facing": shrine_approach - _knight.global_position},
	], shrine_approach + Vector3(8.0, 12.0, 8.0), (pile_approach + shrine_approach) * 0.5 + Vector3.UP)
	_begin_cooperation_shot()
	await _walk_actor_route(_support, pile_approach, false)
	await _use_production_target(_support, receiver)
	for frame in 60:
		await _advance([{"actor": _support, "direction": Vector3(-1, 0, 0), "sprint": true, "jump": frame == 0}])
	if not _require(_support.global_position.distance_to(receiver.global_position) > 2.1, "First teammate clears the production pile after collecting fuel"):
		return
	await _use_production_target(_runner, receiver)
	if not _require(_support.inventory.items[CharacterInventory.InventoryItem.WOOD] >= 3 and _runner.inventory.items[CharacterInventory.InventoryItem.WOOD] >= 3, "Two teammates collect fuel through production pile interactions"):
		return
	_event("shared_fuel_collected")
	await _walk_actor_route(_support, shrine_approach, true)
	await _walk_actor_route(_runner, _navigation_point_near(shrine_approach + Vector3(1.8, 0, 0)), true)
	await _use_production_target(_support, shrine)
	await _use_production_target(_runner, shrine)
	if not _require(shrine.is_filled and shrine.current_amount == shrine.required_amount, "Teammates complete the shared shrine with production offerings"):
		return
	_event("shared_shrine_kindled")
	for frame in 30:
		await _advance([
			{"actor": _support, "direction": Vector3(0, 0, 1), "sprint": true},
			{"actor": _runner, "direction": Vector3(1, 0, 0), "sprint": true},
		])
	var shrine_focus := (_support.global_position + _runner.global_position + _lead.global_position + _knight.global_position) * 0.25 + Vector3.UP
	var previous_camera_position := _camera.global_position
	var previous_camera_focus := _camera_focus
	var shrine_camera_position := _select_camera_position(previous_camera_position, shrine_focus)
	_camera.global_position = previous_camera_position
	_camera_target_position = shrine_camera_position
	_camera_focus = previous_camera_focus
	_camera_focus_target = shrine_focus
	await _frames(24)
	if not _require_camera_coverage("shared_shrine", [_support, _runner, _lead, _knight]):
		return
	var portal_visual: Node3D
	var portal_reveal_started := false
	var portal_visible_recorded := false
	for frame in 540:
		if portal_visual == null:
			portal_visual = _find_portal_visual()
			if portal_visual != null:
				portal_reveal_started = true
				_event("portal_reveal_start")
				_focus_portal_camera(portal_visual)
				var portal_point := portal_visual.global_position + Vector3.UP * 0.35
				var portal_in_frame := _position_in_frame(portal_point)
				var portal_clear := _camera_blocker_at(portal_point).is_empty()
				_visibility_checks.append({"label": "portal_reveal", "passed": portal_in_frame and portal_clear, "portal": {"in_frame": portal_in_frame, "clear": portal_clear, "position": _vector(portal_visual.global_position)}})
				if not _require(portal_in_frame and portal_clear, "Camera clearly frames the spawned portal visual during reveal"):
					return
		await _advance([])
		if GameState.portal_active and not portal_visible_recorded:
			portal_visible_recorded = true
			_event("portal_visible")
		if portal_visible_recorded and not GameState.portal_cinematic_active:
			break
	if not _require(portal_reveal_started, "Production portal visual spawns before its focus delay"):
		return
	if not _require(GameState.portal_active, "Shared shrine activation opens the real production portal"):
		return
	if not _require(portal_visible_recorded, "Production portal state becomes visible before escape"):
		return
	if not _require(not GameState.portal_cinematic_active, "Portal camera sequence completes before the team escapes"):
		return
	_knight.set_physics_process(false)
	_knight.bot_controller._target_peer_id = 0
	_knight.bot_controller._destination = _knight.global_position
	_knight.bot_controller._path = PackedVector3Array([_knight.global_position])
	_knight.bot_controller._path_index = 0
	_knight.bot_controller._decision_time = 10.0
	_knight.bot_controller._path_time = 10.0
	var escape_routes: Array[Dictionary] = [
		{"actor": _support, "path": navigation.find_path(_support.global_position, GameState.portal_position), "index": 0},
		{"actor": _runner, "path": navigation.find_path(_runner.global_position, GameState.portal_position), "index": 0},
	]
	if not _require(not (escape_routes[0]["path"] as PackedVector3Array).is_empty() and not (escape_routes[1]["path"] as PackedVector3Array).is_empty(), "Two teammates have production navigation paths to the opened portal"):
		return
	for route in escape_routes:
		var actor: CharacterBody3D = route["actor"]
		actor.set_physics_process(true)
		actor.bot_controller._target_peer_id = 0
		actor.bot_controller._destination = GameState.portal_position
		actor.bot_controller._path = route["path"]
		actor.bot_controller._path_index = 0
		actor.bot_controller._decision_time = 10.0
		actor.bot_controller._path_time = 10.0
	for frame in 1500:
		await get_tree().physics_frame
		if GameState.escaped_peer_ids.size() >= 2:
			break
	if not _require(GameState.escaped_peer_ids.size() >= 2, "At least two teammates escape through the live portal"):
		return
	await _frames(24)
	_require_camera_coverage("two_escapes", [_support, _runner])
	_event("two_skeletons_escaped")

func _place_actors(placements: Array[Dictionary], camera_position: Vector3, focus: Vector3) -> void:
	_release_input()
	for placement in placements:
		var actor: CharacterBody3D = placement["actor"]
		actor.global_position = placement["position"]
		actor.velocity = Vector3.ZERO
		actor.is_stunned = false
		actor.is_dead = false
		actor.movement.reset()
		_face_actor(actor, placement["facing"])
	_knight_start_position = _knight.global_position
	_select_camera_position(camera_position, focus)

func _select_camera_position(requested_position: Vector3, focus: Vector3, scored_actors: Array[CharacterBody3D] = []) -> Vector3:
	var candidates: Array[Vector3] = [
		requested_position,
		focus + Vector3(-12.0, 13.5, -8.0),
		focus + Vector3(-12.0, 13.5, 8.0),
		focus + Vector3(12.0, 13.5, -8.0),
		focus + Vector3(12.0, 13.5, 8.0),
		focus + Vector3(0.0, 13.5, -13.0),
		focus + Vector3(0.0, 13.5, 13.0),
		focus + Vector3(-13.0, 13.5, 0.0),
		focus + Vector3(13.0, 13.5, 0.0),
		focus + Vector3(-7.0, 13.5, -11.0),
		focus + Vector3(-7.0, 13.5, 11.0),
		focus + Vector3(7.0, 13.5, -11.0),
		focus + Vector3(7.0, 13.5, 11.0)
	]
	var best_position := requested_position
	var best_score := -1
	var actors_to_score: Array[CharacterBody3D] = _actors if scored_actors.is_empty() else scored_actors
	for candidate in candidates:
		_camera.global_position = candidate
		_camera.look_at(focus, Vector3.UP)
		var score := 0
		for actor in actors_to_score:
			score += int(_camera_has_line_of_sight(actor)) * 100
			score += int(_in_frame(actor))
		if score > best_score:
			best_score = score
			best_position = candidate
	_camera.global_position = best_position
	_camera_target_position = best_position
	_camera_focus = focus
	_camera_focus_target = focus
	_camera.look_at(focus, Vector3.UP)
	return best_position

func _find_portal_visual() -> Node3D:
	for candidate in _world.portal_container.get_children():
		if candidate is PortalVisual:
			return candidate
	return null

func _focus_portal_camera(portal_visual: Node3D) -> void:
	var focus := portal_visual.global_position + Vector3.UP * 0.35
	var requested_position := focus + Vector3(8.0, 12.0, 8.0)
	var candidates: Array[Vector3] = [
		requested_position,
		focus + Vector3(-8.0, 12.0, -8.0),
		focus + Vector3(-8.0, 12.0, 8.0),
		focus + Vector3(8.0, 12.0, -8.0),
		focus + Vector3(8.0, 12.0, 8.0),
		focus + Vector3(0.0, 12.0, -10.0),
		focus + Vector3(0.0, 12.0, 10.0)
	]
	var best_position := requested_position
	var best_score := -1
	for candidate in candidates:
		_camera.global_position = candidate
		_camera.look_at(focus, Vector3.UP)
		var score := int(_camera_blocker_at(focus).is_empty()) * 100 + int(_position_in_frame(focus))
		if score > best_score:
			best_score = score
			best_position = candidate
	_camera.global_position = best_position
	_camera_target_position = best_position
	_camera_focus = focus
	_camera_focus_target = focus
	_camera.look_at(focus, Vector3.UP)

func _position_in_frame(position: Vector3) -> bool:
	var frame := get_viewport().get_visible_rect().grow(-24)
	return not _camera.is_position_behind(position) and frame.has_point(_camera.unproject_position(position))

func _begin_cooperation_shot() -> void:
	_first_frame = Engine.get_process_frames()
	_recording = true
	_event("shot_begin")

func _advance(commands: Array[Dictionary]) -> void:
	var command_map: Dictionary = {}
	for command in commands:
		var actor: CharacterBody3D = command["actor"]
		command_map[actor.get_instance_id()] = command
	for actor in _hiders:
		if not is_instance_valid(actor):
			continue
		if GameState.escaped_peer_ids.has(actor.peer_id):
			continue
		var command: Dictionary = command_map.get(actor.get_instance_id(), {})
		var direction: Vector3 = command.get("direction", Vector3.ZERO)
		if command.get("jump", false):
			actor.movement.request_jump()
		if command.get("slide", false):
			actor.movement.start_air_slide()
		_face_actor(actor, direction)
		actor.forces.handle(FRAME_DELTA)
		actor.movement._apply_movement(FRAME_DELTA, Vector2(direction.x, direction.z), command.get("sprint", false))
		actor.move_and_slide()
		actor.movement.finish_physics(FRAME_DELTA)
	await get_tree().physics_frame

func _walk_group(routes: Array[Dictionary], maximum_frames: int) -> void:
	for frame in maximum_frames:
		if _failed:
			return
		var commands: Array[Dictionary] = []
		var all_reached := true
		for route in routes:
			var actor: CharacterBody3D = route["actor"]
			if GameState.escaped_peer_ids.has(actor.peer_id):
				continue
			var destination: Vector3 = route["destination"]
			var remaining := destination - actor.global_position
			remaining.y = 0
			if remaining.length() <= 0.65:
				continue
			all_reached = false
			commands.append({"actor": actor, "direction": remaining.normalized(), "sprint": route.get("sprint", false)})
		if all_reached:
			return
		await _advance(commands)
	_fail("Cooperation route did not reach its staged destination")

func _walk_actor_route(actor: CharacterBody3D, destination: Vector3, sprint: bool) -> void:
	var path: PackedVector3Array = _world.round_utils.navigation.find_path(actor.global_position, destination)
	if not _require(not path.is_empty(), "Production navigation finds a route for %s" % actor.name):
		return
	for waypoint in path:
		await _walk_group([{"actor": actor, "destination": waypoint, "sprint": sprint}], 180)
		if _failed:
			return

func _walk_navigation_group(routes: Array[Dictionary], maximum_frames: int) -> void:
	var navigation: CastleNavigation = _world.round_utils.navigation
	var path_routes: Array[Dictionary] = []
	for route in routes:
		var actor: CharacterBody3D = route["actor"]
		var destination: Vector3 = route["destination"]
		var path := navigation.find_path(actor.global_position, destination)
		if not _require(not path.is_empty(), "Production navigation finds a route for %s" % actor.name):
			return
		path_routes.append({"actor": actor, "path": path, "index": 0})
	await _walk_path_group(path_routes, maximum_frames)
	for route in routes:
		var actor: CharacterBody3D = route["actor"]
		var destination: Vector3 = route["destination"]
		if not _require(actor.global_position.distance_to(destination) <= 0.8, "Production actor %s reaches the staged destination" % actor.name):
			return

func _walk_path_group(routes: Array[Dictionary], maximum_frames: int) -> void:
	for frame in maximum_frames:
		if _failed or GameState.escaped_peer_ids.size() >= 2:
			return
		var commands: Array[Dictionary] = []
		var all_reached := true
		for route in routes:
			var actor: CharacterBody3D = route["actor"]
			var path: PackedVector3Array = route["path"]
			var path_index: int = route["index"]
			while path_index < path.size() and actor.global_position.distance_to(path[path_index]) < 0.42:
				path_index += 1
			route["index"] = path_index
			if path_index >= path.size() or GameState.escaped_peer_ids.has(actor.peer_id):
				continue
			all_reached = false
			var remaining := path[path_index] - actor.global_position
			remaining.y = 0
			commands.append({"actor": actor, "direction": remaining.normalized(), "sprint": true})
		if all_reached:
			return
		await _advance(commands)

func _use_production_target(actor: CharacterBody3D, target: Interactable) -> void:
	await _frames(20)
	actor.interactions._update_target()
	if not _require(actor.global_position.distance_to(target.global_position) <= actor.interact_radius + 0.8, "Teammate reaches the production interaction radius"):
		return
	if not _require(target.can_player_interact(actor, true), "Production interaction has a clear approach"):
		return
	target._execute_player_request(actor, true, {})
	_trigger_action(actor, &"Interact")
	await _frames(20)

func _production_interact(actor: CharacterBody3D, target: Interactable, enable: bool) -> void:
	target._execute_player_request(actor, enable, {})

func _trigger_action(actor: CharacterBody3D, action: StringName) -> bool:
	actor.play_action_animation(action)
	return actor.anim_tree.get("parameters/IW/%s_OS/request" % action) == AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func _find_chair(target_position: Vector3) -> Interactable:
	var selected: Interactable
	var nearest_distance := INF
	for candidate_node in get_tree().get_nodes_in_group("interactible"):
		if not candidate_node is Interactable or candidate_node.get_script() != ChairScript:
			continue
		var candidate: Interactable = candidate_node
		var distance := candidate.global_position.distance_squared_to(target_position)
		if distance < nearest_distance:
			nearest_distance = distance
			selected = candidate
	return selected

func _nearest_shrine(target_position: Vector3) -> Interactable:
	var selected: Interactable
	var nearest_distance := INF
	for candidate_node in _world.shrine_utils.shrine_nodes:
		var candidate: Interactable = candidate_node
		var distance := candidate.global_position.distance_squared_to(target_position)
		if distance < nearest_distance:
			nearest_distance = distance
			selected = candidate
	return selected

func _interaction_position_for(actor: CharacterBody3D, target: Interactable) -> Vector3:
	var navigation: CastleNavigation = _world.round_utils.navigation
	var original_position := actor.global_position
	var candidates: Array[Vector3] = []
	for identifier in navigation.graph.get_point_ids():
		var candidate_position: Vector3 = navigation.graph.get_point_position(identifier)
		if candidate_position.distance_to(target.global_position) < actor.interact_radius + 0.8:
			candidates.append(candidate_position + Vector3.UP * 0.1)
	candidates.sort_custom(func(first_position: Vector3, second_position: Vector3): return first_position.distance_squared_to(target.global_position) < second_position.distance_squared_to(target.global_position))
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = actor.get_node("Regular Collider").shape
	clearance.collision_mask = 1
	clearance.exclude = [actor.get_rid()]
	for candidate in candidates:
		clearance.transform.origin = candidate + Vector3.UP
		if not _world.get_world_3d().direct_space_state.intersect_shape(clearance, 1).is_empty():
			continue
		actor.global_position = candidate
		if target.can_player_interact(actor, true):
			actor.global_position = original_position
			return candidate
		actor.global_position = original_position
	_fail("No clear production interaction approach for %s" % target.get_path())
	return original_position

func _navigation_point_near(desired_position: Vector3) -> Vector3:
	var navigation: CastleNavigation = _world.round_utils.navigation
	var closest := navigation.graph.get_closest_point(desired_position)
	return navigation.graph.get_point_position(closest)

func _select_throw_target(holder_position: Vector3, chair_position: Vector3) -> Vector3:
	var navigation: CastleNavigation = _world.round_utils.navigation
	var desired_positions: Array[Vector3] = [
		chair_position + Vector3(0, 0, -6),
		chair_position + Vector3(0, 0, 6),
		chair_position + Vector3(-6, 0, 0),
		chair_position + Vector3(6, 0, 0),
	]
	for desired_position in desired_positions:
		var candidate := navigation.graph.get_point_position(navigation.graph.get_closest_point(desired_position))
		var distance := candidate.distance_to(holder_position)
		if distance >= 3.4 and distance <= 8.5 and _line_of_sight(holder_position + Vector3.UP, candidate + Vector3.UP):
			return candidate
	return _navigation_point_near(chair_position + Vector3(0, 0, -5))

func _face_actor(actor: CharacterBody3D, direction: Vector3) -> void:
	var horizontal_direction := direction
	horizontal_direction.y = 0
	if horizontal_direction.length_squared() > 0.01:
		actor.model.rotation.y = atan2(horizontal_direction.x, horizontal_direction.z)

func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	var blend := 1.0 - exp(-5.5 * delta)
	_camera.global_position = _camera.global_position.lerp(_camera_target_position, blend)
	_camera_focus = _camera_focus.lerp(_camera_focus_target, blend)
	_camera.look_at(_camera_focus, Vector3.UP)

func _require_camera_coverage(label: String, actors: Array[CharacterBody3D]) -> bool:
	var covered := true
	var details: Array[Dictionary] = []
	for actor in actors:
		var in_frame := _in_frame(actor)
		var clear := _camera_has_line_of_sight(actor)
		details.append({"actor": actor.name, "in_frame": in_frame, "clear": clear, "blocker": _camera_blocker(actor)})
		covered = covered and in_frame and clear
	_visibility_checks.append({"label": label, "passed": covered, "actors": details})
	return _require(covered, "Camera clearly sees every key actor at " + label)

func _camera_has_line_of_sight(actor: CharacterBody3D) -> bool:
	return _camera_blocker(actor).is_empty()

func _camera_blocker(actor: CharacterBody3D) -> String:
	return _camera_blocker_at(actor.global_position + Vector3.UP * 1.0)

func _camera_blocker_at(target_position: Vector3) -> String:
	var excludes: Array[RID] = []
	for candidate in _actors:
		excludes.append(candidate.get_rid())
	if is_instance_valid(_chair_body):
		excludes.append(_chair_body.get_rid())
	var query := PhysicsRayQueryParameters3D.create(_camera.global_position, target_position, 1, excludes)
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	return "" if hit.is_empty() else str(hit["collider"].get_path())

func _line_of_sight(origin: Vector3, destination: Vector3) -> bool:
	var excludes: Array[RID] = []
	for actor in _actors:
		excludes.append(actor.get_rid())
	if is_instance_valid(_chair_body):
		excludes.append(_chair_body.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, excludes)
	return _world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(_delta: float) -> void:
	if not _recording or _failed:
		return
	_update_camera(FRAME_DELTA)
	_sample_count += 1
	for actor in _actors:
		var actor_key := str(actor.peer_id)
		var in_frame := _in_frame(actor)
		var clear := _camera_has_line_of_sight(actor)
		_camera_visible_frames[actor_key] = int(_camera_visible_frames.get(actor_key, 0)) + int(in_frame)
		_camera_clear_frames[actor_key] = int(_camera_clear_frames.get(actor_key, 0)) + int(clear)
	if _lead != null:
		_maximum_height = maxf(_maximum_height, _lead.position.y)
		if _lead.movement.is_compact:
			_lead_compact_frames += 1
		if not _lead.is_on_floor():
			_lead_airborne_frames += 1
	if _knight != null and _knight.bot_controller != null and _knight.bot_controller._target_peer_id == _lead.peer_id:
		_knight_pursuit_frames += 1
	if _knight != null and _knight.is_stunned and _knight_stunned_frame < 0:
		_knight_stunned_frame = Engine.get_process_frames() - _first_frame
	if _chair_throw_speed > 0.0 and is_instance_valid(_chair_body):
		_chair_max_travel = maxf(_chair_max_travel, _chair_body.global_position.distance_to(_chair_start_position))
		var knight_distance := _chair_body.global_position.distance_to(_knight.global_position)
		if _chair_min_knight_distance < 0.0 or knight_distance < _chair_min_knight_distance:
			_chair_min_knight_distance = knight_distance
			_chair_closest_position = _chair_body.global_position
		_chair_last_position = _chair_body.global_position
	if _escape_events.size() < GameState.escaped_peer_ids.size():
		for peer_id in GameState.escaped_peer_ids:
			if not _escape_events.has(peer_id):
				_escape_events.append(peer_id)
				_event("skeleton_escaped_%d" % peer_id)
	var elapsed := Engine.get_process_frames() - _first_frame
	if elapsed % 6 == 0:
		var actor_trace: Dictionary = {}
		for actor in _actors:
			actor_trace[actor.name] = _vector(actor.position)
		_trace.append({"frame": elapsed, "actors": actor_trace, "compact": _lead.movement.is_compact, "airborne": not _lead.is_on_floor()})
	if _lead != null and _lead.is_dead:
		_fail("Knight captured the lead skeleton during cooperation shot")
	elif elapsed > MAXIMUM_SHOT_FRAMES:
		_fail("Cooperation shot exceeded its choreography limit")

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_recording = false
	_last_frame = Engine.get_process_frames()
	_release_input()
	var actor_names: Dictionary = {}
	for actor in _actors:
		actor_names[actor.name] = NetworkManager.get_player_name(actor.peer_id)
	var result := {
		"shot": _cooperation_shot,
		"fixture_seed": FIXTURE_SEED,
		"passed": not _failed,
		"start_frame": _first_frame,
		"end_frame": _last_frame,
		"duration_frames": _last_frame - _first_frame,
		"fps": 60,
		"checks": _checks,
		"events": _events,
		"trace": _trace,
		"visibility_checks": _visibility_checks,
		"camera_visible_frames": _camera_visible_frames,
		"camera_clear_frames": _camera_clear_frames,
		"camera_position": _vector(_camera.global_position),
		"camera_focus": _vector(_camera_focus),
		"maximum_lead_height": _maximum_height,
		"lead_airborne_frames": _lead_airborne_frames,
		"lead_compact_frames": _lead_compact_frames,
		"knight_pursuit_frames": _knight_pursuit_frames,
		"knight_stunned_frame": _knight_stunned_frame,
		"chair_throw_speed": _chair_throw_speed,
		"chair_max_travel": _chair_max_travel,
		"chair_min_knight_distance": _chair_min_knight_distance,
		"chair_last_position": _vector(_chair_last_position),
		"chair_closest_position": _vector(_chair_closest_position),
		"escaped_peer_ids": GameState.escaped_peer_ids,
		"actor_names": actor_names,
	}
	var result_path := OS.get_environment("GOMSTALLE_TRAILER_RESULT")
	if not result_path.is_empty():
		var output := FileAccess.open(result_path, FileAccess.WRITE)
		output.store_string(JSON.stringify(result, "\t"))
	print("COOPERATION_RESULT ", JSON.stringify(result))
	_shutdown.call_deferred()
