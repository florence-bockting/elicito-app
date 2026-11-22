class_name FakeClient
extends ElicitoClient
## An ElicitoClient that is "connected" to an up-to-date server but sends
## nothing: requests are kept in `sent`, and a test answers them by
## emitting the client's signals itself.

var sent: Array[Dictionary] = []


func _init() -> void:
	auto_connect = false
	reconnect = false
	connected = true
	backend = "mock"
	server_version = REQUIRED_SERVER_VERSION


func _process(_delta: float) -> void:
	pass  # no socket


func _send(msg: Dictionary) -> void:
	sent.append(msg)


## Answers the pending request as the server would.
func answer(result: Dictionary) -> void:
	_pending_id = ""
	fit_finished.emit(result)


## Fails the pending request as the server would.
func fail(message: String) -> void:
	_pending_id = ""
	fit_failed.emit(message)
