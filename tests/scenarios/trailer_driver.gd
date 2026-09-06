extends Node

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_forward", &"move_backward", &"run", &"jump", &"skill_1", &"interact", &"emote"]
const SHOTS: Array[String] = ["library", "kitchen", "grand_hall", "offering", "escape"]

var _shot: String
var _world: Node3D
var _skeleton: CharacterBody3D
var _knight: CharacterBody3D
var _camera: Camera3D
var _failed := false
var _recording := false
var _first_frame: int
var _last_frame: int
var _checks: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _trace: Array[Dictionary] = []
var _maximum_height := 0.0
var _knight_maximum_height := 0.0
var _compact_frames := 0
var _airborne_frames := 0
var _pursuit_frames := 0
var _nearest_knight := -1.0
var _knight_start := Vector3.ZERO
var _maximum_frames := 600
var _sample_count := 0
var _skeleton_visible_frames := 0
var _knight_visible_frames := 0
var _gallery_jump_active := false

func _ready() -> void:
	_shot = OS.get_environment("GOMSTALLE_TRAILER_SHOT")
	if not SHOTS.has(_shot):
		_fail("Unknown trailer shot: " + _shot)
		return
	_run.call_deferred()

func _run() -> void:
	CastleAudio.music.stop()
	Generator._configs = []
	seed(641)
	GameState.solo_session = false
	GameState.target_player_count = 2
	NetworkManager.use_local_backend()
	GameState.create_and_join_lobby(_on_lobby_created)

func _on_lobby_created(success: bool) -> void:
	if not _require(success, "A real local game session starts"):
		return
	GameState.enter_lobby()
	for frame in 1800:
		await get_tree().process_frame
		_world = get_tree().current_scene
		if _world != null and _world.get("round_utils") != null and _world.round_utils.initialized:
			break
	if not _require(_world != null and _world.round_utils.initialized, "Production castle navigation and resources initialize"):
		return
	_skeleton = _world.player_container.get_node(str(multiplayer.get_unique_id()))
	for actor in _world.player_container.get_children():
		if actor.is_bot:
			_knight = actor
	if not _require(_knight != null, "A production knight bot joins the game"):
		return
	_knight.set_physics_process(false)
	Generator._configs = Generator.SPAWN_CONFIGS
	Generator._protected_positions.append_array([Vector3(30, 0, 25), Vector3(30, 0, 30), Vector3(35, 0, 30), Vector3(38, 0, 35)])
	Generator._spawn_list = Generator._build_spawn_list(_world.grid_map, Generator._eligible_floor_cells(_world.grid_map), 641)
	Generator._apply_spawn_list(Generator._spawn_list)
	await _frames(2)
	if not _require(GameState.start_game(_knight.peer_id) == OK, "Production round assigns skeleton and knight roles"):
		return
	GameState.advance_round(GameState.remaining_seconds)
	_skeleton.camera_utils.camera_yaw_offset = 0
	_camera = Camera3D.new()
	_camera.name = "TrailerCamera"
	_camera.fov = 56
	_camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_DISABLED
	_world.add_child(_camera)
	_camera.make_current()
	_world.get_node("UI").hide()
	_world.castle_hud.hide()
	_skeleton.hud.hide()
	match _shot:
		"library": await _library()
		"kitchen": await _kitchen()
		"grand_hall": await _grand_hall()
		"offering": await _offering()
		"escape": await _escape()
	if not _failed:
		_finish()

func _place(skeleton_position: Vector3, knight_position: Vector3, camera_position: Vector3, focus: Vector3) -> void:
	_release_input()
	_skeleton.global_position = skeleton_position
	_skeleton.velocity = Vector3.ZERO
	_knight.global_position = knight_position
	_knight.velocity = Vector3.ZERO
	_knight.bot_controller = CastleBotController.new(_knight)
	_knight_start = knight_position
	_camera.position = camera_position
	_camera.look_at(focus)
	await _frames(15)

func _begin() -> void:
	_first_frame = Engine.get_process_frames()
	_recording = true
	_knight.set_physics_process(true)
	_event("shot_begin")

func _library() -> void:
	await _place(Vector3(-15.15, .1, -.7), Vector3(-15.15, .1, 3.0), Vector3(-9.5, 13, 5), Vector3(-19.5, 1.0, -4.5))
	_begin()
	await _walk_to(Vector3(-15.15, 2.67, -8.4), true)
	if not _require(_skeleton.position.y > 2.55, "Skeleton climbs the real library stair to the reading gallery"):
		return
	_event("gallery_reached")
	await _walk_to(Vector3(-18.1, 2.67, -8.4), true)
	_move(Vector2(0, 1), true)
	await _pulse(&"jump")
	_event("gallery_jump")
	_gallery_jump_active = true
	await _walk_to(Vector3(-18.1, 0, -4.7), true)
	await _walk_to(Vector3(-15.0, 0, -2.6), true)
	await _walk_to(Vector3(-19, 0, -.5), true)
	await _walk_to(Vector3(-19, 0, -5.7), false)
	_release_input()
	await _frames(18)
	_require(_airborne_frames > 12 and _skeleton.is_on_floor(), "Gallery jump produces real airtime and a grounded landing")
	_assert_pursuit()

func _kitchen() -> void:
	await _place(Vector3(38, .1, 35.3), Vector3(40.0, .1, 39.3), Vector3(44, 15, 43), Vector3(31.5, .8, 32.8))
	_begin()
	_move(Vector2(0, -1), false)
	await _pulse(&"jump")
	await _frames(10)
	await _pulse(&"skill_1")
	_event("air_slide_input")
	await _walk_to(Vector3(38, 0, 29.7), true)
	if not _require(_skeleton.position.z < 30.8 and _compact_frames > 0, "Real jump and air-slide cross the kitchen serving hatch"):
		return
	_event("hatch_crossed")
	await _walk_to(Vector3(31.2, 0, 29.7), true)
	await _walk_to(Vector3(30.1, 0, 23), true)
	await _walk_to(Vector3(30.1, 0, 29.7), true)
	await _walk_to(Vector3(35, 0, 29.7), false)
	_release_input()
	await _frames(18)
	_require(not _skeleton.movement.is_compact, "Skeleton stands after leaving the serving lintel")
	_require(_knight.position.x < 34 or _knight.position.z < 31, "Knight commits to the ordinary doorway route around the wall")
	_assert_pursuit()

func _grand_hall() -> void:
	await _place(Vector3(2, .1, 56), Vector3(2, .1, 60.2), Vector3(19, 14, 63), Vector3(8.5, 1.0, 52))
	_begin()
	await _walk_to(Vector3(2, 2.2, 50.2), true)
	if not _require(_skeleton.position.y > 2.1, "Skeleton ascends the audience court"):
		return
	_event("audience_court_reached")
	await _walk_to(Vector3(7.2, 2.2, 48.2), true)
	await _walk_to(Vector3(10.9, 0, 48.2), true)
	_event("side_stair_descent")
	await _walk_to(Vector3(10.4, 0, 54), true)
	await _walk_to(Vector3(17.0, 0, 56.5), true)
	_release_input()
	await _frames(18)
	_require(_skeleton.position.y < .2, "Skeleton descends the side stair to the real castle floor")
	_require(_knight_maximum_height > .5, "Production knight follows onto the raised court")
	_assert_pursuit()

func _offering() -> void:
	var shrine: Interactable = _nearest_shrine(Vector3(5, 0, 23))
	var paths: Array[NodePath] = [shrine.get_path()]
	for candidate in _world.shrine_utils.shrine_nodes:
		if candidate != shrine and paths.size() < 3:
			paths.append(candidate.get_path())
	_world.shrine_utils.configure_active_shrines(paths)
	var shrine_approach := _interaction_position(shrine)
	var navigation: CastleNavigation = _world.round_utils.navigation
	var pile_position := navigation.graph.get_point_position(navigation.graph.get_closest_point(shrine_approach + Vector3(-4, 0, 0)))
	var pile: Node3D = load("res://scenes/pile/scene.tscn").instantiate()
	_world.add_child(pile)
	pile.global_position = pile_position
	var receiver: Interactable = pile.get_node("Receiver")
	await _frames(2)
	var pile_approach := _interaction_position(receiver)
	await _place(pile_approach, Vector3(18, .1, 58), shrine_approach + Vector3(7, 10, 7), (shrine_approach + pile_approach) * .5 + Vector3.UP)
	var pile_before: int = receiver.current_amount
	_begin()
	await _use(receiver)
	await _use(receiver)
	if not _require(_skeleton.inventory.items[CharacterInventory.InventoryItem.WOOD] == 6 and receiver.current_amount == pile_before - 6, "Two real pile interactions collect exactly six fuel"):
		return
	_event("fuel_collected")
	await _walk_to(pile_approach + Vector3(0, 0, 2.5), false)
	await _walk_to(shrine_approach + Vector3(0, 0, 2.5), false)
	await _walk_to(shrine_approach, false)
	await _use(shrine)
	await _use(shrine)
	if not _require(shrine.is_filled and shrine.current_amount == 6, "Two production offerings kindle the shrine"):
		return
	_event("shrine_kindled")
	await _pulse(&"emote")
	await _frames(90)
	_require(_skeleton.inventory.items[CharacterInventory.InventoryItem.WOOD] == 0, "Offering consumes the six collected fuel")

func _escape() -> void:
	var selected: WorldPortalUtils.PortalCandidate
	for candidate in _world.portal_utils._collect_floor_candidates():
		if selected == null or candidate.position.distance_squared_to(Vector3.ZERO) < selected.position.distance_squared_to(Vector3.ZERO):
			selected = candidate
	if not _require(selected != null, "Arrival hall has a legal reachable portal opening"):
		return
	await _place(selected.position + Vector3(0, .1, 6.3), selected.position + Vector3(0, .1, 10.5), selected.position + Vector3(8, 12, 11), selected.position + Vector3(0, 0, 2))
	_world.spawn_portal(selected.cell, selected.item_id)
	for frame in 300:
		await get_tree().physics_frame
		if GameState.portal_active:
			break
	if not _require(GameState.portal_active, "Production portal sequence reveals the real floor opening"):
		return
	_camera.make_current()
	_begin()
	for frame in 300:
		await get_tree().physics_frame
		if not GameState.portal_cinematic_active:
			break
	_event("portal_opening_complete")
	_move(Vector2(0, -1), true)
	await _frames(9)
	await _pulse(&"jump")
	for frame in 180:
		await get_tree().physics_frame
		if GameState.escaped_peer_ids.has(_skeleton.peer_id):
			break
		if _skeleton.position.z < selected.position.z + .25:
			_release_input()
	_require(GameState.escaped_peer_ids.has(_skeleton.peer_id), "Skeleton enters the live portal and the authoritative round records escape")
	_event("escaped")
	_release_input()
	await _frames(45)
	_require(GameState.winner == 1 and GameState.game_state == GameState.State.RESULTS, "Real escape resolves the round as a skeleton victory")
	_assert_pursuit()

func _nearest_shrine(position: Vector3) -> Interactable:
	var nearest: Interactable
	var distance := INF
	for shrine in _world.shrine_utils.shrine_nodes:
		var candidate_distance := position.distance_squared_to(shrine.global_position)
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = shrine
	return nearest

func _interaction_position(target: Interactable) -> Vector3:
	var navigation: CastleNavigation = _world.round_utils.navigation
	var original := _skeleton.global_position
	var candidates: Array[Vector3] = []
	for identifier in navigation.graph.get_point_ids():
		var position := navigation.graph.get_point_position(identifier)
		if position.distance_to(target.global_position) < _skeleton.interact_radius + .75:
			candidates.append(position + Vector3.UP * .1)
	candidates.sort_custom(func(first: Vector3, second: Vector3): return first.distance_squared_to(target.global_position) < second.distance_squared_to(target.global_position))
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = _skeleton.get_node("Regular Collider").shape
	clearance.collision_mask = 1
	clearance.exclude = [_skeleton.get_rid()]
	var diagnostics: Array[Dictionary] = []
	for candidate in candidates:
		clearance.transform.origin = candidate + Vector3.UP
		var overlaps := _world.get_world_3d().direct_space_state.intersect_shape(clearance, 1)
		if not overlaps.is_empty():
			diagnostics.append({"candidate": candidate, "blocked": str(overlaps[0]["collider"].get_path())})
			continue
		_skeleton.global_position = candidate
		_skeleton.interactions._update_target()
		diagnostics.append({"candidate": candidate, "closest": str(_skeleton.closest_item), "can_interact": target.can_player_interact(_skeleton, true)})
		if _skeleton.closest_item == target and target.can_player_interact(_skeleton, true):
			_skeleton.global_position = original
			return candidate
	_skeleton.global_position = original
	_fail("No clear production interaction approach for %s at %s: %s" % [target.get_path(), target.global_position, JSON.stringify(diagnostics)])
	return original

func _use(target: Interactable) -> void:
	_release_input()
	await _frames(24)
	_skeleton.interactions._update_target()
	if not _require(_skeleton.closest_item == target and target.can_player_interact(_skeleton, true), "Real input selects " + str(target.get_path())):
		return
	await _pulse(&"interact")
	await _frames(8)

func _walk_to(destination: Vector3, sprint: bool) -> void:
	for frame in 180:
		if _failed:
			return
		var remaining := Vector2(destination.x - _skeleton.position.x, destination.z - _skeleton.position.z)
		if remaining.length() < .25:
			return
		_move(remaining.normalized(), sprint)
		await get_tree().physics_frame
	var collision_paths: Array[String] = []
	for collision_index in _skeleton.get_slide_collision_count():
		collision_paths.append(str(_skeleton.get_slide_collision(collision_index).get_collider().get_path()))
	_fail("Route did not reach %s; actor %s; collisions %s" % [destination, _skeleton.position, collision_paths])

func _move(direction: Vector2, sprint: bool) -> void:
	var strengths := [maxf(-direction.x, 0), maxf(direction.x, 0), maxf(-direction.y, 0), maxf(direction.y, 0)]
	for index in 4:
		if strengths[index] > 0:
			Input.action_press(ACTIONS[index], strengths[index])
		else:
			Input.action_release(ACTIONS[index])
	if sprint:
		Input.action_press(&"run")
	else:
		Input.action_release(&"run")

func _pulse(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)

func _frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame

func _physics_process(_delta: float) -> void:
	if not _recording or _failed:
		return
	_sample_count += 1
	_skeleton_visible_frames += int(_in_frame(_skeleton))
	_knight_visible_frames += int(_in_frame(_knight))
	_maximum_height = maxf(_maximum_height, _skeleton.position.y)
	_knight_maximum_height = maxf(_knight_maximum_height, _knight.position.y)
	var knight_distance := _skeleton.position.distance_to(_knight.position)
	_nearest_knight = knight_distance if _nearest_knight < 0 else minf(_nearest_knight, knight_distance)
	if _gallery_jump_active and _skeleton.is_on_floor():
		_gallery_jump_active = false
		_event("gallery_landing")
	if _skeleton.movement.is_compact:
		_compact_frames += 1
	if not _skeleton.is_on_floor():
		_airborne_frames += 1
	if _knight.bot_controller._target_peer_id == _skeleton.peer_id:
		_pursuit_frames += 1
	var elapsed := Engine.get_process_frames() - _first_frame
	if elapsed % 6 == 0:
		_trace.append({"frame": elapsed, "skeleton": _vector(_skeleton.position), "knight": _vector(_knight.position), "compact": _skeleton.movement.is_compact, "airborne": not _skeleton.is_on_floor()})
	if _skeleton.is_dead:
		_fail("Knight captured the skeleton during shot at " + str(_skeleton.position))
	elif elapsed > _maximum_frames:
		_fail("Shot exceeded its ten-second choreography limit")

func _in_frame(actor: CharacterBody3D) -> bool:
	var frame := get_viewport().get_visible_rect().grow(-24)
	return not _camera.is_position_behind(actor.global_position) and frame.has_point(_camera.unproject_position(actor.global_position)) and frame.has_point(_camera.unproject_position(actor.global_position + Vector3.UP * 2.0))

func _assert_pursuit() -> void:
	_require(_pursuit_frames > 15, "Production knight AI tracks the visible skeleton")
	_require(_knight.position.distance_to(_knight_start) > 2.0, "Knight pursues using production navigation and movement")
	_require(_nearest_knight < 7.0, "Chase pressure remains visible and close")

func _event(event_name: String) -> void:
	var event := {"name": event_name, "frame": Engine.get_process_frames(), "shot_frame": Engine.get_process_frames() - _first_frame}
	_events.append(event)
	print("TRAILER_EVENT ", JSON.stringify(event))

func _require(condition: bool, description: String) -> bool:
	_checks.append({"passed": condition, "description": description})
	if not condition:
		_fail(description)
	return condition

func _fail(description: String) -> void:
	if _failed:
		return
	_failed = true
	print("TRAILER_FAILURE ", description)
	_finish()

func _finish() -> void:
	_recording = false
	_last_frame = Engine.get_process_frames()
	_release_input()
	var result := {"shot": _shot, "fixture_seed": 641, "passed": not _failed, "start_frame": _first_frame, "end_frame": _last_frame, "duration_frames": _last_frame - _first_frame, "fps": 60, "checks": _checks, "events": _events, "trace": _trace, "maximum_skeleton_height": _maximum_height, "maximum_knight_height": _knight_maximum_height, "airborne_frames": _airborne_frames, "compact_frames": _compact_frames, "pursuit_frames": _pursuit_frames, "nearest_knight": _nearest_knight, "sample_count": _sample_count, "skeleton_visible_frames": _skeleton_visible_frames, "knight_visible_frames": _knight_visible_frames, "actor_names": {"skeleton": Settings.player_name, "knight": NetworkManager.get_player_name(_knight.peer_id) if _knight != null else ""}}
	var result_path := OS.get_environment("GOMSTALLE_TRAILER_RESULT")
	if not result_path.is_empty():
		var output := FileAccess.open(result_path, FileAccess.WRITE)
		output.store_string(JSON.stringify(result, "\t"))
	print("TRAILER_RESULT ", JSON.stringify(result))
	_shutdown.call_deferred()

func _shutdown() -> void:
	GameState.quit(multiplayer)
	await get_tree().scene_changed
	await CastleAudio.shutdown()
	get_tree().quit(1 if _failed else 0)

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
