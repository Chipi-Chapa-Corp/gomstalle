extends SceneTree

func _initialize() -> void:
	_load_scenario.call_deferred()

func _load_scenario() -> void:
	var scenario_script: GDScript = load("res://tests/scenarios/bot_round_driver.gd")
	root.add_child(scenario_script.new())
