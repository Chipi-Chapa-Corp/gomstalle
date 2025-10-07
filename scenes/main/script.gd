extends NinePatchRect

@export var world_scene: PackedScene

@onready var MainSection = $Main
@onready var JoinSection = $Join
@onready var JoinLobbyList = $Join/List/Scrollable/Container
@onready var JoinSearching = $Join/Searching

func _on_join_pressed() -> void:
	SteamManager.lobby_match_list_updated.connect(_set_rooms)
	SteamManager.refresh_lobby_list()
	JoinSection.visible = true
	MainSection.visible = false

func _on_host_pressed() -> void:
	Settings.is_host = true
	var on_created = func(error):
		if error:
			push_error("Failed to create lobby: %s" % error)
			return
		_on_start()

	SteamManager.lobby_created.connect(on_created)
	SteamManager.create_lobby()

func _on_join_room_pressed(room) -> void:
	Settings.is_host = false
	var on_join_reply = func(error):
		if error:
			push_error("Failed to join lobby: %s" % error)
			_on_join_back_pressed()
			return
		_on_start()

	GameState.room_id = room.id
	SteamManager.lobby_joined.connect(on_join_reply)
	SteamManager.join_lobby(room.id)

func _on_join_back_pressed() -> void:
	SteamManager.lobby_match_list_updated.disconnect(_set_rooms)
	JoinSection.visible = false
	MainSection.visible = true

func _set_rooms(rooms: Array) -> void:
	var no_rooms := len(rooms) == 0
	JoinSearching.visible = no_rooms

	for child in JoinLobbyList.get_children():
		JoinLobbyList.remove_child(child)

	for room in rooms:
		var button = Button.new()
		button.text = "%s (%s)" % [room.name, room.num_members]
		button.pressed.connect(func(): _on_join_room_pressed(room))
		JoinLobbyList.add_child(button)

func _on_start() -> void:
	GameState.enter_lobby()
	get_tree().change_scene_to_packed(world_scene)
