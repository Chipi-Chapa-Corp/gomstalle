extends Node

const MUSIC := preload("res://assets/sounds/castle/castle_music.ogg")
const AMBIENCE := preload("res://assets/sounds/castle/castle_air.ogg")
const SOUNDS: Dictionary[StringName, AudioStream] = {
	&"swing": preload("res://assets/sounds/castle/swing.wav"),
	&"jump": preload("res://assets/sounds/castle/jump.wav"),
	&"roll": preload("res://assets/sounds/castle/roll.wav"),
	&"throw": preload("res://assets/sounds/castle/throw.wav"),
	&"capture": preload("res://assets/sounds/castle/capture.wav"),
	&"click": preload("res://assets/sounds/castle/click.wav"),
	&"confirm": preload("res://assets/sounds/castle/confirm.wav"),
	&"fuel": preload("res://assets/sounds/castle/fuel.wav"),
	&"door": preload("res://assets/sounds/castle/door.wav"),
	&"shrine": preload("res://assets/sounds/castle/shrine.wav"),
	&"portal": preload("res://assets/sounds/castle/portal.wav"),
	&"round_start": preload("res://assets/sounds/castle/round_start.wav"),
	&"round_end": preload("res://assets/sounds/castle/round_end.wav"),
}
const WOOD_STEPS: Array[AudioStream] = [
	preload("res://assets/sounds/castle/step_wood_0.wav"),
	preload("res://assets/sounds/castle/step_wood_1.wav"),
	preload("res://assets/sounds/castle/step_wood_2.wav"),
]
const ARMOR_STEPS: Array[AudioStream] = [
	preload("res://assets/sounds/castle/step_armor_0.wav"),
	preload("res://assets/sounds/castle/step_armor_1.wav"),
	preload("res://assets/sounds/castle/step_armor_2.wav"),
]
const ACTION_SOUNDS: Dictionary[StringName, StringName] = {
	&"Attack": &"swing", &"Jump": &"jump", &"Roll": &"roll", &"Throw": &"throw",
}

var music := AudioStreamPlayer.new()
var ambience := AudioStreamPlayer.new()
var spatial_voices: Array[AudioStreamPlayer3D] = []
var interface_voices: Array[AudioStreamPlayer] = []
var _step_index := 0
var _shutting_down := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	music.stream = MUSIC
	ambience.stream = AMBIENCE
	music.volume_db = -40.0
	ambience.volume_db = -40.0
	add_child(music)
	add_child(ambience)
	music.play()
	ambience.play()
	for index in 16:
		var voice := AudioStreamPlayer3D.new()
		_configure_spatial(voice)
		add_child(voice)
		spatial_voices.append(voice)
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -12.0
		add_child(voice)
		interface_voices.append(voice)
	get_tree().node_added.connect(_on_node_added)
	GameState.state_changed.connect(_on_state_changed)

func _physics_process(delta: float) -> void:
	var in_castle := GameState.game_state != GameState.State.IDLE
	music.volume_db = move_toward(music.volume_db, -16.0 if in_castle else -11.0, delta * 4.0)
	ambience.volume_db = move_toward(ambience.volume_db, -16.0 if in_castle else -24.0, delta * 4.0)

func _configure_spatial(voice: AudioStreamPlayer3D) -> void:
	voice.unit_size = 4.0
	voice.max_distance = 22.0
	voice.volume_db = -8.0
	voice.max_db = 0.0

func play_at(cue: StringName, location: Vector3) -> void:
	if _shutting_down:
		return
	for voice in spatial_voices:
		if not voice.playing:
			voice.global_position = location
			voice.stream = SOUNDS[cue]
			voice.play()
			return

func play_ui(cue: StringName) -> void:
	if _shutting_down:
		return
	for voice in interface_voices:
		if not voice.playing:
			voice.stream = SOUNDS[cue]
			voice.play()
			return

func play_step(voice: AudioStreamPlayer3D, armored: bool) -> void:
	if _shutting_down:
		return
	_configure_spatial(voice)
	var steps := ARMOR_STEPS if armored else WOOD_STEPS
	voice.stream = steps[_step_index % steps.size()]
	voice.pitch_scale = 0.96 + float(_step_index % 5) * 0.02
	_step_index += 1
	voice.play()

func play_action(voice: AudioStreamPlayer3D, action: StringName) -> void:
	if _shutting_down:
		return
	if not ACTION_SOUNDS.has(action):
		return
	_configure_spatial(voice)
	voice.stream = SOUNDS[ACTION_SOUNDS[action]]
	voice.play()

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.mouse_entered.connect(func():
			if not button.disabled:
				play_ui(&"click"))
		button.pressed.connect(play_ui.bind(&"confirm"))

func _on_state_changed(state: GameState.State) -> void:
	if state == GameState.State.HIDING or state == GameState.State.STARTED:
		play_ui(&"round_start")
	elif state == GameState.State.RESULTS:
		play_ui(&"round_end")

func shutdown() -> void:
	_shutting_down = true
	set_physics_process(false)
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()
	var mix_period := AudioServer.get_time_since_last_mix() + AudioServer.get_time_to_next_mix()
	OS.delay_usec(ceili(mix_period * 2000000.0))
	await get_tree().process_frame
	await get_tree().process_frame

func quit_game() -> void:
	if _shutting_down:
		return
	await shutdown()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
