class_name ConnectionManagerNode
extends Node
## Autoload: WebSocket host/client lifecycle.

signal hosted(port: int)
signal connected_to_host()
signal connection_failed(reason: String)

signal peer_disconnected(peer_id: int)
signal server_disconnected()

var peer: WebSocketMultiplayerPeer
var _expecting_leave := false
var _connecting := false
var _saw_connecting := false
var _join_timer: SceneTreeTimer


func _process(_delta: float) -> void:
	if peer == null: return
	peer.poll()
	if not _connecting: return
	# WebSocket on HTML5 often reaches DISCONNECTED without multiplayer.connection_failed.
	var status := peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_CONNECTING:
		_saw_connecting = true
	elif (
		_saw_connecting
		and status == MultiplayerPeer.CONNECTION_DISCONNECTED
	):
		_fail_connection()


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
	var ws_host := address.strip_edges()
	var ws_scheme := "ws" if ws_host.to_lower() in ["127.0.0.1", "localhost", "::1"] else "wss"
	var url := "%s://%s:%d" % [ws_scheme, ws_host, port]
	var err := peer.create_client(url)
	if err != OK:
		peer = null
		connection_failed.emit("join failed: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	_wire_multiplayer_signals()
	_connecting = true
	_saw_connecting = false
	_cancel_join_timeout()
	_join_timer = get_tree().create_timer(NetConst.JOIN_TIMEOUT_SEC)
	_join_timer.timeout.connect(_on_join_timeout, CONNECT_ONE_SHOT)
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


func _cancel_join_timeout() -> void:
	if _join_timer != null and _join_timer.timeout.is_connected(_on_join_timeout):
		_join_timer.timeout.disconnect(_on_join_timeout)
	_join_timer = null


func _on_join_timeout() -> void:
	_join_timer = null
	if not _connecting:
		return
	_fail_connection("connection timed out")


func _fail_connection(reason: String = "connection failed") -> void:
	if not _connecting:
		return
	# Tear down first so listeners can safely start a new join without this
	# leave() closing the replacement peer (re-entrancy on HTML5).
	leave()
	connection_failed.emit(reason)


func _wire_multiplayer_signals() -> void:
	EventUtils.safe_connect(multiplayer.peer_disconnected, _on_peer_disconnected)
	EventUtils.safe_connect(multiplayer.connected_to_server, _on_connected_to_server)
	EventUtils.safe_connect(multiplayer.connection_failed, _fail_connection)
	EventUtils.safe_connect(multiplayer.server_disconnected, _on_server_disconnected)


func _unwire_multiplayer_signals() -> void:
	EventUtils.safe_disconnect(multiplayer.peer_disconnected, _on_peer_disconnected)
	EventUtils.safe_disconnect(multiplayer.connected_to_server, _on_connected_to_server)
	EventUtils.safe_disconnect(multiplayer.connection_failed, _fail_connection)
	EventUtils.safe_disconnect(multiplayer.server_disconnected, _on_server_disconnected)


func _on_peer_disconnected(id: int) -> void:
	if not _expecting_leave:
		peer_disconnected.emit(id)


func _on_server_disconnected() -> void:
	if not _expecting_leave:
		server_disconnected.emit()


func _on_connected_to_server() -> void:
	_connecting = false
	_cancel_join_timeout()
	connected_to_host.emit()

