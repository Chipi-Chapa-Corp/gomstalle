extends Node

class SceneSpawnConfig:
	var scene: PackedScene
	var amount: int
	var density: float
	var container_path: NodePath
	var configure_method: Callable

	func _init(scene_value: PackedScene, amount_value: int, density_value: float, container_path_value: NodePath, configure_method_value: Callable) -> void:
		scene = scene_value
		amount = amount_value
		density = density_value
		container_path = container_path_value
		configure_method = configure_method_value

var SPAWN_CONFIGS: Array[SceneSpawnConfig] = [
	SceneSpawnConfig.new(preload("res://scenes/pile/scene.tscn"), 40, 4.5, NodePath("Generated"), _configure_wood_pile),
]

var _configs := SPAWN_CONFIGS
var _generated_world_instance_id: int = 0

func _ready() -> void:
	pass

func generate_for_world(world: Node3D) -> void:
	if not multiplayer.is_server():
		return
	var world_instance_id := world.get_instance_id()
	if _generated_world_instance_id == world_instance_id:
		return
	_generated_world_instance_id = world_instance_id
	var grid_map: GridMap = world.grid_map
	assert(grid_map != null)
	var floor_cells: Array[Vector3i] = Utils.get_wall_adjacent_floor_cells(grid_map)
	if floor_cells.is_empty():
		floor_cells = Utils.get_floor_cells(grid_map)
	assert(not floor_cells.is_empty())
	var spawn_seed := int(Time.get_ticks_usec())
	var spawn_list := _build_spawn_list(grid_map, floor_cells, spawn_seed)
	_apply_spawn_list.rpc(spawn_list)

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
			var instance_seed := int(rng.randi())
			spawn_list.append({"config_index": config_index, "cell": cell, "instance_seed": instance_seed})
			used_positions.append(position)
			spawned_for_config += 1
	return spawn_list

func _cell_position(grid_map: GridMap, cell: Vector3i) -> Vector3:
	return grid_map.to_global(grid_map.map_to_local(cell))

func _is_position_free(position: Vector3, used_positions: Array[Vector3], min_distance: float) -> bool:
	var position_2d := Vector2(position.x, position.z)
	for used_position in used_positions:
		if position_2d.distance_to(Vector2(used_position.x, used_position.z)) < min_distance:
			return false
	return true

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
	for entry in spawn_list:
		var config_index: int = entry["config_index"]
		var config := _configs[config_index]
		var target_container := _get_or_create_container(world as Node3D, config.container_path)
		var instance = config.scene.instantiate()
		assert(instance is Node3D)
		var instance_node: Node3D = instance
		target_container.add_child(instance_node)
		var cell: Vector3i = entry["cell"]
		var position := _cell_position(grid_map, cell)
		instance_node.global_position = position
		if config.configure_method != null:
			config.configure_method.call(instance_node, position, int(entry["instance_seed"]))

func _configure_wood_pile(instance: Node3D, _position: Vector3, instance_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = instance_seed
	instance.rotation.y = rng.randf_range(0.0, TAU)
