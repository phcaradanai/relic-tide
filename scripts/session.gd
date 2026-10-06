class_name ExpeditionSession
extends Node
## WebSocket client or central server transport. Full rules exist only on the server.
signal view_changed(snapshot: Dictionary)
signal lobby_changed(info: Dictionary)
signal rooms_changed(rooms: Array)
signal connection_error(message: String)
signal directory_ready
const Directory = preload("res://scripts/room_directory.gd")
const DEFAULT_PORT := 24567
var server_url := ""
var mode := "idle"
var room_code := ""
var is_host := false
var directory = null
var _peer: WebSocketMultiplayerPeer
var _connecting_time := 0.0
var _pending: Dictionary = {}
var _simulation_time := 0.0
func _ready() -> void:
	if server_url.is_empty():
		if OS.has_feature("web"):
			# Use the site's room service, never the visitor's localhost.
			server_url = str(JavaScriptBridge.eval("window.relicTideServerURL || ((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/rooms')"))
		else:
			server_url = OS.get_environment("RELIC_TIDE_SERVER_URL")
			if server_url.is_empty(): server_url = ProjectSettings.get_setting("network/room_server_url", "ws://127.0.0.1:24567")
	multiplayer.peer_connected.connect(_connected_peer)
	multiplayer.peer_disconnected.connect(_disconnected_peer)
	multiplayer.connected_to_server.connect(_joined)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_server_left)
func _exit_tree() -> void:
	multiplayer.peer_connected.disconnect(_connected_peer)
	multiplayer.peer_disconnected.disconnect(_disconnected_peer)
	multiplayer.connected_to_server.disconnect(_joined)
	multiplayer.connection_failed.disconnect(_failed)
	multiplayer.server_disconnected.disconnect(_server_left)
	close()
func _process(delta: float) -> void:
	if mode == "server":
		_simulation_time += minf(delta, 0.25)
		while _simulation_time >= Directory.Rules.STEP:
			_simulation_time -= Directory.Rules.STEP
			directory.step()
	if mode == "connecting":
		_connecting_time += delta
		if _connecting_time > 10:
			close()
			connection_error.emit("Room service unavailable. Retry or contact the server operator.")
func serve(port: int = DEFAULT_PORT, bind_address: String = "127.0.0.1") -> Error:
	close()
	if port < 1024 or port > 65535 or bind_address.is_empty(): return ERR_INVALID_PARAMETER
	_peer = WebSocketMultiplayerPeer.new()
	var error := _peer.create_server(port, bind_address)
	if error != OK:
		_peer = null
		return error
	directory = Directory.new()
	directory.packet.connect(_send_packet)
	mode = "server"
	# Clients communicate only with authority, never with unrelated room peers.
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = _peer
	return OK
func connect_directory() -> Error:
	if mode in ["client", "connecting"]: return OK
	if not server_url.begins_with("ws://") and not server_url.begins_with("wss://"): return ERR_INVALID_PARAMETER
	_peer = WebSocketMultiplayerPeer.new()
	var error := _peer.create_client(server_url)
	if error != OK:
		_peer = null
		return error
	mode = "connecting"
	_connecting_time = 0
	multiplayer.multiplayer_peer = _peer
	return OK
func _request(kind: String, data: Dictionary = {}) -> Error:
	if mode == "client":
		_room_request.rpc_id(1, kind, data)
		return OK
	if mode == "connecting" and not _pending.is_empty() and _pending.kind != "list": return ERR_BUSY
	_pending = {"kind": kind, "data": data}
	var error := connect_directory()
	if error != OK: _pending.clear()
	return error
func create_room(capacity: int = 4) -> Error:
	return _request("create", {"capacity": capacity})
func join_room(code: String) -> Error:
	return _request("join", {"code": code.strip_edges().to_upper()})
func refresh_rooms() -> Error:
	return _request("list")
func start_match() -> void:
	_request("start")
func movement(command: Dictionary) -> void:
	if mode == "client": _request("input", command)
func interaction(command: Dictionary) -> void:
	if mode == "client": _request("event", command)
func close() -> void:
	mode = "idle"
	room_code = ""
	is_host = false
	directory = null
	_simulation_time = 0
	_pending.clear()
	if _peer:
		_peer.close()
		_peer = null
	if is_inside_tree(): multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
func _joined() -> void:
	mode = "client"
	directory_ready.emit()
	if not _pending.is_empty():
		var command := _pending.duplicate(true)
		_pending.clear()
		_request(command.kind, command.data)
func _failed() -> void:
	close()
	connection_error.emit("Room service unavailable. Retry or contact the server operator.")
func _server_left() -> void:
	close()
	connection_error.emit("Room service disconnected. Reconnect from the room list.")
func _connected_peer(id: int) -> void:
	if mode == "server":
		if multiplayer.get_peers().size() > 256:
			_peer.disconnect_peer(id)
		else: directory.connected(id)
func _disconnected_peer(id: int) -> void:
	if mode == "server": directory.disconnected(id)
@rpc("any_peer", "call_remote", "reliable")
func _room_request(kind: String, data: Dictionary) -> void:
	if mode == "server": directory.request(multiplayer.get_remote_sender_id(), kind, data)
func _send_packet(peer: int, kind: String, data: Dictionary) -> void:
	if peer in multiplayer.get_peers() and _peer.get_peer(peer).get_ready_state() == WebSocketPeer.STATE_OPEN:
		_receive_packet.rpc_id(peer, kind, data)
@rpc("authority", "call_remote", "reliable")
func _receive_packet(kind: String, data: Dictionary) -> void:
	match kind:
		"rooms": rooms_changed.emit(data.rooms)
		"lobby":
			room_code = data.code
			is_host = data.is_host
			lobby_changed.emit(data)
		"view": view_changed.emit(data)
		"closed":
			room_code = ""
			is_host = false
			connection_error.emit(data.message)
		"error": connection_error.emit(data.message)
