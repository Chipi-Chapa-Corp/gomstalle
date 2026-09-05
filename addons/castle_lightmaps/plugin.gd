@tool
extends EditorPlugin

var _importing: bool = false
var _last_import_finished: int = 0

func _enter_tree() -> void:
	if OS.get_environment("GOMSTALLE_LIGHTMAP_SCENE").is_empty():
		return
	EditorInterface.get_resource_filesystem().resources_reimporting.connect(func(_paths: PackedStringArray): _importing = true)
	EditorInterface.get_resource_filesystem().resources_reimported.connect(func(_paths: PackedStringArray):
		_importing = false
		_last_import_finished = Time.get_ticks_msec())
	_bake.call_deferred()

func _bake() -> void:
	for startup_frame in 20:
		await get_tree().process_frame
	var scene_path := OS.get_environment("GOMSTALLE_LIGHTMAP_SCENE")
	assert(not scene_path.is_empty(), "GOMSTALLE_LIGHTMAP_SCENE must identify the prepared static scene.")
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	EditorInterface.open_scene_from_path(scene_path)
	while EditorInterface.get_edited_scene_root() == null or EditorInterface.get_edited_scene_root().scene_file_path != scene_path:
		await get_tree().process_frame
	var scene := EditorInterface.get_edited_scene_root()
	var lightmap: LightmapGI = scene.get_node("LightmapGI")
	EditorInterface.edit_node(lightmap)
	_last_import_finished = Time.get_ticks_msec()
	while _importing or EditorInterface.get_resource_filesystem().is_scanning() or Time.get_ticks_msec() - _last_import_finished < 2000:
		await get_tree().process_frame
	var bake_button: Button
	for control in EditorInterface.get_base_control().find_children("*", "Button", true, false):
		for connection in control.get_signal_connection_list("pressed"):
			var callback: Callable = connection["callable"]
			if callback.get_object().get_class() == &"LightmapGIEditorPlugin":
				bake_button = control
				break
		if bake_button != null:
			break
	assert(bake_button != null and not bake_button.disabled, "Native lightmap baking must be available.")
	var started := Time.get_ticks_msec()
	bake_button.pressed.emit()
	if lightmap.light_data.get_lightmap_textures().is_empty():
		push_error("Native lightmap bake produced no textures.")
		get_tree().quit(1)
		return
	EditorInterface.save_scene()
	print("LIGHTMAP_BAKE_COMPLETE elapsed_ms=", Time.get_ticks_msec() - started)
	await get_tree().process_frame
	get_tree().quit()
