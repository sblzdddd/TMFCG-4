class_name LanDiscovery
extends Node
## UDP LAN advertise (host) + listen (clients) for public rooms.

signal rooms_updated(rooms: Array[Dictionary])

var _udp := PacketPeerUDP.new()
var _advertising := false
var _listening := false
var _payload: Dictionary = {}
var _broadcast_acc := 0.0
var _discovered: Dictionary[String, Dictionary] = {}


func _process(delta: float) -> void:
	if _advertising:
		_broadcast_acc += delta
		if _broadcast_acc >= NetConst.BROADCAST_INTERVAL:
			_broadcast_acc = 0.0
			_send_advertise()
	if _listening:
		_poll_packets()
		_expire_stale()


func is_advertising() -> bool:
	return _advertising


func start_advertising(snapshot: Dictionary) -> void:
	_payload = snapshot.duplicate(true)
	_advertising = true
	_broadcast_acc = NetConst.BROADCAST_INTERVAL
	_udp.close()
	_udp.bind(0)
	_udp.set_broadcast_enabled(true)


func update_payload(snapshot: Dictionary) -> void:
	_payload = snapshot.duplicate(true)


func stop_advertising() -> void:
	_advertising = false
	_payload.clear()
	if not _listening:
		_udp.close()


func start_listening() -> Error:
	if _listening:
		return OK
	_udp.close()
	var err := _udp.bind(NetConst.DISCOVERY_PORT)
	if err != OK:
		return err
	_listening = true
	_discovered.clear()
	return OK


func stop_listening() -> void:
	_listening = false
	_discovered.clear()
	if not _advertising:
		_udp.close()
	var empty: Array[Dictionary] = []
	rooms_updated.emit(empty)


func get_rooms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for code in _discovered:
		result.append(_discovered[code].duplicate(true))
	return result


func _send_advertise() -> void:
	if _payload.is_empty():
		return
	var packet := JSON.stringify(_payload).to_utf8_buffer()
	_udp.set_dest_address("255.255.255.255", NetConst.DISCOVERY_PORT)
	_udp.put_packet(packet)


func _poll_packets() -> void:
	var changed := false
	while _udp.get_available_packet_count() > 0:
		var bytes := _udp.get_packet()
		var sender := _udp.get_packet_ip()
		var text := bytes.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = parsed
		var code := str(data.get("code", ""))
		if code.is_empty():
			continue
		data["address"] = sender
		data["last_seen"] = Time.get_ticks_msec() / 1000.0
		_discovered[code] = data
		changed = true
	if changed:
		rooms_updated.emit(get_rooms())


func _expire_stale() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var removed := false
	var codes: Array[String] = []
	for key: Variant in _discovered.keys():
		codes.append(str(key))
	for code: String in codes:
		var entry: Dictionary = _discovered[code]
		if now - float(entry.get("last_seen", 0.0)) > NetConst.DISCOVERY_TTL_SEC:
			_discovered.erase(code)
			removed = true
	if removed:
		rooms_updated.emit(get_rooms())


func build_advertise_payload(room: RoomData, port: int = NetConst.GAME_PORT) -> Dictionary:
	return {
		"v": 1,
		"code": room.code,
		"name": room.name,
		"players": room.member_count(),
		"max": room.max_players,
		"port": port,
		"host_uid": room.host_uid,
	}
