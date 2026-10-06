class_name RoomDirectory
extends RefCounted
## Central room authority. Packet signals are addressed to one peer only.
signal packet(peer: int, kind: String, data: Dictionary)
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const MAX_ROOMS := 64
var rooms: Dictionary = {}
var members: Dictionary = {}
var _requests: Dictionary = {}
var _movement_requests: Dictionary = {}
var _idle: Dictionary = {}
func connected(peer: int) -> void:
	_idle[peer] = true
	list_rooms(peer)
func request(peer: int, kind: String, data: Dictionary) -> void:
	# Movement has a separate budget so a held key cannot starve lobby controls.
	var now := Time.get_ticks_msec()
	var requests: Dictionary = _movement_requests if kind == "input" else _requests
	var bucket: Dictionary = requests.get(peer, {"time": now, "count": 0})
	if now - bucket.time > 1000: bucket = {"time": now, "count": 0}
	bucket.count += 1
	requests[peer] = bucket
	if bucket.count > (40 if kind == "input" else 30): return
	match kind:
		"list": list_rooms(peer)
		"create":
			if typeof(data.get("capacity")) == TYPE_INT: create_room(peer, data.capacity)
			else: error(peer, "Invalid room capacity.")
		"join":
			if typeof(data.get("code")) == TYPE_STRING: join_room(peer, data.code)
			else: error(peer, "Invalid room code.")
		"start": start_room(peer)
		"input": accept_input(peer, data)
		"event": accept_event(peer, data)
		"leave": leave(peer)
func error(peer: int, message: String) -> void:
	packet.emit(peer, "error", {"message": message})
func list_rooms(peer: int) -> void:
	var result: Array = []
	for code in rooms:
		var room: Dictionary = rooms[code]
		if room.phase == "lobby":
			result.append({"code": code, "count": room.peers.size(), "limit": room.limit, "joinable": room.peers.size() < room.limit})
	packet.emit(peer, "rooms", {"rooms": result})
func changed() -> void:
	for peer in _idle: list_rooms(peer)
func new_code() -> String:
	var crypto := Crypto.new()
	while true:
		var code := ""
		for byte in crypto.generate_random_bytes(6): code += ALPHABET[byte % ALPHABET.length()]
		if not rooms.has(code): return code
	return ""
func create_room(peer: int, capacity: int) -> bool:
	if members.has(peer):
		error(peer, "Leave your current room first.")
		return false
	if capacity < 2 or capacity > 4 or rooms.size() >= MAX_ROOMS:
		error(peer, "Cannot create room. Choose 2–4 players or try again later.")
		return false
	var code := new_code()
	rooms[code] = {"code": code, "host": peer, "peers": [peer], "limit": capacity, "phase": "lobby", "game": null, "match_id": ""}
	members[peer] = code
	_idle.erase(peer)
	lobby(rooms[code])
	changed()
	return true
func join_room(peer: int, raw_code: String) -> bool:
	var code := raw_code.strip_edges().to_upper()
	if members.has(peer):
		error(peer, "Leave your current room first.")
		return false
	if code.length() != 6 or not rooms.has(code):
		error(peer, "Room not found. Check the six-character code or refresh the list.")
		return false
	var room: Dictionary = rooms[code]
	if room.phase != "lobby" or room.peers.size() >= room.limit:
		error(peer, "Room is full or the expedition has started.")
		return false
	room.peers.append(peer)
	members[peer] = code
	_idle.erase(peer)
	lobby(room)
	changed()
	return true
func lobby(room: Dictionary) -> void:
	for i in range(room.peers.size()):
		packet.emit(room.peers[i], "lobby", {"code": room.code, "count": room.peers.size(), "limit": room.limit, "player": i, "is_host": room.peers[i] == room.host})
func start_room(peer: int) -> bool:
	if not members.has(peer): return false
	var room: Dictionary = rooms[members[peer]]
	if room.host != peer or room.phase != "lobby" or room.peers.size() < 2: return false
	room.game = Rules.new(1, room.peers.size())
	room.phase = "running"
	room.match_id = Crypto.new().generate_random_bytes(16).hex_encode()
	views(room)
	changed()
	return true
func accept_input(peer: int, command: Dictionary) -> bool:
	if not members.has(peer): return false
	var room: Dictionary = rooms[members[peer]]
	var who: int = room.peers.find(peer)
	if room.phase != "running" or room.game == null or who < 0: return false
	if command.size() != 3 or typeof(command.get("direction")) != TYPE_VECTOR2 or typeof(command.get("sequence")) != TYPE_INT or typeof(command.get("match_id")) != TYPE_STRING: return false
	if command.match_id != room.match_id: return false
	return room.game.set_input(who, command.direction, command.sequence)
func step() -> void:
	for room: Dictionary in rooms.values():
		if room.phase != "running": continue
		room.game.step()
		if room.game.finished:
			room.phase = "finished"
			views(room)
		elif room.game.tick % 2 == 0: views(room)
func accept_event(peer: int, command: Dictionary) -> bool:
	if not members.has(peer): return false
	var room: Dictionary = rooms[members[peer]]
	if room.phase != "running" or room.game == null: return false
	if command.size() != 4 or typeof(command.get("kind")) != TYPE_STRING or typeof(command.get("target")) != TYPE_STRING or typeof(command.get("sequence")) != TYPE_INT or typeof(command.get("match_id")) != TYPE_STRING: return false
	if command.match_id != room.match_id: return false
	var who: int = room.peers.find(peer)
	var accepted := false
	match command.kind:
		"take_light", "drop_light": accepted = command.target.is_empty() and room.game.use_light(who, command.kind, command.sequence)
		"toggle_door": accepted = room.game.toggle_door(who, command.target, command.sequence)
		"begin_valve": accepted = command.target.is_empty() and room.game.begin_valve(who, command.sequence)
		"begin_vault": accepted = room.game.begin_vault(who, command.target, command.sequence)
		"take_relic", "drop_relic": accepted = command.target.is_empty() and room.game.use_relic(who, command.kind, command.sequence)
		"begin_extraction": accepted = command.target.is_empty() and room.game.begin_extraction(who, command.sequence)
		"keep_interaction": accepted = command.target.is_empty() and room.game.keep_interaction(who, command.sequence)
		"cancel_interaction": accepted = command.target.is_empty() and room.game.cancel_interaction(who, command.sequence)
	if not accepted: return false
	views(room)
	return true
func view(room: Dictionary, who: int, notice: String = "") -> void:
	if members.get(room.peers[who], "") != room.code: return
	var snapshot := View.project(room.game, who, room.match_id, room.phase)
	snapshot["notice"] = notice
	packet.emit(room.peers[who], "view", snapshot)
func views(room: Dictionary, notice: String = "") -> void:
	for who in range(room.peers.size()): view(room, who, notice)
func leave(peer: int) -> void:
	if not members.has(peer): return
	var code: String = members[peer]
	var room: Dictionary = rooms[code]
	members.erase(peer)
	_idle[peer] = true
	if room.game != null:
		if room.phase != "finished":
			room.phase = "aborted"
			views(room, "An explorer left. Match ended; return to the room list.")
		if not room.peers.any(func(id): return members.get(id, "") == code): rooms.erase(code)
	elif room.host == peer:
		for id in room.peers:
			if id != peer:
				members.erase(id)
				_idle[id] = true
				packet.emit(id, "closed", {"message": "Room creator left. Choose another room."})
		rooms.erase(code)
	else:
		room.peers.erase(peer)
		lobby(room)
	changed()
func disconnected(peer: int) -> void:
	leave(peer)
	_idle.erase(peer)
	_requests.erase(peer)
	_movement_requests.erase(peer)
