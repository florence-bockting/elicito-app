class_name ElicitoClient
extends Node
## WebSocket client for the Python elicito server (server/, elicito-app-server).
##
## Polls the socket every frame, reconnects on its own, and turns the
## server's JSON messages into signals. One fit runs at a time.

signal connection_changed(connected: bool, backend: String)
## stage is "Warm-up" (no loss) or "Training"; phase counts the runs of one fit.
signal progress(stage: String, done: int, total: int, loss: Variant, phase: int, phases: int)
signal heartbeat(elapsed: float)
signal fit_finished(result: Dictionary)
signal fit_failed(message: String)

## The server protocol this client needs (see PROTOCOL_VERSION in server/src/elicito_app_server/app.py).
const REQUIRED_SERVER_VERSION := 4

@export var url := "ws://127.0.0.1:8765/ws"
## Connect as soon as the node is ready (Main connects itself, after
## reading the server address from the start options).
@export var auto_connect := true
## Try again every reconnect_delay seconds while the server is unreachable.
@export var reconnect := true
@export var reconnect_delay := 2.0

var backend := ""
var connected := false
## False when training settings are ignored (PrecomputedClient).
var supports_settings := true
var server_version := 0  # from the server's hello; older servers send none

var _ws := WebSocketPeer.new()
var _last_state := WebSocketPeer.STATE_CLOSED
var _retry_in := 0.0
var _pending_id := ""


func _ready() -> void:
	if auto_connect:
		connect_to_server()


func connect_to_server() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20  # results with replay draws can be large
	var err := _ws.connect_to_url(url)
	if err != OK:
		push_warning("ElicitoClient: cannot connect to %s (%s)" % [url, error_string(err)])
		_retry_in = reconnect_delay
	_last_state = WebSocketPeer.STATE_CONNECTING


## True when a server from an older version of the project is still running.
func is_outdated() -> bool:
	return connected and server_version < REQUIRED_SERVER_VERSION


func _refuse_if_outdated() -> bool:
	if is_outdated():
		fit_failed.emit("The elicito server is an old version. Stop it (Ctrl+C) and start it again: elicito-app-server")
	return is_outdated()


func is_busy() -> bool:
	return _pending_id != ""


## Ask the server to fit a prior. `expert` maps target names to quantile
## lists, e.g. {"pumps": [2, 3, 4, 6, 8], "omega": [...]}. Returns the id.
func request_fit(case_id: String, expert: Dictionary, replay_n := 24, settings := {}) -> String:
	if not connected:
		fit_failed.emit("Not connected to the elicito server at %s" % url)
		return ""
	if is_busy():
		fit_failed.emit("A fit is already running")
		return ""
	if _refuse_if_outdated():
		return ""
	_pending_id = "fit-%d" % Time.get_ticks_msec()
	_send({"type": "fit", "request_id": _pending_id, "case_study": case_id, "expert": expert, "replay_n": replay_n, "settings": settings})
	return _pending_id


## Fit a panel of experts with partial pooling. `experts` maps each
## expert's name to their answers (like `expert` in request_fit).
func request_fit_panel(case_id: String, experts: Dictionary, replay_n := 24, settings := {}) -> String:
	if not connected:
		fit_failed.emit("Not connected to the elicito server at %s" % url)
		return ""
	if is_busy():
		fit_failed.emit("A fit is already running")
		return ""
	if _refuse_if_outdated():
		return ""
	_pending_id = "panel-%d" % Time.get_ticks_msec()
	_send({"type": "fit_panel", "request_id": _pending_id, "case_study": case_id, "experts": experts, "replay_n": replay_n, "settings": settings})
	return _pending_id


func _send(msg: Dictionary) -> void:
	_ws.send_text(JSON.stringify(msg))


func _process(delta: float) -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state != _last_state:
		_last_state = state
		if state == WebSocketPeer.STATE_CLOSED:
			if connected:
				connected = false
				connection_changed.emit(false, "")
			if _pending_id != "":
				_pending_id = ""
				fit_failed.emit("Connection to the server was lost")
			_retry_in = reconnect_delay
	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			_handle(_ws.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED and reconnect:
		_retry_in -= delta
		if _retry_in <= 0.0:
			connect_to_server()


func _handle(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		push_warning("ElicitoClient: ignoring non-JSON message")
		return
	var rid: String = str(msg.get("request_id", ""))
	match str(msg.get("type", "")):
		"hello":
			backend = str(msg.get("backend", "?"))
			server_version = int(msg.get("version", 1))
			connected = true
			connection_changed.emit(true, backend)
		"progress":
			if rid == _pending_id:
				progress.emit(str(msg.stage), int(msg.done), int(msg.total), msg.get("loss"), int(msg.get("phase", 1)), int(msg.get("phases", 1)))
		"heartbeat":
			if rid == _pending_id:
				heartbeat.emit(float(msg.elapsed))
		"result":
			if rid == _pending_id:
				_pending_id = ""
				fit_finished.emit(msg)
		"error":
			if rid == _pending_id or rid == "":
				_pending_id = ""
				fit_failed.emit(str(msg.get("message", "unknown error")))
		"pong":
			pass
		_:
			push_warning("ElicitoClient: unknown message %s" % msg.get("type"))
