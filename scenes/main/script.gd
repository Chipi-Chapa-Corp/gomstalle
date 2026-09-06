extends Control

var _main: VBoxContainer
var _modal: PanelContainer
var _modal_content: VBoxContainer
var _status: Label
var _role_buttons: Array[Button] = []
var _busy := false
var _room_list: VBoxContainer
var _loading: Control
var _world_requested := false

func _ready() -> void:
	theme = CastleTheme.create()
	add_child(CastleMenuBackdrop.new())
	_build_menu()
	_status.text = NetworkManager.last_error
	_status.visible = not _status.text.is_empty()
	NetworkManager.lobby_match_list_updated.connect(_set_rooms)
	_handle_autostart.call_deferred()

func _build_menu() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("1b1715e0"))
	gradient.set_color(1, Color("1b171500"))
	gradient.add_point(0.4, Color("1b171580"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	var shade := TextureRect.new()
	shade.texture = texture
	CastleTheme.full_rect(shade)
	add_child(shade)
	var margin := MarginContainer.new()
	CastleTheme.full_rect(margin)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(center)
	_main = VBoxContainer.new()
	_main.custom_minimum_size.x = 440
	_main.add_theme_constant_override("separation", 18)
	center.add_child(_main)
	var title := CastleTheme.label("Gömställe", 90, CastleTheme.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", CastleTheme.INK)
	title.add_theme_constant_override("shadow_offset_y", 5)
	_main.add_child(title)
	var roles := HBoxContainer.new()
	_main.add_child(roles)
	for role_index in 2:
		var button := CastleTheme.button(tr("Skeleton") if role_index == 0 else tr("Knight"), _select_role.bind(role_index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roles.add_child(button)
		_role_buttons.append(button)
	_select_role(Settings.preferred_role)
	_main.add_child(CastleTheme.button(tr("Play solo"), _host.bind(true, false), true))
	var friends := HBoxContainer.new()
	_main.add_child(friends)
	var host := CastleTheme.button(tr("Host"), _host.bind(false, false))
	host.tooltip_text = tr("Host a LAN game")
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends.add_child(host)
	var join := CastleTheme.button(tr("Join"), _show_join)
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends.add_child(join)
	var options := HBoxContainer.new()
	_main.add_child(options)
	for entry in [[tr("Settings"), _show_settings], [tr("Controls"), _show_help]]:
		var button := CastleTheme.button(entry[0], entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options.add_child(button)
	_main.add_child(CastleTheme.button(tr("Quit"), CastleAudio.quit_game))
	_status = CastleTheme.paragraph("", 22, CastleTheme.PAPER)
	_status.add_theme_color_override("font_outline_color", CastleTheme.INK)
	_status.add_theme_constant_override("outline_size", 4)
	_status.visible = false
	_main.add_child(_status)
	var modal_center := CenterContainer.new()
	CastleTheme.full_rect(modal_center)
	add_child(modal_center)
	_modal = PanelContainer.new()
	_modal.custom_minimum_size.x = 620
	_modal.visible = false
	modal_center.add_child(_modal)
	_modal_content = VBoxContainer.new()
	_modal.add_child(_modal_content)

func _select_role(role: int) -> void:
	Settings.preferred_role = role
	for role_index in _role_buttons.size():
		var selected_color := CastleTheme.MINT if role_index == 0 else CastleTheme.DANGER
		var fill := selected_color if role_index == role else Color("c4ae8a")
		_role_buttons[role_index].add_theme_stylebox_override("normal", CastleTheme.button_style(fill))
		_role_buttons[role_index].add_theme_stylebox_override("hover", CastleTheme.button_style(fill.lightened(0.15)))

func _open_modal(title: String) -> void:
	for child in _modal_content.get_children():
		_modal_content.remove_child(child)
		child.queue_free()
	_main.visible = false
	_modal.visible = true
	_modal_content.add_child(CastleTheme.label(title, 40))

func _close_modal() -> void:
	_modal.visible = false
	_main.visible = true

func _show_help() -> void:
	_open_modal(tr("Controls"))
	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 32)
	controls.add_theme_constant_override("v_separation", 8)
	_modal_content.add_child(controls)
	for entry in [
		["WASD", tr("Move")],
		["Shift", tr("Sprint")],
		["Space", tr("Jump")],
		["F", tr("Air slide while airborne (skeleton)")],
		["E", tr("Interact / pick up / offer wood")],
		[tr("Left mouse"), tr("Strike / throw")],
		[tr("Right mouse"), tr("Aim")],
		["Esc", tr("Menu")],
	]:
		controls.add_child(CastleTheme.label(entry[0], 22))
		controls.add_child(CastleTheme.label(entry[1], 22, CastleTheme.MUTED))
	_modal_content.add_child(CastleTheme.paragraph(tr("Skeleton: Fill three shrines with wood, then escape through the portal."), 22))
	_modal_content.add_child(CastleTheme.paragraph(tr("Knight: Catch every skeleton before time runs out."), 22))
	_modal_content.add_child(CastleTheme.button(tr("Back"), _close_modal))

func _show_settings() -> void:
	_open_modal(tr("Settings"))
	_modal_content.add_child(CastleTheme.label(tr("Name"), 22, CastleTheme.MUTED))
	var name_input := LineEdit.new()
	name_input.text = Settings.player_name
	name_input.max_length = 24
	name_input.text_changed.connect(func(value: String): Settings.player_name = value.strip_edges() if not value.strip_edges().is_empty() else "Wanderer")
	_modal_content.add_child(name_input)
	_modal_content.add_child(CastleTheme.label(tr("Volume"), 22, CastleTheme.MUTED))
	var volume := HSlider.new()
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = Settings.master_volume
	volume.custom_minimum_size.y = 36
	volume.value_changed.connect(func(value: float): Settings.master_volume = value; Settings.apply())
	_modal_content.add_child(volume)
	var fullscreen := CheckButton.new()
	fullscreen.text = tr("Fullscreen")
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(func(value: bool): Settings.fullscreen = value; Settings.apply())
	_modal_content.add_child(fullscreen)
	_modal_content.add_child(CastleTheme.button(tr("Save"), func(): Settings.save(); _close_modal(), true))

func _show_join() -> void:
	_open_modal(tr("Join game"))
	_modal_content.add_child(CastleTheme.paragraph(tr("Enter the host’s IP address to join a LAN game."), 22))
	var address := LineEdit.new()
	address.placeholder_text = tr("Host IP address")
	_modal_content.add_child(address)
	_modal_content.add_child(CastleTheme.button(tr("Join LAN"), func(): _join_address(address.text.strip_edges()), true))
	_modal_content.add_child(CastleTheme.button(tr("Host a Steam lobby"), _host.bind(false, true)))
	_modal_content.add_child(CastleTheme.button(tr("Find Steam lobbies"), _find_steam_rooms))
	_room_list = VBoxContainer.new()
	_modal_content.add_child(_room_list)
	_modal_content.add_child(CastleTheme.button(tr("Back"), _close_modal))

func _find_steam_rooms() -> void:
	if not NetworkManager.use_steam_backend():
		_show_error(tr("Steam is unavailable. Open Steam and sign in, or play solo / LAN."))
		return
	NetworkManager.refresh_lobby_list()

func _set_rooms(rooms: Array) -> void:
	if not is_instance_valid(_room_list):
		return
	for child in _room_list.get_children():
		_room_list.remove_child(child)
		child.queue_free()
	if rooms.is_empty():
		_room_list.add_child(CastleTheme.label(tr("No open Steam lobbies."), 22, CastleTheme.MUTED))
	for room: Dictionary in rooms:
		_room_list.add_child(CastleTheme.button("%s  ·  %d/10" % [room.name, room.num_members], _join_room.bind(int(room.id))))

func _host(solo: bool, steam: bool) -> void:
	if _busy:
		return
	if steam:
		if not NetworkManager.use_steam_backend():
			_show_error(tr("Steam is unavailable. Open Steam and sign in, or play solo / LAN."))
			return
	else:
		NetworkManager.use_local_backend()
	GameState.solo_session = solo
	_set_busy()
	GameState.create_and_join_lobby(_connection_result)

func _join_address(address: String) -> void:
	if address.is_empty() or _busy:
		return
	NetworkManager.use_local_backend(address)
	_join_room(1)

func _join_room(lobby_id: int) -> void:
	GameState.solo_session = false
	_set_busy()
	GameState.join_lobby(lobby_id, _connection_result)

func _set_busy() -> void:
	_busy = true
	_close_modal()
	_main.visible = false
	_loading = CenterContainer.new()
	CastleTheme.full_rect(_loading)
	_loading.add_child(CastleTheme.label(tr("Loading…"), 42, CastleTheme.GOLD, true))
	add_child(_loading)

func _connection_result(success: bool) -> void:
	if success:
		await get_tree().process_frame
		await get_tree().process_frame
		_world_requested = true
		ResourceLoader.load_threaded_request(GameState.world_scene)
		while ResourceLoader.load_threaded_get_status(GameState.world_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(GameState.world_scene) == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded_world := ResourceLoader.load_threaded_get(GameState.world_scene) as PackedScene
			GameState.enter_lobby(loaded_world)
		else:
			_loading.queue_free()
			NetworkManager.leave_lobby()
			_show_error(tr("The castle could not load. Restart the game and try again."))
	else:
		_loading.queue_free()
		_show_error(tr("Could not connect. Check the host address and try again."))

func _show_error(message: String) -> void:
	_busy = false
	_close_modal()
	_status.text = message
	_status.visible = true

func _handle_autostart() -> void:
	var arguments := OS.get_cmdline_args()
	var connect_index := arguments.find("+connect_lobby")
	if connect_index != -1 and connect_index + 1 < arguments.size():
		_join_room(int(arguments[connect_index + 1]))
	elif arguments.has("--solo"):
		_host(true, false)
	elif arguments.has("--host"):
		_host(false, arguments.has("--steam"))

func _exit_tree() -> void:
	if _world_requested and ResourceLoader.load_threaded_get_status(GameState.world_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		ResourceLoader.load_threaded_get(GameState.world_scene)
