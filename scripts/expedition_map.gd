class_name ExpeditionMap
extends RefCounted
## Authored geometry is frozen per expedition. Only room power is mutable.
const Legacy = preload("res://scripts/level_map.gd")
const PRODUCTION_IDS := ["lagoon", "foundry", "catacombs"]
const FOOT_RADIUS := Legacy.FOOT_RADIUS
const SPEED := Legacy.SPEED
const MAX_WATER_DEPTH := Legacy.MAX_WATER_DEPTH
const SHALLOW_DEPTH := Legacy.SHALLOW_DEPTH
const WADING_DEPTH := Legacy.WADING_DEPTH
const DEEP_DEPTH := Legacy.DEEP_DEPTH
const BLOCKING_DEPTH := Legacy.BLOCKING_DEPTH
const USE_RADIUS := Legacy.USE_RADIUS
const CARRY_MULTIPLIER := Legacy.CARRY_MULTIPLIER
const CONTROL_RADIUS := Legacy.CONTROL_RADIUS
const POWERED_VISION := 1250.0
const CELL_SIZE := 256.0
const HALL_WIDTH := 144.0
const ROOM_SIZE := Vector2(520, 380)
# Painted furniture uses small ground contacts; it never adds eye-level occlusion.
const FURNITURE := {
	"shelf": {"height": 85.0, "half": Vector2(40, 9)},
	"urns": {"height": 45.0, "half": Vector2(20, 9), "round": true},
	"sarcophagus": {"height": 90.0, "half": Vector2(22.5, 32.5)},
	"engine": {"height": 85.0, "half": Vector2(27.5, 8)},
	"writing_desk": {"height": 42.0, "half": Vector2(27, 8)},
	"chair": {"height": 34.0, "half": Vector2(8, 4)},
	"bookcase": {"height": 80.0, "half": Vector2(44, 8)},
	"cot": {"height": 36.0, "half": Vector2(27, 10)},
	"crates": {"height": 46.0, "half": Vector2(27, 10)},
	"barrels": {"height": 44.0, "half": Vector2(21, 8), "round": true},
	"rope": {"height": 22.0, "half": Vector2(14, 6), "round": true},
	"sacks": {"height": 33.0, "half": Vector2(17, 7), "round": true},
	"workbench": {"height": 64.0, "half": Vector2(33, 9)},
	"anvil": {"height": 43.0, "half": Vector2(17, 7)},
	"pump": {"height": 72.0, "half": Vector2(22, 8), "round": true},
	"chart_table": {"height": 42.0, "half": Vector2(26, 7)},
	"planter": {"height": 47.0, "half": Vector2(14, 8), "round": true},
	"armillary": {"height": 76.0, "half": Vector2(23, 7), "round": true},
	"altar": {"height": 70.0, "half": Vector2(29, 10)},
	"ossuary": {"height": 62.0, "half": Vector2(36, 10)},
}
# Offsets are authored ensembles, not random clutter. Centre axes stay clear for portals.
const COMMON_FURNISHINGS := {
	"R0": [["crates", -158, -91], ["barrels", -218, -88], ["rope", -135, -145], ["chart_table", 137, -105], ["chair", 145, -55], ["sacks", 214, -108]],
	"R1": [["shelf", -152, -91], ["writing_desk", 132, -103], ["chair", 140, -57], ["bookcase", -133, 134], ["planter", 209, -117], ["sacks", -215, 139]],
	"R2": [["workbench", -139, -87], ["chair", -144, -38], ["anvil", 132, 131], ["crates", 205, 142], ["sacks", -214, -108]],
	"R3": [["altar", -155, -88], ["armillary", 155, -89], ["urns", -185, 129], ["urns", 185, 137]],
	"R4": [["cot", -149, -90], ["planter", -218, -86], ["writing_desk", 147, -99], ["chair", 150, -52], ["sacks", -183, 135], ["barrels", 180, 135]],
}
const THEMED_FURNISHINGS := {
	"lagoon": {
		"R5": [["pump", -155, -87], ["urns", -218, -93], ["rope", 133, -138], ["barrels", 176, -88], ["crates", -161, 140], ["sacks", -220, 144]],
		"R6": [["planter", -151, -91], ["planter", -217, -82], ["writing_desk", 145, -98], ["chair", 148, -52], ["planter", 192, 139], ["sacks", 120, 137]],
		"R7": [["armillary", -153, -85], ["urns", -222, -86], ["chart_table", 145, -100], ["chair", 140, -53], ["planter", -168, 141], ["urns", 181, 133]],
		"R8": [["chart_table", -140, -102], ["chair", -147, -55], ["armillary", 160, -87], ["bookcase", -162, 142], ["barrels", -220, -93]],
		"R9": [["crates", -139, -89], ["barrels", -217, -85], ["sacks", -148, -143], ["crates", 149, -92], ["sacks", 217, -101], ["barrels", -176, 133], ["rope", 145, 143], ["sacks", 205, 138]],
		"R10": [["pump", -157, -85], ["pump", 153, -91], ["rope", -214, -119], ["urns", 214, -82], ["barrels", -168, 136], ["crates", 172, 141]],
		"R11": [["armillary", -153, -84], ["chart_table", 143, -100], ["chair", 145, -54], ["planter", 213, -116], ["bookcase", 173, 143]],
	},
	"foundry": {
		"R5": [["engine", -159, -91], ["anvil", 149, -93], ["sacks", 216, -101], ["workbench", -154, 140], ["barrels", -220, -84]],
		"R6": [["workbench", -145, -89], ["chair", -146, -38], ["anvil", 149, -93], ["crates", 216, -89], ["pump", 165, 140]],
		"R7": [["engine", -156, -89], ["pump", 159, -85], ["barrels", -221, -87], ["engine", -166, 141], ["crates", 149, 139], ["sacks", 213, 140]],
		"R8": [["crates", -145, -92], ["barrels", -219, -88], ["crates", 142, -93], ["sacks", 216, -102], ["bookcase", -155, 139], ["rope", -219, 142]],
		"R9": [["pump", -154, -86], ["pump", 157, -89], ["barrels", -219, -84], ["rope", 214, -125], ["barrels", -174, 137], ["sacks", 174, 139]],
		"R10": [["armillary", -151, -87], ["urns", -217, -87], ["writing_desk", 148, -100], ["chair", 151, -53], ["altar", -163, 141], ["crates", 171, 138]],
		"R11": [["engine", -153, -90], ["pump", 152, -87], ["barrels", -219, -87], ["rope", 213, -116], ["crates", 167, 140], ["sacks", 220, 141]],
	},
	"catacombs": {
		"R5": [["ossuary", -147, -86], ["ossuary", 147, -92], ["urns", -218, -90], ["urns", 220, -94], ["sarcophagus", -153, 134]],
		"R6": [["sarcophagus", -148, -78], ["altar", 153, -89], ["urns", -217, -91], ["urns", 214, -91], ["ossuary", 174, 141]],
		"R7": [["altar", -151, -87], ["armillary", 154, -89], ["urns", -219, -85], ["urns", 215, -89], ["ossuary", -161, 142], ["bookcase", 161, 142]],
		"R8": [["sarcophagus", -143, -79], ["sarcophagus", 145, -76], ["urns", -217, -92], ["urns", 217, -92], ["ossuary", -165, 140]],
		"R9": [["altar", -153, -88], ["shelf", 145, -89], ["chair", 148, -37], ["urns", -218, -90], ["urns", -180, 133], ["urns", 174, 139]],
		"R10": [["crates", -145, -91], ["ossuary", 147, -85], ["sacks", -216, -105], ["urns", 221, -91], ["crates", -166, 139], ["urns", 173, 139]],
		"R11": [["altar", -151, -88], ["sarcophagus", 151, -76], ["urns", -217, -91], ["urns", 215, -92], ["ossuary", 171, 142]],
	},
}
const COMMON_DETAILS := {
	"R0": [["netting", -166, -98, 80], ["mineral", -204, 111, 35]],
	"R1": [["rug", 138, -78, 110], ["papers", 206, 85, 28], ["stone_chips", -135, 125, 55]],
	"R2": [["grate", -141, -50, 110], ["tools", 170, 118, 35], ["mineral", 183, -108, 65]],
	"R3": [["rug", 0, -35, 140], ["pottery", -175, 115, 38], ["stone_chips", 186, 125, 50]],
	"R4": [["rug", 0, 28, 140], ["papers", 203, -74, 25]],
}
const THEMED_DETAILS := {
	"lagoon": {
		"R5": [["grate", 0, 20, 110], ["mineral", -157, -73, 85]],
		"R6": [["rug", 141, -78, 100], ["mineral", -157, -72, 95], ["stone_chips", 175, 127, 40]],
		"R7": [["mineral", 0, 28, 115], ["stone_chips", -160, -74, 65]],
		"R8": [["rug", -140, -79, 110], ["papers", -204, 116, 30]],
		"R9": [["netting", -146, -78, 80], ["pottery", 177, 127, 42]],
		"R10": [["grate", 0, 25, 125], ["mineral", 153, -75, 90]],
		"R11": [["rug", 141, -77, 110], ["papers", -110, 30, 30]],
	},
	"foundry": {
		"R5": [["grate", -140, 20, 125], ["tools", 157, -81, 40], ["stone_chips", 195, 61, 40]],
		"R6": [["grate", 0, 28, 140], ["tools", -144, -73, 42], ["stone_chips", 159, 130, 45]],
		"R7": [["grate", 0, 20, 140], ["tools", -161, 127, 40], ["mineral", 160, -76, 90]],
		"R8": [["netting", -138, -80, 90], ["mineral", 149, -75, 80], ["papers", -196, 128, 28]],
		"R9": [["grate", 0, 25, 140], ["mineral", 155, -77, 90], ["tools", -165, 128, 30]],
		"R10": [["rug", 0, 20, 140], ["papers", 171, -76, 28]],
		"R11": [["grate", 0, 25, 125], ["tools", -160, -76, 40], ["mineral", 156, -77, 90]],
	},
	"catacombs": {
		"R5": [["stone_chips", 0, 30, 95], ["pottery", -154, -73, 44]],
		"R6": [["rug", 0, 25, 140], ["pottery", 154, -74, 44]],
		"R7": [["rug", 0, 20, 140], ["pottery", -171, 127, 42]],
		"R8": [["stone_chips", 0, 45, 85], ["pottery", 161, -68, 42], ["mineral", -139, -72, 70]],
		"R9": [["rug", 0, 20, 145], ["pottery", -171, 123, 45], ["papers", 140, -75, 30]],
		"R10": [["stone_chips", 0, 25, 85], ["mineral", -157, 125, 70], ["pottery", 170, 122, 40]],
		"R11": [["rug", 0, 25, 145], ["pottery", 174, -67, 40], ["stone_chips", -156, -75, 50]],
	},
}
const LAYOUTS := {
	"lagoon": {"order": ["R0", "R1", "R2", "R3", "R5", "R6", "R7", "R8", "R4", "R9", "R10", "R11"], "edges": [["R0", "R1"], ["R2", "R3"], ["R1", "R2"], ["R5", "R4"], ["R0", "R5"], ["R1", "R6"], ["R2", "R7"], ["R5", "R6"], ["R6", "R7"], ["R7", "R8"], ["R8", "R11"], ["R7", "R10"], ["R6", "R9"], ["R9", "R10"], ["R10", "R11"]]},
	"foundry": {"order": ["R4", "R5", "R6", "R7", "R3", "R2", "R1", "R0", "R8", "R9", "R10", "R11"], "edges": [["R0", "R1"], ["R2", "R3"], ["R1", "R2"], ["R5", "R4"], ["R5", "R2"], ["R5", "R6"], ["R6", "R1"], ["R6", "R7"], ["R7", "R0"], ["R0", "R11"], ["R1", "R10"], ["R2", "R9"], ["R9", "R8"], ["R9", "R10"], ["R10", "R11"]]},
	"catacombs": {"order": ["R8", "R3", "R2", "R9", "R7", "R6", "R1", "R10", "R4", "R5", "R0", "R11"], "edges": [["R0", "R1"], ["R2", "R3"], ["R1", "R2"], ["R5", "R4"], ["R5", "R0"], ["R5", "R6"], ["R6", "R7"], ["R7", "R8"], ["R6", "R1"], ["R2", "R9"], ["R9", "R10"], ["R10", "R1"], ["R10", "R11"], ["R11", "R0"]]},
}
var id := "prototype"
var SIZE := Legacy.SIZE
var ART_SIZE := Legacy.ART_SIZE
var DARK_VISION := Legacy.DARK_VISION
var LANTERN_VISION := Legacy.LANTERN_VISION
var TORCH_VISION := Legacy.TORCH_VISION
var TORCH_REACH := Legacy.TORCH_REACH
var REGIONS: Array = []
var NAMES: Dictionary = {}
var REFUGES: Array = []
var DOORS: Dictionary = {}
var CONNECTIONS: Array = []
var VAULT_CONTROLS: Dictionary = {}
var ART_FLOORS: Dictionary = {}
var ART_SPAWNS: Array = []
var ART_TORCHES: Array = []
var ART_PROP_COLLIDERS: Array = []
var RELIC_ART_POSITION := Vector2.ZERO
var EXTRACTION_ART_RECT := Rect2()
var VALVE_ART_POSITION := Vector2.ZERO
var room_specs: Dictionary = {}
var corridors: Dictionary = {}
var prop_specs: Array[Dictionary] = []
var chest_anchors: Dictionary = {}
var chests: Dictionary:
	get: return chest_anchors
var room_power: Dictionary = {}
var power: Dictionary:
	get: return room_power
var map_id: String:
	get: return id
var spawnpoint: Vector2:
	get: return spawn(0)
var _all_floors: Array[Rect2] = []
var _floor_regions: Array[String] = []
var _region_floors: Dictionary = {}
var _floor_cells: Dictionary = {}
var _door_cells: Dictionary = {}
var _door_barriers: Dictionary = {}
var _prop_cells: Dictionary = {}
var _prop_polygons: Array[PackedVector2Array] = []
var _walls: Array[PackedVector2Array] = []
var _adjacency: Dictionary = {}

static func catalogue() -> Array[Dictionary]:
	return [
		{"id": "lagoon", "name": "The Drowned Lagoon", "description": "Flooded galleries, cisterns and a northern vault."},
		{"id": "foundry", "name": "The Brass Foundry", "description": "Engine rooms and looping furnace passages."},
		{"id": "catacombs", "name": "The Sunken Catacombs", "description": "Long crypt passages and a secluded refuge."},
	]

static func valid_id(value: String, include_prototype: bool = false) -> bool:
	return value in PRODUCTION_IDS or (include_prototype and value == "prototype")

func _init(value: String = "prototype") -> void:
	id = value if valid_id(value, true) else "prototype"
	if id == "prototype": _load_prototype()
	else: _load_production()
	_cache_geometry()
	for region: String in REGIONS: room_power[region] = true
	for authored in [REGIONS, NAMES, REFUGES, DOORS, CONNECTIONS, VAULT_CONTROLS, ART_FLOORS, ART_SPAWNS, ART_TORCHES, ART_PROP_COLLIDERS, room_specs, corridors, prop_specs, chests]: _freeze(authored)

func _freeze(value) -> void:
	if value is Dictionary:
		for child in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze(child)
		value.make_read_only()

func _load_prototype() -> void:
	REGIONS = Legacy.REGIONS.duplicate()
	NAMES = Legacy.NAMES.duplicate(true)
	REFUGES = Legacy.REFUGES.duplicate()
	DOORS = Legacy.DOORS.duplicate(true)
	CONNECTIONS = Legacy.CONNECTIONS.duplicate(true)
	VAULT_CONTROLS = Legacy.VAULT_CONTROLS.duplicate(true)
	ART_FLOORS = Legacy.ART_FLOORS.duplicate(true)
	ART_SPAWNS = Legacy.ART_SPAWNS.duplicate()
	ART_TORCHES = Legacy.ART_TORCHES.duplicate()
	ART_PROP_COLLIDERS = Legacy.ART_PROP_COLLIDERS.duplicate(true)
	RELIC_ART_POSITION = Legacy.RELIC_ART_POSITION
	EXTRACTION_ART_RECT = Legacy.EXTRACTION_ART_RECT
	VALVE_ART_POSITION = Legacy.VALVE_ART_POSITION

func _load_production() -> void:
	SIZE = Vector2(3840, 2560)
	ART_SIZE = SIZE
	DARK_VISION = 180.0
	LANTERN_VISION = 360.0
	TORCH_VISION = POWERED_VISION
	TORCH_REACH = POWERED_VISION
	REFUGES = ["R4"]
	var labels: Array = {
		"lagoon": ["Landing", "Archive", "Workshop", "Inner Vault", "Refuge", "Cistern", "Glasshouse", "Tide Gallery", "Navigation Room", "Storage", "Reservoir", "Observatory"],
		"foundry": ["Landing", "Archive", "Workshop", "Inner Vault", "Refuge", "Furnace", "Foundry", "Engine Room", "Storehouse", "Coolant Room", "Brass Gallery", "Pump House"],
		"catacombs": ["Landing", "Archive", "Workshop", "Inner Vault", "Refuge", "Ossuary", "Crypt Gallery", "Reliquary", "Burial Chamber", "Memorial Hall", "Stone Store", "Deep Chapel"],
	}[id]
	var order: Array = LAYOUTS[id].order
	for number in range(12):
		var region := "R%d" % number
		var cell: int = order.find(region)
		var center := Vector2(480 + 880 * (cell % 4), 440 + 800 * (cell / 4))
		var rect := Rect2(center - ROOM_SIZE * 0.5, ROOM_SIZE)
		REGIONS.append(region)
		NAMES[region] = labels[number]
		ART_FLOORS[region] = [rect]
		room_specs[region] = {"region": region, "center": center, "centre": center, "rect": rect, "floor": rect, "kind": ["landing", "archive", "workshop", "vault", "refuge"][number] if number < 5 else "chamber", "name": labels[number]}
		ART_TORCHES.append(center + Vector2(-205, -143))
	var door_number := 8
	var edges: Array = LAYOUTS[id].edges
	for number in range(edges.size()):
		var door_ids: Array = ["D0", "D1"] if number == 0 else ["D2", "D4"] if number == 1 else ["D3", "D6"] if number == 2 else ["D7", "D5"] if number == 3 else ["D%d" % door_number, "D%d" % (door_number + 1)]
		if number >= 4: door_number += 2
		_add_corridor("C%d" % number, edges[number][0], edges[number][1], door_ids)
	var landing: Vector2 = room_specs.R0.center
	for who in range(4): ART_SPAWNS.append(landing + Vector2(-108 + who * 72, 70))
	VALVE_ART_POSITION = room_specs.R2.center + Vector2(170, -95)
	RELIC_ART_POSITION = room_specs.R3.center + Vector2(0, -70)
	EXTRACTION_ART_RECT = Rect2(landing + Vector2(-90, 105), Vector2(180, 55))
	var approach: Vector2 = (room_specs.R3.center - room_specs.R2.center).normalized()
	var across := Vector2(-approach.y, approach.x)
	var controls_center: Vector2 = DOORS.D4.art_position - approach * 110
	VAULT_CONTROLS = {"A": controls_center - across * 36, "B": controls_center + across * 36}
	for number in range(8):
		var region := "R%d" % ([0, 0, 1, 2, 5, 6, 8, 11][number])
		chest_anchors["T%d" % number] = {"id": "T%d" % number, "region": region, "position": room_specs[region].center + Vector2(155 if number % 2 == 0 else -155, 110), "kind": "chest"}
	_load_props()

func _load_props() -> void:
	for region: String in room_specs:
		var center: Vector2 = room_specs[region].centre
		_add_prop("torch", center + Vector2(-205, -143), 36, region)
		match region:
			"R0": _add_prop("boat", extraction_position(), 82, region)
			"R2": _add_prop("valve", valve_position(), 60, region)
			"R3": _add_prop("pedestal", relic_position(), 48, region, _oval_contour(relic_position() + Vector2(0, -25), Vector2(18, 7)))
		var furnishings: Array = COMMON_FURNISHINGS.get(region, THEMED_FURNISHINGS[id].get(region, []))
		for furnishing: Array in furnishings:
			var kind: String = furnishing[0]
			var anchor := center + Vector2(furnishing[1], furnishing[2])
			var spec: Dictionary = FURNITURE[kind]
			var half: Vector2 = spec.half
			var contour: Array = _oval_contour(anchor, half) if spec.get("round", false) else _bevel_contour(anchor, half)
			_add_prop(kind, anchor, spec.height, region, contour)
		var details: Array = COMMON_DETAILS.get(region, THEMED_DETAILS[id].get(region, []))
		for detail: Array in details:
			_add_prop(detail[0], center + Vector2(detail[1], detail[2]), detail[3], region, [], true)

func _add_prop(kind: String, point: Vector2, height: float, region: String, contour: Array = [], floor_detail: bool = false) -> void:
	prop_specs.append({"kind": kind, "position": point, "height": height, "region": region, "contour": contour, "floor_detail": floor_detail})
	if not contour.is_empty(): ART_PROP_COLLIDERS.append(contour)

func _box_contour(center: Vector2, half: Vector2) -> Array[Vector2]:
	return [center - half, center + Vector2(half.x, -half.y), center + half, center + Vector2(-half.x, half.y)]

func _bevel_contour(center: Vector2, half: Vector2) -> Array[Vector2]:
	var bevel := minf(7.0, minf(half.x, half.y) * 0.5)
	return [center + Vector2(-half.x + bevel, -half.y), center + Vector2(half.x - bevel, -half.y), center + Vector2(half.x, -half.y + bevel), center + Vector2(half.x, half.y - bevel), center + Vector2(half.x - bevel, half.y), center + Vector2(-half.x + bevel, half.y), center + Vector2(-half.x, half.y - bevel), center + Vector2(-half.x, -half.y + bevel)]

func _oval_contour(center: Vector2, radius: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for number in range(16):
		var angle := float(number) / 16 * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _add_corridor(region: String, a: String, b: String, door_ids: Array) -> void:
	var first: Vector2 = room_specs[a].center
	var last: Vector2 = room_specs[b].center
	var direction := (last - first).normalized()
	var horizontal := absf(direction.x) > 0.5
	var extent := ROOM_SIZE.x * 0.5 if horizontal else ROOM_SIZE.y * 0.5
	var start := first + direction * extent
	var finish := last - direction * extent
	var minimum := Vector2(minf(start.x, finish.x), minf(start.y, finish.y))
	var length := start.distance_to(finish)
	var rect := Rect2(minimum - Vector2(0, HALL_WIDTH * 0.5), Vector2(length, HALL_WIDTH)) if horizontal else Rect2(minimum - Vector2(HALL_WIDTH * 0.5, 0), Vector2(HALL_WIDTH, length))
	var half := rect.size * Vector2(0.5, 1) if horizontal else rect.size * Vector2(1, 0.5)
	var second := rect.position + Vector2(half.x, 0) if horizontal else rect.position + Vector2(0, half.y)
	REGIONS.append(region)
	NAMES[region] = "Vault Antechamber" if region == "C1" else "Service Pump Hall" if region == "C2" else "Passage %d" % (corridors.size() + 1)
	ART_FLOORS[region] = [Rect2(rect.position, half), Rect2(second, half)]
	corridors[region] = {"region": region, "a": a, "b": b, "rect": rect, "floor": rect, "rects": ART_FLOORS[region], "center": rect.get_center(), "centre": rect.get_center(), "doors": door_ids, "horizontal": horizontal, "path": [start, rect.get_center(), finish]}
	for side in range(2):
		var room := a if side == 0 else b
		var door_id: String = door_ids[side]
		DOORS[door_id] = {"art_position": start if side == 0 else finish, "width": HALL_WIDTH, "horizontal": not horizontal, "regions": [room, region] if side == 0 else [region, room], "room": room, "refuge": room == "R4", "initially_open": door_id != "D4", "locked": door_id == "D4"}
		CONNECTIONS.append({"a": room if side == 0 else region, "b": region if side == 0 else room, "door": door_id, "conductance": 0.5, "threshold": 0.08 if room == "R4" else 0.06 if room == "R3" else 0.02})

func _cache_geometry() -> void:
	for region: String in REGIONS:
		var projected: Array[Rect2] = []
		for rect: Rect2 in ART_FLOORS[region]:
			var floor_rect := Rect2(from_art(rect.position), from_art(rect.size))
			_index_rect(_floor_cells, floor_rect, _all_floors.size())
			_all_floors.append(floor_rect)
			_floor_regions.append(region)
			projected.append(floor_rect)
		projected.make_read_only()
		_region_floors[region] = projected
		_adjacency[region] = []
	for door_id: String in DOORS:
		var segment := door_segment(door_id)
		var barrier := Rect2(segment[0] - Vector2(5, 5), segment[1] - segment[0] + Vector2(10, 10))
		_door_barriers[door_id] = barrier
		_index_rect(_door_cells, barrier, door_id)
	for connection: Dictionary in CONNECTIONS:
		_adjacency[connection.a].append({"region": connection.b, "door": connection.door})
		_adjacency[connection.b].append({"region": connection.a, "door": connection.door})
	for contour: Array in ART_PROP_COLLIDERS:
		var polygon := PackedVector2Array()
		for point: Vector2 in contour: polygon.append(from_art(point))
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon: bounds = bounds.expand(point)
		_index_rect(_prop_cells, bounds.grow(FOOT_RADIUS), _prop_polygons.size())
		_prop_polygons.append(polygon)
	_walls = Legacy.wall_segments() if id == "prototype" else _build_walls()
	_all_floors.make_read_only()
	_floor_regions.make_read_only()
	_walls.make_read_only()

func _index_rect(index: Dictionary, rect: Rect2, item) -> void:
	var low := Vector2i(floori(rect.position.x / CELL_SIZE), floori(rect.position.y / CELL_SIZE))
	var high := Vector2i(floori(rect.end.x / CELL_SIZE), floori(rect.end.y / CELL_SIZE))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var cell := Vector2i(x, y)
			if not index.has(cell): index[cell] = []
			index[cell].append(item)

func _candidates(index: Dictionary, bounds: Rect2) -> Array:
	var result: Array = []
	var low := Vector2i(floori(bounds.position.x / CELL_SIZE), floori(bounds.position.y / CELL_SIZE))
	var high := Vector2i(floori(bounds.end.x / CELL_SIZE), floori(bounds.end.y / CELL_SIZE))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for item in index.get(Vector2i(x, y), []):
				if not result.has(item): result.append(item)
	return result

func from_art(point: Vector2) -> Vector2:
	return Legacy.from_art(point) if id == "prototype" else point
func floors(region: String = "") -> Array[Rect2]:
	if id == "prototype": return Legacy.floors(region)
	return _all_floors if region.is_empty() else _region_floors.get(region, [])
func spawn(who: int) -> Vector2:
	return Legacy.spawn(who) if id == "prototype" else ART_SPAWNS[clampi(who, 0, 3)]
func door_position(door_id: String) -> Vector2:
	return Legacy.door_position(door_id) if id == "prototype" else DOORS[door_id].art_position
func valve_position() -> Vector2:
	return Legacy.valve_position() if id == "prototype" else VALVE_ART_POSITION
func vault_control_position(control: String) -> Vector2:
	return Legacy.vault_control_position(control) if id == "prototype" else VAULT_CONTROLS[control]
func relic_position() -> Vector2:
	return Legacy.relic_position() if id == "prototype" else RELIC_ART_POSITION
func extraction_rect() -> Rect2:
	return Legacy.extraction_rect() if id == "prototype" else EXTRACTION_ART_RECT
func extraction_position() -> Vector2:
	return extraction_rect().get_center()
func door_segment(door_id: String) -> PackedVector2Array:
	if id == "prototype": return Legacy.door_segment(door_id)
	var door: Dictionary = DOORS[door_id]
	var half: float = door.width * 0.5
	var across := Vector2(half, 0) if door.horizontal else Vector2(0, half)
	return PackedVector2Array([door.art_position - across, door.art_position + across])
func door_barrier(door_id: String) -> Rect2:
	return Legacy.door_barrier(door_id) if id == "prototype" else _door_barriers[door_id]
func door_shadow_polygon(door_id: String) -> PackedVector2Array:
	if id == "prototype": return Legacy.door_shadow_polygon(door_id)
	# The local light follows legal feet. Expanding the barrier into walkable
	# space can put that source inside a closed shadow and black out its room.
	var rect := door_barrier(door_id)
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
func door_distance(point: Vector2, door_id: String) -> float:
	if id == "prototype": return Legacy.door_distance(point, door_id)
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, door_segment(door_id)[0], door_segment(door_id)[1]))
func closed_door_ids(doors: Dictionary) -> Array[String]:
	return Legacy.closed_door_ids(doors)
func segment_interval(a: Vector2, b: Vector2, rect: Rect2) -> Vector2:
	return Legacy.segment_interval(a, b, rect)
func region_at(point: Vector2) -> String:
	if id == "prototype": return Legacy.region_at(point)
	if not point.is_finite(): return ""
	for index in _floor_cells.get(Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE)), []):
		if _all_floors[index].has_point(point): return _floor_regions[index]
	return ""
func contains_floor(point: Vector2) -> bool:
	return Legacy.contains_floor(point) if id == "prototype" else not region_at(point).is_empty()

func line_of_sight(a: Vector2, b: Vector2, closed_doors: Array = []) -> bool:
	if id == "prototype": return Legacy.line_of_sight(a, b, closed_doors)
	if not a.is_finite() or not b.is_finite(): return false
	var bounds := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y)))
	var intervals: Array[Vector2] = []
	for index in _candidates(_floor_cells, bounds):
		var interval := segment_interval(a, b, _all_floors[index])
		if interval.x >= 0: intervals.append(interval)
	intervals.sort_custom(func(one, two): return one.x < two.x)
	var covered := 0.0
	for interval in intervals:
		if interval.x > covered + 0.00001: return false
		covered = maxf(covered, interval.y)
	if covered < 0.99999: return false
	for door_id in _candidates(_door_cells, bounds):
		if door_id not in closed_doors: continue
		var interval := segment_interval(a, b, _door_barriers[door_id])
		if interval.x >= 0 and interval.y - interval.x > 0.00001: return false
	return true

func vision_radius(point: Vector2, has_light: bool = false, closed_doors: Array = []) -> float:
	if id == "prototype": return Legacy.vision_radius(point, has_light, closed_doors)
	if room_power.get(region_at(point), false): return POWERED_VISION
	return LANTERN_VISION if has_light else DARK_VISION
func can_see(point: Vector2, target: Vector2, has_light: bool = false, closed_doors: Array = []) -> bool:
	return can_see_with_radius(point, target, vision_radius(point, has_light, closed_doors), closed_doors, has_light)
func can_see_with_radius(point: Vector2, target: Vector2, radius: float, closed_doors: Array = [], has_light: bool = false) -> bool:
	if id == "prototype": return Legacy.can_see_with_radius(point, target, radius, closed_doors)
	var target_region := region_at(target)
	if target_region.is_empty(): return false
	var reach := radius
	if not room_power.get(target_region, false):
		var held_light := has_light or is_equal_approx(radius, LANTERN_VISION)
		reach = minf(reach, LANTERN_VISION if held_light else DARK_VISION)
	return point.distance_to(target) <= reach and line_of_sight(point, target, closed_doors)

func region_visible(point: Vector2, region: String, has_light: bool, closed_doors: Array = []) -> bool:
	if id == "prototype": return Legacy.region_visible(point, region, has_light, closed_doors)
	if region_at(point) == region: return true
	var radius := vision_radius(point, has_light, closed_doors)
	if not room_power.get(region, false): radius = minf(radius, LANTERN_VISION if has_light else DARK_VISION)
	var bounds := Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2)
	for rect: Rect2 in floors(region):
		if not rect.intersects(bounds, true): continue
		var near := Vector2(clampf(point.x, rect.position.x + 0.01, rect.end.x - 0.01), clampf(point.y, rect.position.y + 0.01, rect.end.y - 0.01))
		if can_see_with_radius(point, near, radius, closed_doors, has_light): return true
		var overlap := rect.intersection(bounds)
		var across := maxi(1, ceili(overlap.size.x / 96.0))
		var down := maxi(1, ceili(overlap.size.y / 96.0))
		for x in range(across):
			for y in range(down):
				var sample := overlap.position + Vector2((x + 0.5) * overlap.size.x / across, (y + 0.5) * overlap.size.y / down)
				if can_see_with_radius(point, sample, radius, closed_doors, has_light): return true
	return false

func _build_walls() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var xs: Array[float] = []
	var ys: Array[float] = []
	for rect: Rect2 in _all_floors:
		for x: float in [rect.position.x, rect.end.x]:
			if not xs.has(x): xs.append(x)
		for y: float in [rect.position.y, rect.end.y]:
			if not ys.has(y): ys.append(y)
	xs.sort()
	ys.sort()
	for axis in range(2):
		var across := xs if axis == 0 else ys
		var along := ys if axis == 0 else xs
		for fixed: float in across:
			var start := -1.0
			for number in range(along.size() - 1):
				var point := Vector2(fixed, (along[number] + along[number + 1]) * 0.5) if axis == 0 else Vector2((along[number] + along[number + 1]) * 0.5, fixed)
				var normal := Vector2(0.1, 0) if axis == 0 else Vector2(0, 0.1)
				var edge := contains_floor(point - normal) != contains_floor(point + normal)
				if edge and start < 0: start = along[number]
				if start >= 0 and (not edge or number == along.size() - 2):
					var finish: float = along[number + 1] if edge else along[number]
					result.append(PackedVector2Array([Vector2(fixed, start), Vector2(fixed, finish)]) if axis == 0 else PackedVector2Array([Vector2(start, fixed), Vector2(finish, fixed)]))
					start = -1.0
	return result
func wall_segments() -> Array[PackedVector2Array]:
	return _walls
func prop_polygons() -> Array[PackedVector2Array]:
	if id == "prototype": return Legacy.prop_polygons()
	var result: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in _prop_polygons: result.append(polygon.duplicate())
	return result
func prop_blocks_feet(point: Vector2) -> bool:
	if id == "prototype": return Legacy.prop_blocks_feet(point)
	if not point.is_finite(): return false
	for index in _candidates(_prop_cells, Rect2(point, Vector2.ZERO)):
		var polygon := _prop_polygons[index]
		if Geometry2D.is_point_in_polygon(point, polygon): return true
		for number in range(polygon.size()):
			var closest := Geometry2D.get_closest_point_to_segment(point, polygon[number], polygon[(number + 1) % polygon.size()])
			if point.distance_to(closest) < FOOT_RADIUS: return true
	return false

func walkable(point: Vector2, closed_doors: Array = []) -> bool:
	if id == "prototype": return Legacy.walkable(point, closed_doors)
	if not point.is_finite() or prop_blocks_feet(point): return false
	var footprint := Rect2(point - Vector2.ONE * FOOT_RADIUS, Vector2.ONE * FOOT_RADIUS * 2)
	for door_id in _candidates(_door_cells, footprint):
		if door_id in closed_doors and footprint.intersects(_door_barriers[door_id]): return false
	var xs: Array[float] = [footprint.position.x, footprint.end.x]
	var ys: Array[float] = [footprint.position.y, footprint.end.y]
	var candidates := _candidates(_floor_cells, footprint)
	for index in candidates:
		var rect := _all_floors[index]
		for x: float in [rect.position.x, rect.end.x]:
			if x > footprint.position.x and x < footprint.end.x and not xs.has(x): xs.append(x)
		for y: float in [rect.position.y, rect.end.y]:
			if y > footprint.position.y and y < footprint.end.y and not ys.has(y): ys.append(y)
	xs.sort()
	ys.sort()
	for x in range(xs.size() - 1):
		for y in range(ys.size() - 1):
			var middle := Vector2((xs[x] + xs[x + 1]) * 0.5, (ys[y] + ys[y + 1]) * 0.5)
			if not candidates.any(func(index): return _all_floors[index].has_point(middle)): return false
	return true
func speed_multiplier(depth: float) -> float:
	return Legacy.speed_multiplier(depth)
func move(point: Vector2, direction: Vector2, seconds: float, closed_doors: Array = [], start_depth: float = 0.0, region_depths: Dictionary = {}, carrying: bool = false, oxygen_enabled: bool = false) -> Vector2:
	if id == "prototype": return Legacy.move(point, direction, seconds, closed_doors, start_depth, region_depths, carrying)
	if not direction.is_finite() or not is_finite(seconds) or seconds <= 0: return point
	var displacement := direction.limit_length(1.0) * SPEED * speed_multiplier(start_depth) * (CARRY_MULTIPLIER if carrying else 1.0) * minf(seconds, 0.25)
	var steps := maxi(1, ceili(displacement.length() / 4.0))
	var step := displacement / steps
	for number in range(steps):
		for axis in range(2):
			var next := point + (Vector2(step.x, 0) if axis == 0 else Vector2(0, step.y))
			var next_region := region_at(next)
			if walkable(next, closed_doors) and (oxygen_enabled or next_region == region_at(point) or region_depths.get(next_region, 0.0) < BLOCKING_DEPTH): point = next
	return point

func _inside_route(region: String, first: Vector2, last: Vector2) -> Array[Vector2]:
	if id != "prototype" and room_specs.has(region):
		var center: Vector2 = room_specs[region].centre
		var room_points: Array[Vector2] = [last]
		if not first.is_equal_approx(center) and not last.is_equal_approx(center): room_points.push_front(center)
		return room_points
	var rects: Array[Rect2] = _region_floors[region]
	var start := -1
	var finish := -1
	for number in range(rects.size()):
		if start < 0 and rects[number].grow(0.01).has_point(first): start = number
		if finish < 0 and rects[number].grow(0.01).has_point(last): finish = number
	if start < 0 or finish < 0: return []
	var queue: Array[int] = [start]
	var previous := {start: -1}
	var head := 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		if current == finish: break
		for number in range(rects.size()):
			if not previous.has(number) and rects[current].intersects(rects[number], true):
				previous[number] = current
				queue.append(number)
	if not previous.has(finish): return []
	var chain: Array[int] = [finish]
	while chain[-1] != start: chain.append(previous[chain[-1]])
	chain.reverse()
	var points: Array[Vector2] = []
	for number in range(chain.size() - 1): points.append(_overlap_center(rects[chain[number]], rects[chain[number + 1]]))
	points.append(last)
	return points

func find_route(first: Vector2, last: Vector2, closed_doors: Array = []) -> Array[Vector2]:
	var origin := region_at(first)
	var destination := region_at(last)
	if origin.is_empty() or destination.is_empty(): return []
	var queue: Array[String] = [origin]
	var previous := {origin: {"region": "", "door": ""}}
	var head := 0
	while head < queue.size():
		var current: String = queue[head]
		head += 1
		if current == destination: break
		for edge: Dictionary in _adjacency[current]:
			if edge.door in closed_doors or previous.has(edge.region): continue
			previous[edge.region] = {"region": current, "door": edge.door}
			queue.append(edge.region)
	if not previous.has(destination): return []
	var chain: Array[String] = [destination]
	while chain[-1] != origin: chain.append(previous[chain[-1]].region)
	chain.reverse()
	var result: Array[Vector2] = [first]
	var cursor := first
	for number in range(chain.size() - 1):
		var door_id: String = previous[chain[number + 1]].door
		var portal := door_position(door_id) if not door_id.is_empty() else _shared_portal(chain[number], chain[number + 1])
		var part := _inside_route(chain[number], cursor, portal)
		if part.is_empty(): return []
		result.append_array(part)
		cursor = portal
	result.append_array(_inside_route(destination, cursor, last))
	return result

func _shared_portal(a: String, b: String) -> Vector2:
	for one: Rect2 in _region_floors[a]:
		for two: Rect2 in _region_floors[b]:
			if one.intersects(two, true): return _overlap_center(one, two)
	return Vector2.ZERO

func _overlap_center(a: Rect2, b: Rect2) -> Vector2:
	return (Vector2(maxf(a.position.x, b.position.x), maxf(a.position.y, b.position.y)) + Vector2(minf(a.end.x, b.end.x), minf(a.end.y, b.end.y))) * 0.5

func region_center(region: String) -> Vector2:
	if room_specs.has(region): return room_specs[region].centre
	if corridors.has(region): return corridors[region].centre
	var region_floors := floors(region)
	return region_floors[0].get_center() if not region_floors.is_empty() else Vector2.ZERO
