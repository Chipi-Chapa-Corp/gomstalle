extends SceneTree

func _initialize() -> void:
	_load_scenario.call_deferred()

func _load_scenario() -> void:
	var scenario: GDScript = load("res://tests/scenarios/scene_loading_driver.gd")
	root.add_child(scenario.new())
