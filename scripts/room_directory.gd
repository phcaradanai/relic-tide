class_name RoomDirectory
extends RefCounted
## Central room authority. Packet signals are addressed to one peer only.
signal packet(peer: int, kind: String, data: Dictionary)
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
const Maps = preload("res://scripts/expedition_map.gd")
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const MAX_ROOMS := 64
var rooms: Dictionary = {}
var members: Dictionary = {}
var _requests: Dictionary = {}
var _movement_requests: Dictionary = {}
var _idle: Dictionary = {}
var allow_prototype := false
func connected(peer: int) -> void:
	_idle[peer] = true
	list_rooms(peer)
func request(peer: int, kind: String, data: Dictionary) -> void:
	# Movement has a separate budget so a held key cannot starve lobby controls.
	var now := Time.get_ticks_msec()
	var requests: Dictionary = _movement_requests if kind in ["input", "lobby_input"] else _requests
	var bucket: Dictionary = requests.get(peer, {"time": now, "count": 0})
	if now - bucket.time > 1000: bucket = {"time": now, "count": 0}
	bucket.count += 1
	requests[peer] = bucket
	if bucket.count > (40 if kind in ["input", "lobby_input"] else 30): return
	match kind:
		"list": list_rooms(peer)
		"create":
			var map_id = data.get("map_id", "lagoon")
			if typeof(data.get("capacity")) == TYPE_INT and typeof(map_id) == TYPE_STRING and Maps.valid_id(map_id, allow_prototype): create_room(peer, data.capacity, map_id)
			else: error(peer, "Invalid room capacity.")
		"join":
			if typeof(data.get("code")) == TYPE_STRING: join_room(peer, data.code)
			else: error(peer, "Invalid room code.")
		"start": start_room(peer)
		"select_map":
			if data.size() == 1 and typeof(data.get("map_id")) == TYPE_STRING: select_map(peer, data.map_id)
		"ready":
			if data.size() == 1 and typeof(data.get("ready")) == TYPE_BOOL: set_ready(peer, data.ready)
		"lobby_input": accept_lobby_input(peer, data)
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
			result.append({"code": code, "count": room.peers.size(), "limit": room.limit, "joinable": room.peers.size() < room.limit, "map_id": room.map_id})
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
func create_room(peer: int, capacity: int, map_id: String = "prototype") -> bool:
	if members.has(peer):
		error(peer, "Leave your current room first.")
		return false
	if capacity < 2 or capacity > 4 or rooms.size() >= MAX_ROOMS or not Maps.valid_id(map_id, true):
		error(peer, "Cannot create room. Choose 2–4 players or try again later.")
		return false
	var code := new_code()
	rooms[code] = {"code": code, "host": peer, "peers": [peer], "limit": capacity, "phase": "lobby", "game": null, "match_id": "", "map_id": map_id, "staging_map": Maps.new(map_id), "ready": {}, "positions": {}, "lobby_inputs": {}, "lobby_tick": 0}
	_stage_peer(rooms[code], peer, 0)
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
	_stage_peer(room, peer, room.peers.size() - 1)
	members[peer] = code
	_idle.erase(peer)
	lobby(room)
	changed()
	return true
func lobby(room: Dictionary) -> void:
	var ready_states: Array[bool] = []
	for peer in room.peers: ready_states.append(room.ready.get(peer, false))
	for i in range(room.peers.size()):
		packet.emit(room.peers[i], "lobby", {"code": room.code, "count": room.peers.size(), "limit": room.limit, "player": i, "is_host": room.peers[i] == room.host, "map_id": room.map_id, "ready": ready_states, "can_start": room.peers.size() >= 2 and (room.map_id == "prototype" or ready_states.all(func(value): return value)), "staging_view": _staging_view(room, i)})

func _stage_peer(room: Dictionary, peer: int, index: int) -> void:
	room.ready[peer] = false
	room.positions[peer] = room.staging_map.spawn(index)
	room.lobby_inputs[peer] = {"direction": Vector2.ZERO, "sequence": -1, "ack": -1, "tick": -100}

func _staging_token(room: Dictionary) -> String:
	return room.code + ":" + room.map_id + ":waiting"

func _staging_view(room: Dictionary, who: int) -> Dictionary:
	var actors: Array = []
	for index in range(room.peers.size()):
		var peer: int = room.peers[index]
		actors.append({"name": "P%d" % (index + 1), "position": room.positions[peer], "velocity": Vector2.ZERO, "region": "R0", "state": "exploring", "has_light": false, "has_relic": false, "breath": 20.0, "score": 0})
	var closed := {}
	for door_id in room.staging_map.DOORS:
		closed[door_id] = {"position": room.staging_map.door_position(door_id), "horizontal": room.staging_map.DOORS[door_id].horizontal, "progress": 0.0, "locked": true, "target_open": false, "state": "closed", "refuge": room.staging_map.DOORS[door_id].refuge, "sealed_safe": false}
	return {"you": who, "tick": room.lobby_tick, "match_id": _staging_token(room), "phase": "waiting", "ack_sequence": room.lobby_inputs[room.peers[who]].ack, "explorers": actors, "vision_radius": 1250.0, "doors": closed, "water_depths": {}, "map_id": room.map_id}

func select_map(peer: int, map_id: String) -> bool:
	if not members.has(peer) or not Maps.valid_id(map_id): return false
	var room: Dictionary = rooms[members[peer]]
	if room.host != peer or room.phase != "lobby": return false
	if room.map_id == map_id: return true
	room.map_id = map_id
	room.staging_map = Maps.new(map_id)
	room.lobby_tick = 0
	for index in range(room.peers.size()): _stage_peer(room, room.peers[index], index)
	lobby(room)
	changed()
	return true

func set_ready(peer: int, value: bool) -> bool:
	if not members.has(peer): return false
	var room: Dictionary = rooms[members[peer]]
	if room.phase != "lobby": return false
	room.ready[peer] = value
	lobby(room)
	return true

func accept_lobby_input(peer: int, command: Dictionary) -> bool:
	if not members.has(peer): return false
	var room: Dictionary = rooms[members[peer]]
	if room.phase != "lobby" or command.size() != 3 or typeof(command.get("direction")) != TYPE_VECTOR2 or typeof(command.get("sequence")) != TYPE_INT or typeof(command.get("match_id")) != TYPE_STRING: return false
	var direction: Vector2 = command.direction
	if command.match_id != _staging_token(room) or not direction.is_finite() or absf(direction.x) > 1.0 or absf(direction.y) > 1.0 or command.sequence < 0 or command.sequence <= room.lobby_inputs[peer].sequence: return false
	room.lobby_inputs[peer] = {"direction": direction.limit_length(1.0), "sequence": command.sequence, "ack": room.lobby_inputs[peer].ack, "tick": room.lobby_tick}
	return true
func start_room(peer: int) -> bool:
	if not members.has(peer): return false
	var room: Dictionary = rooms[members[peer]]
	if room.host != peer or room.phase != "lobby" or room.peers.size() < 2: return false
	if room.map_id != "prototype" and not room.peers.all(func(id): return room.ready.get(id, false)): return false
	var seed_bytes := Crypto.new().generate_random_bytes(4)
	var seed_value := int(seed_bytes.decode_u32(0))
	room.game = Rules.new(seed_value, room.peers.size(), room.map_id)
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
		if room.phase == "lobby":
			var closed: Array = room.staging_map.DOORS.keys()
			for peer in room.peers:
				var intention: Dictionary = room.lobby_inputs[peer]
				var direction: Vector2 = intention.direction if room.lobby_tick - intention.tick < Rules.INPUT_TIMEOUT_TICKS else Vector2.ZERO
				room.positions[peer] = room.staging_map.move(room.positions[peer], direction, Rules.STEP, closed)
				intention.ack = intention.sequence
			room.lobby_tick += 1
			if room.lobby_tick % 2 == 0: lobby(room)
			continue
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
	if command.target.length() > 64 or command.kind.length() > 32: return false
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
		"chest", "puzzle", "heal", "fire", "cancel_puzzle":
			if room.game.expedition != null: accepted = room.game.expedition.event(room.game, who, command.kind, command.target, command.sequence)
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
		room.positions.erase(peer)
		room.ready.erase(peer)
		room.lobby_inputs.erase(peer)
		lobby(room)
	changed()
func disconnected(peer: int) -> void:
	leave(peer)
	_idle.erase(peer)
	_requests.erase(peer)
	_movement_requests.erase(peer)
