extends Node
class_name RegistryClient

signal rooms_updated(rooms: Array)
signal created(room_id: String, token: String)
signal connected()
signal join_reply(ok: bool, net_id: int, host: Dictionary)

var rooms: Array = [] # always current snapshot
var _ws: WebSocketPeer
var _state := WebSocketPeer.STATE_CLOSED
var _room_id := ""
var _token := ""
var _hb_timer := Timer.new()

func _ready() -> void:
	_hb_timer.wait_time = 3.0
	_hb_timer.timeout.connect(_heartbeat)
	add_child(_hb_timer)

func connect_ws(url: String, timeout_sec := 5.0) -> bool:
	print("Connecting to registry at %s" % url)
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK: return false
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_ws.poll()
		var st = _ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN: _state = st; print("Connected to registry"); return true
		if st == WebSocketPeer.STATE_CLOSED: print("Connection to registry closed"); return false
		await get_tree().process_frame
	_ws.close(1000, "timeout"); _state = WebSocketPeer.STATE_CLOSED; print("Connection to registry timed out")
	return false

func ensure_connected(url: String, timeout_sec := 5.0) -> bool:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return true
	return await connect_ws(url, timeout_sec)

func _process(_dt: float) -> void:
	if _ws == null: return
	_ws.poll()
	var st = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		_hb_timer.stop()
		return
	if st != WebSocketPeer.STATE_OPEN: return
	while _ws.get_available_packet_count() > 0:
		var m = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if typeof(m) != TYPE_DICTIONARY: continue
		match m.type:
			"HELLO":
				print("HELLO")
				connected.emit() # initial handshake
			"ROOMS":
				print("ROOMS", m.rooms)
				rooms = m.rooms
				rooms_updated.emit(rooms)
			"CREATED":
				print("CREATED", m.room_id, m.token)
				_room_id = m.room_id; _token = m.token
				_hb_timer.start()
				created.emit(_room_id, _token) # <-- signal fired here
			"JOIN_REPLY":
				print("JOIN_REPLY", m.ok, m.net_id, m.host)
				join_reply.emit(m.ok, m.net_id, m.host if m.has("host") else {})

# Public API -------------------------------------------------
func create_room(host_ip: String, host_port: int, mode := "duo", ver := "dev", cap := 8) -> void:
	_send({"type": "CREATE", "host": {"ip": host_ip, "port": host_port}, "mode": mode, "ver": ver, "cap": cap})

func join_room(room_id: String) -> void:
	_send({"type": "JOIN", "room_id": room_id})

func close_room() -> void:
	if _room_id == "" or _token == "": return
	_send({"type": "CLOSE", "room_id": _room_id, "token": _token})
	_hb_timer.stop()

# Internal ---------------------------------------------------
func _heartbeat() -> void:
	if _room_id != "" and _token != "":
		_send({"type": "HEARTBEAT", "room_id": _room_id, "token": _token})

func _send(msg: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))
