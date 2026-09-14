extends Node

class SceneSpawnConfig:
	var scene: PackedScene
	var amount: int
	var density: float
	var container_path: NodePath
	var configure_method: Callable
	var bounds: AABB

	func _init(scene_value: PackedScene, amount_value: int, density_value: float, container_path_value: NodePath, configure_method_value: Callable) -> void:
		scene = scene_value
		amount = amount_value
		density = density_value
		container_path = container_path_value
		configure_method = configure_method_value
		var instance: Node3D = scene.instantiate()
		var shapes: Array[AABB] = []
		for collision: CollisionShape3D in instance.find_children("*", "CollisionShape3D", true, false):
			var body: CollisionObject3D = collision.get_parent()
			if body.collision_layer & 1 == 0:
				continue
			var transform_value := collision.transform
			var parent := collision.get_parent()
			while parent != instance:
				transform_value = parent.transform * transform_value
				parent = parent.get_parent()
			shapes.append(transform_value * collision.shape.get_debug_mesh().get_aabb())
		assert(not shapes.is_empty(), "Generated obstacles require physical collision shapes.")
		bounds = shapes[0]
		for shape_bounds in shapes:
			bounds = bounds.merge(shape_bounds)
		var radius := 0.0
		for corner in 8:
			var endpoint := bounds.get_endpoint(corner)
			radius = maxf(radius, Vector2(endpoint.x, endpoint.z).length())
		bounds = AABB(Vector3(-radius, bounds.position.y, -radius), Vector3(radius * 2, bounds.size.y, radius * 2))
		instance.free()

var SPAWN_CONFIGS: Array[SceneSpawnConfig] = [
	SceneSpawnConfig.new(preload("res://scenes/pile/scene.tscn"), 40, 4.5, NodePath("Generated"), _configure_wood_pile),
]

var _configs := SPAWN_CONFIGS
var _generated_world_instance_id: int = 0
var _spawn_list: Array[Dictionary] = []
var _furniture_bounds: Array[AABB] = []
var _protected_positions: Array[Vector3] = []
var _navigation: CastleNavigation

func _ready() -> void:
	pass

func generate_for_world(world: Node3D) -> void:
	if not multiplayer.is_server():
		return
	var world_instance_id := world.get_instance_id()
	if _generated_world_instance_id == world_instance_id:
		return
	_generated_world_instance_id = world_instance_id
	_furniture_bounds = world.get_node("CastleDressing").get_furniture_bounds()
	_navigation = world.round_utils.navigation
	_protected_positions = [GameState.player_spawn_center]
	for shrine: Node3D in world.shrine_utils.shrine_nodes:
		_protected_positions.append(shrine.global_position)
	var grid_map: GridMap = world.grid_map
	assert(grid_map != null)
	var floor_cells := _eligible_floor_cells(grid_map)
	assert(not floor_cells.is_empty())
	var spawn_seed := int(Time.get_ticks_usec())
	_spawn_list = _build_spawn_list(grid_map, floor_cells, spawn_seed)
	_apply_spawn_list(_spawn_list)

func _eligible_floor_cells(grid_map: GridMap) -> Array[Vector3i]:
	var floor_cells := Utils.get_floor_cells(grid_map).filter(func(cell: Vector3i): return _navigation.can_reach_floor(_cell_position(grid_map, cell)))
	var wall_adjacent := Utils.get_wall_adjacent_floor_cells(grid_map)
	var preferred := floor_cells.filter(func(cell: Vector3i): return wall_adjacent.has(cell))
	return floor_cells if preferred.is_empty() else preferred

func synchronize_peer(peer_id: int) -> void:
	if multiplayer.is_server():
		_apply_spawn_list.rpc_id(peer_id, _spawn_list)

func _build_spawn_list(grid_map: GridMap, floor_cells: Array[Vector3i], spawn_seed: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed
	var spawn_list: Array[Dictionary] = []
	var used_positions: Array[Vector3] = []
	for config_index in _configs.size():
		var config := _configs[config_index]
		var max_attempts := config.amount * 25
		var spawned_for_config := 0
		var attempts := 0
		while spawned_for_config < config.amount and attempts < max_attempts:
			attempts += 1
			var cell: Vector3i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
			var position := _cell_position(grid_map, cell)
			if not _is_position_free(position, used_positions, config.density):
				continue
			var obstacle := AABB(position + config.bounds.position, config.bounds.size)
			if not _has_placement_clearance(obstacle) or not _navigation.try_reserve_obstacle(obstacle, position, CastleBotController.INTERACTION_DISTANCE):
				continue
			var instance_seed := int(rng.randi())
			spawn_list.append({"config_index": config_index, "cell": cell, "instance_seed": instance_seed})
			used_positions.append(position)
			spawned_for_config += 1
	return spawn_list

func _cell_position(grid_map: GridMap, cell: Vector3i) -> Vector3:
	return grid_map.to_global(grid_map.map_to_local(cell))

func _is_position_free(position: Vector3, used_positions: Array[Vector3], min_distance: float) -> bool:
	for protected in _protected_positions:
		if position.distance_to(protected) < 3.0:
			return false
	for furniture_bounds in _furniture_bounds:
		if furniture_bounds.grow(0.8).has_point(position):
			return false
	var position_2d := Vector2(position.x, position.z)
	for used_position in used_positions:
		if position_2d.distance_to(Vector2(used_position.x, used_position.z)) < min_distance:
			return false
	return true

func _has_placement_clearance(obstacle: AABB) -> bool:
	var shape := BoxShape3D.new()
	shape.size = obstacle.size + Vector3(0.7, 0, 0.7)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, obstacle.get_center() + Vector3.UP * 0.1)
	query.collision_mask = 1
	query.exclude = _navigation.excluded_bodies
	return _navigation.world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _get_or_create_container(world: Node3D, container_path: NodePath) -> Node3D:
	if container_path == NodePath("Generated"):
		var existing = world.get_node_or_null("Generated")
		if existing != null:
			assert(existing is Node3D)
			return existing as Node3D
		var generated_container := Node3D.new()
		generated_container.name = "Generated"
		world.add_child(generated_container)
		return generated_container
	var container = world.get_node(container_path)
	assert(container is Node3D)
	return container as Node3D

@rpc("authority", "call_local", "reliable")
func _apply_spawn_list(spawn_list: Array[Dictionary]) -> void:
	var world = get_tree().current_scene
	assert(world is Node3D)
	var grid_map: GridMap = world.grid_map
	assert(grid_map != null)
	for index in spawn_list.size():
		var entry: Dictionary = spawn_list[index]
		var config_index: int = entry["config_index"]
		var config := _configs[config_index]
		var target_container := _get_or_create_container(world as Node3D, config.container_path)
		var instance = config.scene.instantiate()
		assert(instance is Node3D)
		var instance_node: Node3D = instance
		instance_node.name = "Wood_%02d" % index
		target_container.add_child(instance_node)
		var cell: Vector3i = entry["cell"]
		var position := _cell_position(grid_map, cell)
		instance_node.global_position = position
		if config.configure_method != null:
			config.configure_method.call(instance_node, position, int(entry["instance_seed"]))

func _configure_wood_pile(instance: Node3D, _position: Vector3, instance_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = instance_seed
	instance.rotation.y = float(rng.randi_range(0, 3)) * PI * 0.5
