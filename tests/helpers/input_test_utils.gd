extends Object

class_name InputTestUtils

static func apply_movement_input(input_vector: Vector2, run: bool) -> void:
	release_movement_inputs()
	var horizontal = clampf(input_vector.x, -1.0, 1.0)
	var vertical = clampf(input_vector.y, -1.0, 1.0)
	if horizontal < 0.0:
		Input.action_press("move_left", -horizontal)
	elif horizontal > 0.0:
		Input.action_press("move_right", horizontal)
	if vertical < 0.0:
		Input.action_press("move_forward", -vertical)
	elif vertical > 0.0:
		Input.action_press("move_backward", vertical)
	if run:
		Input.action_press("run")

static func release_movement_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("run")

static func release_input_actions() -> void:
	release_movement_inputs()
	Input.action_release("interact")

static func press_action(tree: SceneTree, action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	release.strength = 0.0
	Input.parse_input_event(release)
	await tree.physics_frame
