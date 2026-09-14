extends Node3D

const Actor := preload("res://scenes/midnight/actor.gd")
const Director := preload("res://scenes/midnight/director.gd")
const FilmOverlay := preload("res://scenes/midnight/overlay.gd")
const SoulShader := preload("res://scenes/midnight/soul.gdshader")

@export var score: AudioStream

var stage: Node3D
var camera := Camera3D.new()
var skeleton := Actor.new()
var knight := Actor.new()
var director := Director.new()
var overlay := FilmOverlay.new()
var score_player := AudioStreamPlayer.new()
var soul_material := ShaderMaterial.new()
var soul := MeshInstance3D.new()
var soul_light := OmniLight3D.new()
var magic_sparks: Array[MeshInstance3D] = []
var pages: Array[MeshInstance3D] = []
var candle_lights: Array[OmniLight3D] = []
var play_mode: Node
var elapsed := 0.0
var warmup_frames := 24
var playing := false
var capture_path := ""
var capture_time := -1.0
var recording := false
var first_recorded_frame := 0
var capture_started := false
var _quitting := false
var _play_magic_strength := 0.45

func _ready() -> void:
	CastleAudio.music.stop()
	CastleAudio.ambience.stop()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().use_taa = true
	RenderingServer.environment_set_volumetric_fog_volume_size(192, 128)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	stage = load("res://assets/castle/midnight_library/midnight_library.glb").instantiate()
	stage.name = "Library"
	add_child(stage)
	_lighting()
	_magic()
	skeleton.name = "Wanderer"
	knight.name = "Keeper"
	add_child(skeleton)
	add_child(knight)
	skeleton.configure(false)
	knight.configure(true)
	camera.name = "FilmCamera"
	camera.near = 0.08
	camera.far = 80.0
	add_child(camera)
	camera.make_current()
	director.configure(camera, skeleton, knight)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(overlay)
	add_child(score_player)
	score_player.stream = score
	recording = OS.get_environment("GOMSTALLE_FILM_RECORD") == "1"
	capture_path = OS.get_environment("GOMSTALLE_FILM_CAPTURE")
	if not OS.get_environment("GOMSTALLE_FILM_TIME").is_empty():
		capture_time = float(OS.get_environment("GOMSTALLE_FILM_TIME"))
	overlay.show_controls = not recording and capture_path.is_empty()
	_update_film(maxf(capture_time, 0.0))

func _lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("091524")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("819ebd")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.ssao_enabled = true
	environment.ssao_radius = 0.7
	environment.ssao_intensity = 1.65
	environment.ssil_enabled = true
	environment.ssil_radius = 4.0
	environment.ssil_intensity = 0.65
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.06
	environment.glow_hdr_threshold = 1.15
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.011
	environment.volumetric_fog_albedo = Color("9bb3c4")
	environment.volumetric_fog_emission = Color("14212d")
	environment.volumetric_fog_emission_energy = 0.28
	environment.volumetric_fog_length = 40.0
	environment.volumetric_fog_detail_spread = 1.2
	environment.volumetric_fog_ambient_inject = 0.25
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var moonlight := _spot(Vector3(0, 6.3, -10.25), Vector3(1.5, 0, 5), Color("c2d8ff"), 13.0, 27.0, 36.0, 2.5)
	moonlight.light_projector = preload("res://assets/castle/midnight_library/moon_window.png")
	_spot(Vector3(-6, 8, -6), Vector3(1, 0, 4), Color("84afed"), 4.0, 23.0, 49.0, 0.3)
	_spot(Vector3(5, 7, 7), Vector3(0, 1, -2), Color("ffcc8d"), 2.0, 21.0, 52.0, 0.1)
	_omni(Vector3(0, 5.5, 3.0), Color("8daed7"), 0.55, 17.0, false)
	for location in [Vector3(-6.61, 7.14, -9.65), Vector3(6.61, 7.14, -9.65), Vector3(-6.61, 6.54, 4.2), Vector3(6.61, 6.54, 4.2)]:
		var light := _omni(location, Color("ffb65f"), 2.0, 6.8, true)
		candle_lights.append(light)
	for location in [Vector3(-2.8, 7.88, -2.0), Vector3(2.8, 7.88, -6.2)]:
		var light := _omni(location, Color("ffc67d"), 2.1, 9.5, false)
		candle_lights.append(light)
	var probe := ReflectionProbe.new()
	probe.position = Vector3(0, 4, 0)
	probe.size = Vector3(17, 10, 24)
	probe.interior = true
	probe.box_projection = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color("7896b7")
	probe.ambient_color_energy = 0.3
	probe.max_distance = 30
	add_child(probe)

func _spot(location: Vector3, target: Vector3, color: Color, energy: float, distance: float, angle: float, fog: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.position = location
	light.light_color = color
	light.light_energy = energy
	light.light_volumetric_fog_energy = fog
	light.spot_range = distance
	light.spot_angle = angle
	light.spot_attenuation = 0.85
	light.spot_angle_attenuation = 0.65
	light.shadow_enabled = true
	light.light_size = 0.22
	add_child(light)
	light.look_at(target)
	return light

func _omni(location: Vector3, color: Color, energy: float, distance: float, shadows: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = location
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	light.omni_attenuation = 1.2
	light.light_size = 0.16
	light.light_volumetric_fog_energy = 0.14
	light.shadow_enabled = shadows
	add_child(light)
	return light

func _magic() -> void:
	stage.find_child("MidnightLibrary_MoonGlass_glass", true, false).hide()
	soul_material.shader = SoulShader
	var sphere := SphereMesh.new()
	sphere.radius = 0.72
	sphere.height = 1.44
	sphere.radial_segments = 48
	sphere.rings = 24
	sphere.material = soul_material
	soul.mesh = sphere
	soul.position = Vector3(0, 2.0, -5.15)
	add_child(soul)
	soul_light.position = soul.position
	soul_light.light_color = Color("79efce")
	soul_light.light_energy = 1.4
	soul_light.omni_range = 7
	soul_light.light_volumetric_fog_energy = 1.2
	add_child(soul_light)
	var sparkle_material := StandardMaterial3D.new()
	sparkle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle_material.albedo_color = Color("a5ffdf")
	sparkle_material.emission_enabled = true
	sparkle_material.emission = Color("62e9c0")
	sparkle_material.emission_energy_multiplier = 3.0
	var sparkle := SphereMesh.new()
	sparkle.radius = 0.017
	sparkle.height = 0.034
	sparkle.radial_segments = 8
	sparkle.rings = 4
	sparkle.material = sparkle_material
	for index in 90:
		var spark := MeshInstance3D.new()
		spark.mesh = sparkle
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		magic_sparks.append(spark)
	var paper_material := StandardMaterial3D.new()
	paper_material.albedo_color = Color("d9c7a4")
	paper_material.roughness = 0.9
	paper_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var paper := PlaneMesh.new()
	paper.size = Vector2(0.26, 0.4)
	paper.material = paper_material
	for index in 15:
		var page := MeshInstance3D.new()
		page.mesh = paper
		add_child(page)
		pages.append(page)
	var dust_material := StandardMaterial3D.new()
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.albedo_color = Color(0.55, 0.64, 0.61, 0.32)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mote := QuadMesh.new()
	mote.size = Vector2(0.012, 0.012)
	mote.material = dust_material
	var dust := GPUParticles3D.new()
	dust.amount = 220
	dust.lifetime = 22.0
	dust.preprocess = 20.0
	dust.visibility_aabb = AABB(Vector3(-8, 0, -11), Vector3(16, 10, 22))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(7, 4.5, 10)
	process.gravity = Vector3(0.01, -0.025, 0.005)
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.08
	dust.process_material = process
	dust.position = Vector3(0, 5, 0)
	dust.draw_pass_1 = mote
	add_child(dust)

func _process(delta: float) -> void:
	if _quitting:
		return
	if warmup_frames > 0:
		warmup_frames -= 1
		if warmup_frames == 0 and capture_time < 0:
			playing = true
			first_recorded_frame = Engine.get_process_frames()
			if score != null:
				score_player.play()
		return
	if not capture_path.is_empty() and not capture_started:
		capture_started = true
		_capture.call_deferred()
	if playing:
		elapsed = minf(elapsed + delta, Director.DURATION)
		_update_film(elapsed)
		if elapsed >= Director.DURATION:
			playing = false
			if recording:
				var report := {"start_frame": first_recorded_frame, "end_frame": Engine.get_process_frames(), "duration_seconds": Director.DURATION, "shot_names": Director.SHOT_NAMES}
				var report_path := OS.get_environment("GOMSTALLE_FILM_RESULT")
				FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
				_quit.call_deferred()
	elif is_instance_valid(play_mode):
		elapsed += delta
		var target_strength := 1.0 if play_mode.library_awake else 0.45
		_play_magic_strength = lerpf(_play_magic_strength, target_strength, 1.0 - exp(-2.4 * delta))
		_animate_magic(elapsed, _play_magic_strength)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var viewport := get_viewport()
	if _handle_scene_key(event as InputEventKey):
		viewport.set_input_as_handled()

func _update_film(time: float) -> void:
	director.evaluate(time)
	_animate_magic(time, director.magic_strength)
	overlay.title_opacity = director.title_opacity
	overlay.fade_opacity = 1.0 - smoothstep(0.0, 0.9, time) if time < 1.0 else smoothstep(37.3, 38.0, time)
	overlay.queue_redraw()

func _animate_magic(time: float, strength: float) -> void:
	soul_material.set_shader_parameter("clock", time)
	soul_material.set_shader_parameter("strength", strength)
	soul.position.y = 2.0 + sin(time * 1.6) * 0.055
	soul_light.light_energy = 1.0 + strength * 3.5
	for index in magic_sparks.size():
		var phase := float(index) * 2.399963
		var height := fposmod(float(index) * 0.193 + time * (0.2 + strength * 0.2), 5.0)
		var radius := 0.65 + height * 0.26 + sin(phase * 2.0) * 0.2
		magic_sparks[index].position = Vector3(cos(phase + time * 0.8) * radius, 0.8 + height, -5 + sin(phase + time * 0.8) * radius)
		magic_sparks[index].scale = Vector3.ONE * (0.35 + strength * 1.2) * sin(height / 5.0 * PI)
	for index in pages.size():
		var phase := float(index) * 2.399963 + time * 0.45
		var radius := 1.2 + float(index % 4) * 0.33
		pages[index].visible = strength > 0.4
		pages[index].position = Vector3(cos(phase) * radius, 1.2 + float(index) * 0.24 + sin(time * 1.2 + phase) * 0.16, -5 + sin(phase) * radius)
		pages[index].rotation = Vector3(sin(time + phase) * 0.4, -phase, cos(time * 1.5 + phase) * 0.35)
	for index in candle_lights.size():
		candle_lights[index].light_energy = 2.0 + sin(time * 4.2 + float(index) * 2.1) * 0.08 + sin(time * 7.9 + index) * 0.045

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var viewport := get_viewport()
	if _handle_scene_key(event as InputEventKey):
		viewport.set_input_as_handled()

func _handle_scene_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	if key == KEY_TAB and not is_instance_valid(play_mode):
		_enter_play()
		return true
	if key == KEY_R and not is_instance_valid(play_mode):
		elapsed = 0
		playing = true
		if score != null:
			score_player.play()
		return true
	if key == KEY_ESCAPE:
		_leave_library()
		return true
	return false

func _leave_library() -> void:
	playing = false
	score_player.stop()
	if is_instance_valid(play_mode):
		play_mode.finish()
	CastleAudio.music.play()
	CastleAudio.ambience.play()
	get_tree().change_scene_to_file("res://scenes/main/scene.tscn")

func _enter_play() -> void:
	playing = false
	_play_magic_strength = 0.45
	skeleton.hide()
	knight.hide()
	overlay.cinematic = false
	overlay.title_opacity = 0
	overlay.fade_opacity = 0
	overlay.queue_redraw()
	camera.attributes = null
	play_mode = load("res://scenes/midnight/play.gd").new()
	add_child(play_mode)
	play_mode.return_to_film.connect(_return_to_film)
	play_mode.begin(self, camera)

func _return_to_film() -> void:
	play_mode.finish()
	play_mode.queue_free()
	play_mode = null
	camera.make_current()
	camera.attributes = director.attributes
	overlay.cinematic = true
	elapsed = 0
	playing = true
	if score != null:
		score_player.play()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var rendered := get_viewport().get_texture().get_image()
	var result := rendered.save_png(capture_path)
	print("MIDNIGHT_CAPTURE ", JSON.stringify({"path": capture_path, "time": capture_time, "shot": Director.SHOT_NAMES[director.shot_index], "camera": str(camera.position), "saved": result == OK}))
	await _quit()

func _quit() -> void:
	_quitting = true
	score_player.stop()
	await CastleAudio.shutdown()
	get_tree().quit()
