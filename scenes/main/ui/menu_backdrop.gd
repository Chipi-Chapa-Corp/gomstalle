class_name CastleMenuBackdrop
extends Node3D

var _camera: Camera3D
var _elapsed := 0.0
var _candles: Array[OmniLight3D] = []

func _ready() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101c24")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("85a9bc")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	environment_node.environment = environment
	add_child(environment_node)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -35, 0)
	moon.light_color = Color("94bed9")
	moon.light_energy = 1.3
	moon.shadow_enabled = true
	add_child(moon)
	for floor_x in range(-3, 4):
		for floor_z in range(-2, 3):
			_prop("floor_tile_large", Vector3(floor_x * 4, -0.15, floor_z * 4))
	for wall_x in range(-2, 4):
		_prop("wall", Vector3(wall_x * 4, 0, -7))
	for pillar_x in [-6.0, 2.0, 10.0]:
		_prop("pillar_decorated", Vector3(pillar_x, 0, -6.7))
	_prop("banner_patternB_red", Vector3(6, 2.8, -6.8))
	_prop("table_medium_decorated_A", Vector3(3.8, 0, -1), 0.2)
	_prop("barrel_large_decorated", Vector3(8, 0, -4))
	_prop("barrel_small", Vector3(7, 0, -4.8))
	_prop("chest_gold", Vector3(7.2, 0, 2.4), -0.7)
	_prop("candle_triple", Vector3(4.2, 1.5, -1))
	_prop("candle_lit", Vector3(1.4, 0, 2.3))
	_character("Skeleton_Minion", Vector3(2.2, 0, 0.7), 0.3)
	_character("Knight", Vector3(6.4, 0, -2.4), -0.55)
	for candle_position in [Vector3(4.2, 2.2, -1), Vector3(1.4, 0.7, 2.3), Vector3(7, 2, -5)]:
		var light := OmniLight3D.new()
		light.position = candle_position
		light.light_color = Color("ffb663")
		light.light_energy = 3.0
		light.omni_range = 7.0
		light.shadow_enabled = true
		add_child(light)
		_candles.append(light)
	_camera = Camera3D.new()
	_camera.position = Vector3(14, 11, 18)
	_camera.fov = 40
	add_child(_camera)
	_camera.look_at(Vector3(0, 1, -0.5))
	_camera.current = true

func _process(delta: float) -> void:
	_elapsed += delta
	_camera.position.x = 14.0 + sin(_elapsed * 0.12) * 0.4
	_camera.look_at(Vector3(0, 1, -0.5))
	for light_index in _candles.size():
		_candles[light_index].light_energy = 3.0 + sin(_elapsed * 4.0 + light_index) * 0.15

func _prop(model_name: String, origin: Vector3, yaw: float = 0.0) -> void:
	var scene := load("res://assets/dungeon/models/%s.gltf" % model_name) as PackedScene
	var prop := scene.instantiate() as Node3D
	prop.position = origin
	prop.rotation.y = yaw
	add_child(prop)

func _character(model_name: String, origin: Vector3, yaw: float) -> void:
	var scene := load("res://assets/models/%s.glb" % model_name) as PackedScene
	var character := scene.instantiate() as Node3D
	character.position = origin
	character.rotation.y = yaw
	character.scale = Vector3.ONE * 1.45
	add_child(character)
	for child in character.find_children("*", "AnimationPlayer"):
		var animation_player := child as AnimationPlayer
		for animation_name in animation_player.get_animation_list():
			if "Idle" in animation_name:
				animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
				animation_player.play(animation_name)
				break
