extends SceneTree

func _initialize() -> void:
	root.show()
	_capture.call_deferred()

func _capture() -> void:
	var scene_path := OS.get_environment("GOMSTALLE_LIGHTMAP_SCENE")
	var output_directory := OS.get_environment("GOMSTALLE_LIGHTMAP_CAPTURE_DIR")
	assert(not scene_path.is_empty() and not output_directory.is_empty())
	DirAccess.make_dir_recursive_absolute(output_directory)
	var scene: Node3D = load(scene_path).instantiate()
	if scene_path == "res://scenes/world/scene.tscn":
		scene.set_script(null)
		scene.get_node("UI").free()
	root.add_child(scene)
	current_scene = scene
	var camera := Camera3D.new()
	camera.fov = 65.0
	scene.add_child(camera)
	camera.current = true
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var views: Array[Dictionary] = [
		{"name": "library", "focus": Vector3(-24, 0, -4)},
		{"name": "alchemy", "focus": Vector3(31, 0, -6)},
		{"name": "banquet", "focus": Vector3(34, 0, 26)},
		{"name": "kitchen", "focus": Vector3(35, 0, 38)}
	]
	if OS.get_environment("GOMSTALLE_LIGHTMAP_PROOF") == "1":
		views = [{"name": "proof", "from": Vector3(6, 5, 6), "to": Vector3(0, 0.5, 0)}]
	var metrics: Array[Dictionary] = []
	for view in views:
		if view.has("focus"):
			camera.position = view["focus"] + Vector3(4.94975, 11, 4.94975)
			camera.rotation_degrees = Vector3(-55, 45, 0)
		else:
			camera.position = view["from"]
			camera.look_at(view["to"])
		for settling_frame in 45:
			await process_frame
		var frame_times: Array[float] = []
		var gpu_times: Array[float] = []
		var cpu_times: Array[float] = []
		for sample_frame in 60:
			var started := Time.get_ticks_usec()
			await process_frame
			frame_times.append(float(Time.get_ticks_usec() - started) / 1000.0)
			gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			cpu_times.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		frame_times.sort()
		gpu_times.sort()
		cpu_times.sort()
		metrics.append({"view": view["name"], "frame_ms_median": frame_times[30], "frame_ms_p95": frame_times[57],
			"render_gpu_ms": gpu_times[30], "render_cpu_ms": cpu_times[30],
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_directory.path_join(view["name"] + ".png"))
	var report := FileAccess.open(output_directory.path_join("metrics.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "\t"))
	print("LIGHTMAP_CAPTURE_COMPLETE ", JSON.stringify(metrics))
	quit()
