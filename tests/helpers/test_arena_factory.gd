extends Object

class_name TestArenaFactory

static func create(world: Node3D, origin: Vector3) -> Node3D:
	var arena = Node3D.new()
	arena.name = "TestArena"
	world.add_child(arena)
	arena.global_position = origin
	var floor = StaticBody3D.new()
	floor.name = "Floor"
	var floor_shape = CollisionShape3D.new()
	var floor_box = BoxShape3D.new()
	floor_box.size = Vector3(20, 1, 20)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor.add_child(floor_shape)
	arena.add_child(floor)
	return arena
