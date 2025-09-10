extends NinePatchRect

@onready var game_scene: PackedScene = preload("res://scenes/world/scene.tscn")

func _on_host_pressed() -> void:
	Settings.is_host = true
	_on_start()

func _on_join_room(room) -> void:
	var on_join_reply = func(ok: bool, net_id: int, host: Dictionary):
		if not ok:
			_on_join_back_pressed()
			return
		Settings.net_id = net_id
		if host and host.has("ip") and host.has("port"):
			Settings.lobby_host = host.ip
			Settings.lobby_port = int(host.port)
		_on_start()

	Registry.join_reply.connect(on_join_reply)
	Registry.join_room(room.id)

func _on_join_pressed() -> void:
	Registry.rooms_updated.connect(_set_rooms)
	var ok := await Registry.ensure_connected(Settings.get_registry_url())
	if not ok:
		print("Error: failed to connect to registry")
		return
	Settings.is_host = false
	$Join.visible = true
	$Main.visible = false
	print("Registry.rooms", Registry.rooms)
	_set_rooms(Registry.rooms)
	# _on_start()

func _set_rooms(rooms: Array) -> void:
	var no_rooms := len(rooms) == 0
	$Join/Searching.visible = no_rooms

	for child in $Join/List.get_children():
		$Join/List.remove_child(child)

	for room in rooms:
		var button = Button.new()
		button.text = room.id
		button.pressed.connect(func(): _on_join_room(room))
		$Join/List.add_child(button)

func _on_join_back_pressed() -> void:
	$Join.visible = false
	$Main.visible = true

func _on_start() -> void:
	get_tree().change_scene_to_packed(game_scene)
