class_name ConnectionManagerNode
extends Node
## Autoload: WebSocket host/client lifecycle.

signal hosted(port: int)
signal connected_to_host()
signal connection_failed(reason: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal server_disconnected()

var peer: WebSocketMultiplayerPeer
var _wired := false
var _expecting_leave := false
var _connecting := false
var _saw_connecting := false
var _join_timer: SceneTreeTimer


func _process(_delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	if not _connecting:
		return
	# WebSocket on HTML5 often reaches DISCONNECTED without multiplayer.connection_failed.
	var status := peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_CONNECTING:
		_saw_connecting = true
	elif (
		_saw_connecting
		and status == MultiplayerPeer.CONNECTION_DISCONNECTED
	):
		_fail_connection("connection failed")


func host(port: int = NetConst.GAME_PORT) -> Error:
	leave()
	peer = WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		peer = null
		connection_failed.emit("host failed: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	_wire_multiplayer_signals()
	hosted.emit(port)
	return OK


func join(address: String, port: int = NetConst.GAME_PORT) -> Error:
	leave()
	peer = WebSocketMultiplayerPeer.new()
	var url := "ws://%s:%d" % [address.strip_edges(), port]
	var err := peer.create_client(url)
	if err != OK:
		peer = null
		connection_failed.emit("join failed: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	_wire_multiplayer_signals()
	_connecting = true
	_saw_connecting = false
	_arm_join_timeout()
	return OK


func leave() -> void:
	_expecting_leave = true
	_connecting = false
	_saw_connecting = false
	_cancel_join_timeout()
	_unwire_multiplayer_signals()
	if peer != null:
		peer.close()
		peer = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_expecting_leave = false


func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func is_connected_peer() -> bool:
	return multiplayer.has_multiplayer_peer() and peer != null


func get_unique_id() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 0
	return multiplayer.get_unique_id()


func _arm_join_timeout() -> void:
	_cancel_join_timeout()
	_join_timer = get_tree().create_timer(NetConst.JOIN_TIMEOUT_SEC)
	_join_timer.timeout.connect(_on_join_timeout, CONNECT_ONE_SHOT)


func _cancel_join_timeout() -> void:
	if _join_timer != null and _join_timer.timeout.is_connected(_on_join_timeout):
		_join_timer.timeout.disconnect(_on_join_timeout)
	_join_timer = null


func _on_join_timeout() -> void:
	_join_timer = null
	if not _connecting:
		return
	_fail_connection("connection timed out")


func _fail_connection(reason: String) -> void:
	if not _connecting:
		return
	# Tear down first so listeners can safely start a new join without this
	# leave() closing the replacement peer (re-entrancy on HTML5).
	leave()
	connection_failed.emit(reason)


func _wire_multiplayer_signals() -> void:
	if _wired:
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_wired = true


func _unwire_multiplayer_signals() -> void:
	if not _wired:
		return
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	_wired = false


func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if _expecting_leave:
		return
	peer_disconnected.emit(id)


func _on_connected_to_server() -> void:
	_connecting = false
	_cancel_join_timeout()
	connected_to_host.emit()


func _on_connection_failed() -> void:
	_fail_connection("connection failed")


func _on_server_disconnected() -> void:
	if _expecting_leave:
		return
	server_disconnected.emit()
