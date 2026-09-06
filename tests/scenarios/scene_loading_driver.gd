extends Node

var _observed_cover: bool = false
var _finished: bool = false
var _started_at: int

func _ready() -> void:
	_started_at = Time.get_ticks_msec()
	get_tree().change_scene_to_file(GameState.main_scene)
	await get_tree().scene_changed
	get_tree().current_scene._host(true, false)

func _process(_delta: float) -> void:
	if _finished:
		return
	if Time.get_ticks_msec() - _started_at > 30000:
		_finish(false, "Loading did not complete within 30 seconds.")
		return
	_observed_cover = _observed_cover or SceneLoading.visible
	var world := get_tree().current_scene
	if world == null or world.scene_file_path != GameState.world_scene or SceneLoading.visible:
		return
	if not _observed_cover:
		_finish(false, "World appeared without the loading cover.")
		return
	if not world.round_utils.initialized:
		_finish(false, "Loading cover disappeared before round initialization.")
		return
	var player: CharacterBody3D = world.player_container.get_node(str(multiplayer.get_unique_id()))
	var camera := get_viewport().get_camera_3d()
	if camera != player.camera:
		_finish(false, "First visible world camera does not belong to the local player.")
		return
	var expected: Vector3 = player.global_position + player.camera_utils.camera_offset
	if camera.global_position.distance_to(expected) > 0.1:
		_finish(false, "First visible world camera is not at the spawn position.")
		return
	_finish(true, "Loading cover persists until the round and local camera are ready.")

func _finish(passed: bool, message: String) -> void:
	_finished = true
	print("SCENE_LOADING ", JSON.stringify({"passed": passed, "check": message}))
	if passed and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := OS.get_environment("GOMSTALLE_LOADING_FRAME")
		if not output.is_empty():
			get_viewport().get_texture().get_image().save_png(output)
	GameState.quit(multiplayer)
	await get_tree().process_frame
	await CastleAudio.shutdown()
	get_tree().quit(0 if passed else 1)
