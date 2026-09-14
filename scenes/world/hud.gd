class_name CastleHud
extends CanvasLayer

var world: Node3D
var _root: Control
var _play: Control
var _room: Label
var _clock: Label
var _objective: Label
var _progress: Label
var _status: Label
var _fuel: Label
var _skill: Label
var _stamina: ProgressBar
var _prompt: Label
var _prompt_panel: PanelContainer
var _clock_panel: PanelContainer
var _progress_panel: PanelContainer
var _lobby: PanelContainer
var _lobby_names: Label
var _lobby_start: Button
var _pause: PanelContainer
var _results: PanelContainer
var _result_title: Label
var _result_roster: GridContainer
var _rematch: Button
var _local_player: CharacterBody3D
var _refresh_elapsed := 0.0

func _init(node: Node3D) -> void:
	world = node
	layer = 8

func _ready() -> void:
	_root = Control.new()
	CastleTheme.full_rect(_root)
	_root.theme = CastleTheme.create()
	add_child(_root)
	_play = Control.new()
	CastleTheme.full_rect(_play)
	_root.add_child(_play)
	_build_play()
	_build_lobby()
	_build_pause()
	_build_results()
	GameState.state_changed.connect(_state_changed)
	_state_changed(GameState.game_state)

func _build_play() -> void:
	var location := _column(_play, Vector2(28, 24), Vector2(370, 86))
	location.add_theme_constant_override("separation", 6)
	_room = CastleTheme.label("", 30, CastleTheme.PAPER, true)
	location.add_child(_room)
	_status = CastleTheme.label("", 22, CastleTheme.PAPER, true)
	location.add_child(_status)
	_clock_panel = PanelContainer.new()
	_clock_panel.position = Vector2(610, 20)
	_clock_panel.custom_minimum_size = Vector2(220, 0)
	_clock_panel.add_theme_stylebox_override("panel", CastleTheme.parchment(18, 12))
	_play.add_child(_clock_panel)
	var clock_column := VBoxContainer.new()
	clock_column.add_theme_constant_override("separation", 0)
	_clock_panel.add_child(clock_column)
	_clock = CastleTheme.label("", 36)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_column.add_child(_clock)
	_objective = CastleTheme.label("", 20, CastleTheme.MUTED)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_column.add_child(_objective)
	_progress_panel = PanelContainer.new()
	_progress_panel.position = Vector2(1110, 20)
	_progress_panel.custom_minimum_size.x = 300
	_progress_panel.add_theme_stylebox_override("panel", CastleTheme.parchment(18, 15))
	_play.add_child(_progress_panel)
	_progress = CastleTheme.label("", 26)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_panel.add_child(_progress)
	var resource_panel := PanelContainer.new()
	resource_panel.position = Vector2(1070, 758)
	resource_panel.custom_minimum_size.x = 340
	resource_panel.add_theme_stylebox_override("panel", CastleTheme.parchment(18, 14))
	_play.add_child(resource_panel)
	var resources := VBoxContainer.new()
	resources.add_theme_constant_override("separation", 6)
	resource_panel.add_child(resources)
	_fuel = CastleTheme.label("", 26)
	resources.add_child(_fuel)
	_skill = CastleTheme.label("", 22, CastleTheme.MUTED)
	resources.add_child(_skill)
	var stamina_row := HBoxContainer.new()
	resources.add_child(stamina_row)
	stamina_row.add_child(CastleTheme.label(tr("Stamina"), 20, CastleTheme.MUTED))
	_stamina = ProgressBar.new()
	_stamina.show_percentage = false
	_stamina.custom_minimum_size = Vector2(180, 16)
	_stamina.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stamina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stamina.max_value = 50
	stamina_row.add_child(_stamina)
	var menu := CastleTheme.button(tr("Esc  Menu"), toggle_pause)
	menu.position = Vector2(28, 826)
	menu.custom_minimum_size = Vector2(160, 48)
	menu.add_theme_font_size_override("font_size", 22)
	_play.add_child(menu)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_left = -250
	_prompt_panel.offset_top = -112
	_prompt_panel.offset_right = 250
	_prompt_panel.offset_bottom = -54
	_prompt_panel.add_theme_stylebox_override("panel", CastleTheme.parchment(18, 12))
	_play.add_child(_prompt_panel)
	_prompt = CastleTheme.label("", 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt)

func _build_lobby() -> void:
	_lobby = _panel(Vector2(1030, 165), Vector2(380, 0))
	var column := VBoxContainer.new()
	_lobby.add_child(column)
	column.add_child(CastleTheme.label(tr("Lobby"), 38))
	_lobby_names = CastleTheme.label("", 24)
	column.add_child(_lobby_names)
	_lobby_start = CastleTheme.button(tr("Start game"), world._on_start_pressed, true)
	column.add_child(_lobby_start)
	column.add_child(CastleTheme.button(tr("Main menu"), world._on_quit_pressed))

func _build_pause() -> void:
	_pause = _panel(Vector2(470, 275), Vector2(500, 0))
	_pause.visible = false
	var column := VBoxContainer.new()
	_pause.add_child(column)
	column.add_child(CastleTheme.label(tr("Menu"), 42))
	column.add_child(CastleTheme.button(tr("Resume"), toggle_pause, true))
	column.add_child(CastleTheme.button(tr("Main menu"), world._on_quit_pressed))

func _build_results() -> void:
	_results = _panel(Vector2(420, 180), Vector2(600, 0))
	_results.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	_results.add_child(column)
	_result_title = CastleTheme.label("", 48)
	column.add_child(_result_title)
	_result_roster = GridContainer.new()
	_result_roster.columns = 2
	_result_roster.add_theme_constant_override("h_separation", 32)
	_result_roster.add_theme_constant_override("v_separation", 10)
	column.add_child(_result_roster)
	_rematch = CastleTheme.button(tr("New game"), GameState.restart_round, true)
	column.add_child(_rematch)
	column.add_child(CastleTheme.button(tr("Main menu"), world._on_quit_pressed))

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.1:
		return
	_refresh_elapsed = 0.0
	if not is_instance_valid(_local_player):
		for player in world.player_container.get_children():
			player.hud.visible = false
			if player.is_local_player():
				_local_player = player
	if not is_instance_valid(_local_player):
		return
	_refresh_play()
	if GameState.game_state == GameState.State.LOBBY:
		var names := PackedStringArray()
		for player in world.player_container.get_children():
			names.append(player.label.text)
		_lobby_names.text = "\n".join(names)
		_lobby_start.visible = NetworkManager.is_host()
		_lobby_start.disabled = not world.round_utils.initialized

func _refresh_play() -> void:
	var hunter: bool = _local_player.is_hunter
	_room.text = tr(CastleDressing.get_room_name(_local_player.global_position))
	var seconds := ceili(GameState.remaining_seconds)
	_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	_clock_panel.visible = GameState.game_state != GameState.State.LOBBY
	_progress_panel.visible = _clock_panel.visible
	_objective.text = tr("Hiding") if GameState.game_state == GameState.State.HIDING else tr("Hunt")
	_progress.text = tr("Shrines  %d / %d") % [GameState.shrines_completed, GameState.shrines_total]
	if GameState.portal_active:
		_progress.text = tr("Portal open")
	_status.text = tr("%d escaped · %d caught") % [GameState.escaped_peer_ids.size(), GameState.captured_peer_ids.size()]
	_status.visible = GameState.escaped_peer_ids.size() + GameState.captured_peer_ids.size() > 0
	var fuel: int = _local_player.inventory.items[CharacterInventory.InventoryItem.WOOD]
	_fuel.visible = not hunter
	_fuel.text = tr("Wood  %d") % fuel
	var cooldown: float = _local_player.ability_cooldown_timer.time_left
	if hunter:
		_skill.text = tr("Left mouse: Strike")
	elif cooldown > 0.0:
		_skill.text = tr("Air slide: %.1fs") % cooldown
	elif _local_player.stamina < CharacterMovement.AIR_SLIDE_STAMINA:
		_skill.text = tr("Air slide: Low stamina")
	else:
		_skill.text = tr("Jump, then F: Air slide")
	_stamina.value = _local_player.stamina
	_prompt.text = _interaction_prompt()
	if GameState.escaped_peer_ids.has(_local_player.peer_id):
		_prompt.text = tr("Escaped")
	elif _local_player.is_dead:
		_prompt.text = tr("Caught")
	elif _local_player.is_stunned:
		_prompt.text = tr("Stunned")
	_prompt_panel.visible = not _prompt.text.is_empty()

func _interaction_prompt() -> String:
	if is_instance_valid(_local_player.item):
		return tr("E / Left mouse: Throw")
	if not is_instance_valid(_local_player.closest_item):
		return ""
	var target: PhysicsBody3D = _local_player.closest_item
	var path: String = target.get_script().resource_path
	if "shrine" in path:
		return tr("E: Offer wood  %d / %d") % [target.current_amount, target.required_amount]
	if "pile" in path:
		return tr("E: Gather wood")
	if "echo_bell" in path:
		return tr("E: Echo Bell · Throw to distract")
	if "door" in path:
		return tr("E: Open / close door")
	return tr("E: Pick up")

func toggle_pause() -> void:
	if GameState.game_state == GameState.State.RESULTS:
		return
	_pause.visible = not _pause.visible
	GameState.set_local_paused(_pause.visible)
	_play.visible = not _pause.visible
	_lobby.visible = not _pause.visible and GameState.game_state == GameState.State.LOBBY

func _state_changed(state: GameState.State) -> void:
	_lobby.visible = state == GameState.State.LOBBY
	_results.visible = state == GameState.State.RESULTS
	if state == GameState.State.RESULTS:
		_pause.visible = false
		_play.visible = false
		GameState.set_local_paused(false)
		_result_title.text = tr("Skeletons win") if GameState.winner == 1 else tr("Knight wins")
		for child in _result_roster.get_children():
			_result_roster.remove_child(child)
			child.queue_free()
		for player in world.player_container.get_children():
			var outcome := tr("Inside")
			if player.is_hunter:
				outcome = tr("Knight")
			elif GameState.escaped_peer_ids.has(player.peer_id):
				outcome = tr("Escaped")
			elif GameState.captured_peer_ids.has(player.peer_id):
				outcome = tr("Caught")
			var player_name := CastleTheme.label(player.label.text, 25)
			player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_result_roster.add_child(player_name)
			var result := CastleTheme.label(outcome, 25, CastleTheme.MUTED)
			result.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_result_roster.add_child(result)
		_rematch.visible = NetworkManager.is_host()

func _panel(origin: Vector2, extent: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = origin
	panel.size = extent
	_root.add_child(panel)
	return panel

func _column(parent: Control, origin: Vector2, extent: Vector2) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.position = origin
	column.size = extent
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	return column
