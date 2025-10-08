extends NinePatchRect

@export var main_section: VBoxContainer
@export var join_section: VBoxContainer
@export var join_lobby_list: VBoxContainer
@export var join_label: Label
@export var lobby_fetch_timer: Timer

func _ready() -> void:
	SteamManager.lobby_match_list_updated.connect(_set_rooms)
	lobby_fetch_timer.timeout.connect(func(): SteamManager.refresh_lobby_list())

func _on_join_pressed() -> void:
	join_section.visible = true
	main_section.visible = false

func _on_join_back_pressed() -> void:
	join_section.visible = false
	main_section.visible = true

func _on_host_pressed() -> void:
	GameState.create_and_join_lobby(func(success):
		if success:
			_on_start()
		else:
			pass # TODO: Show error
	)

func _on_join_room_pressed(room) -> void:
	GameState.join_lobby(room.id, func(success):
		if success:
			_on_start()
		else:
			pass # TODO: Show error
	)

func _set_rooms(rooms: Array) -> void:
	var no_rooms := len(rooms) == 0
	join_label.visible = no_rooms

	for child in join_lobby_list.get_children():
		join_lobby_list.remove_child(child)

	for room in rooms:
		var button = Button.new()
		button.text = "%s (%s)" % [room.name, room.num_members]
		button.pressed.connect(func(): _on_join_room_pressed(room))
		join_lobby_list.add_child(button)

func _on_start() -> void:
	GameState.enter_lobby()

func _exit_tree() -> void:
	SteamManager.lobby_match_list_updated.disconnect(_set_rooms)