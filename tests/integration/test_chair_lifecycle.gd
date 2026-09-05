extends GutTest

const ChairScene := preload("res://scenes/chair/scene.tscn")

func test_unused_chair_releases_duplicated_carry_collision() -> void:
	var scene: Node3D = ChairScene.instantiate()
	add_child(scene)
	var chair: RigidBody3D = scene.get_node("RigidBody3D")
	var shadow: CollisionShape3D = chair.collision_shadow
	assert_true(is_instance_valid(shadow))
	scene.free()
	assert_false(is_instance_valid(shadow), "An uncarried chair must release its detached collision copy")

func test_pickup_drop_and_destruction_release_carry_collision() -> void:
	var carrier := CharacterBody3D.new()
	add_child(carrier)
	var scene: Node3D = ChairScene.instantiate()
	add_child(scene)
	var chair: RigidBody3D = scene.get_node("RigidBody3D")
	var shadow: CollisionShape3D = chair.collision_shadow
	chair._set_collision_exclusion(carrier, true)
	assert_eq(shadow.get_parent(), carrier)
	chair._set_collision_exclusion(carrier, false)
	assert_null(shadow.get_parent())
	scene.free()
	assert_false(is_instance_valid(shadow))
	carrier.free()

func test_destroying_carried_chair_removes_collision_from_carrier() -> void:
	var carrier := CharacterBody3D.new()
	add_child(carrier)
	var scene: Node3D = ChairScene.instantiate()
	add_child(scene)
	var chair: RigidBody3D = scene.get_node("RigidBody3D")
	var shadow: CollisionShape3D = chair.collision_shadow
	chair._set_collision_exclusion(carrier, true)
	scene.free()
	assert_false(is_instance_valid(shadow))
	assert_eq(carrier.get_child_count(), 0)
	carrier.free()

func test_carrier_can_be_destroyed_before_the_carried_chair() -> void:
	var carrier := CharacterBody3D.new()
	add_child(carrier)
	var scene: Node3D = ChairScene.instantiate()
	add_child(scene)
	var chair: RigidBody3D = scene.get_node("RigidBody3D")
	var shadow: CollisionShape3D = chair.collision_shadow
	chair._set_collision_exclusion(carrier, true)
	carrier.free()
	assert_false(is_instance_valid(shadow))
	scene.free()
	assert_false(is_instance_valid(scene))
