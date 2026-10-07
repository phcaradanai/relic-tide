extends SceneTree
const Map = preload("res://scripts/expedition_map.gd")
const Legacy = preload("res://scripts/level_map.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _init() -> void:
	test_prototype()
	for map_id: String in Map.PRODUCTION_IDS: test_production(map_id)
	test_isolation()
	print("Expedition maps: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_prototype() -> void:
	var map := Map.new()
	check(map.id == "prototype" and map.SIZE == Legacy.SIZE and map.ART_SIZE == Legacy.ART_SIZE, "Legacy remains an internal constructor default")
	check(map.REGIONS == Legacy.REGIONS and map.DOORS == Legacy.DOORS and map.CONNECTIONS == Legacy.CONNECTIONS, "Legacy metadata stays exact")
	check(map.floors() == Legacy.floors() and map.wall_segments() == Legacy.wall_segments() and map.prop_polygons() == Legacy.prop_polygons(), "Legacy floor, wall and contour geometry stay exact")
	for who in range(4): check(map.spawn(who) == Legacy.spawn(who), "Legacy spawn %d" % who)
	for id: String in Legacy.DOORS:
		check(map.door_position(id) == Legacy.door_position(id) and map.door_segment(id) == Legacy.door_segment(id) and map.door_barrier(id) == Legacy.door_barrier(id), "Legacy door geometry " + id)
	check(map.valve_position() == Legacy.valve_position() and map.relic_position() == Legacy.relic_position() and map.extraction_rect() == Legacy.extraction_rect(), "Legacy mechanism positions")
	var point := Legacy.spawn(0)
	check(map.move(point, Vector2.RIGHT, 0.05) == Legacy.move(point, Vector2.RIGHT, 0.05), "Legacy fixed movement")
	var dark := Legacy.from_art(Vector2(1030, 460))
	check(map.vision_radius(dark) == Legacy.vision_radius(dark), "Legacy lighting")
	check(not Map.valid_id("prototype") and Map.valid_id("prototype", true) and not Map.valid_id("unknown"), "Public catalogue excludes prototype and unknown ids")
	check(Map.catalogue().size() == 3, "Three public maps")

func test_production(map_id: String) -> void:
	var map := Map.new(map_id)
	check(map.id == map_id and map.SIZE == Vector2(3840, 2560) and map.from_art(Vector2(13, 27)) == Vector2(13, 27), map_id + " world coordinates")
	check(map.room_specs.size() == 12 and map.REGIONS.size() > 24 and map.corridors.size() > 12, map_id + " twelve rooms plus looped corridors")
	check(map.CONNECTIONS.size() == map.corridors.size() * 2 and map.DOORS.size() == map.CONNECTIONS.size(), map_id + " two independently gated room entries per corridor")
	check(map.corridors.size() - map.room_specs.size() + 1 >= 3, map_id + " multiple alternate loops")
	check(map.REFUGES == ["R4"], map_id + " exactly one refuge")
	var refuge_connections := 0
	var vault_connections := 0
	for connection: Dictionary in map.CONNECTIONS:
		if connection.a == "R4" or connection.b == "R4":
			refuge_connections += 1
			check(connection.door == "D5" and map.DOORS[connection.door].refuge, map_id + " refuge admits water only through D5")
		if connection.a == "R3" or connection.b == "R3": vault_connections += 1
	check(refuge_connections == 1 and vault_connections == 1, map_id + " shelter and locked vault have no bypass entrances")
	check(map.DOORS.D4.locked and not map.DOORS.D4.initially_open and not map.DOORS.D4.refuge, map_id + " normal locked cooperative vault")
	check(map.DOORS.D0.regions == ["R0", "C0"] and map.DOORS.D1.regions == ["C0", "R1"], map_id + " stable Landing/Archive roles")
	check(map.region_at(map.valve_position()) == "R2" and map.region_at(map.relic_position()) == "R3", map_id + " workshop and vault anchors")
	check(map.region_at(map.extraction_position()) == "R0" and map.walkable(map.extraction_position()), map_id + " extraction inside Landing")
	check(map.vault_control_position("A").distance_to(map.vault_control_position("B")) == 72 and map.region_at(map.vault_control_position("A")) == "C1" and map.region_at(map.vault_control_position("B")) == "C1", map_id + " two separated antechamber controls")
	check(map.walkable(map.vault_control_position("A"), ["D4"]) and map.walkable(map.vault_control_position("B"), ["D4"]), map_id + " both controls reachable outside closed vault")
	for who in range(4): check(map.walkable(map.spawn(who)) and map.region_at(map.spawn(who)) == "R0", map_id + " spawn " + str(who))
	check(map.chest_anchors.size() == 8 and map.chest_anchors.T0.region == "R0" and map.chest_anchors.T1.region == "R0", map_id + " eight shared treasure anchors including two starter chests")
	for anchor: Dictionary in map.chest_anchors.values(): check(map.walkable(anchor.position) and map.region_at(anchor.position) == anchor.region, map_id + " chest " + anchor.id)
	for region: String in map.REGIONS:
		check(not map.floors(region).is_empty() and map.room_power[region], map_id + " explicit floor/power " + region)
	for door_id: String in map.DOORS:
		var location := map.door_position(door_id)
		var axis := Vector2.DOWN if map.DOORS[door_id].horizontal else Vector2.RIGHT
		check(map.walkable(location) and not map.walkable(location, [door_id]), map_id + " physical gate " + door_id)
		check(map.line_of_sight(location - axis * 25, location + axis * 25) and not map.line_of_sight(location - axis * 25, location + axis * 25, [door_id]), map_id + " sight gate " + door_id)
	for room: String in map.room_specs:
		var route := map.find_route(map.spawn(0), map.room_specs[room].centre)
		check(not route.is_empty() and route[-1] == map.room_specs[room].centre, map_id + " connected route " + room)
		check_route(map, route, map_id + " path " + room)
	for hall: Dictionary in map.corridors.values():
		check_route(map, map.find_route(map.room_specs[hall.a].centre, map.room_specs[hall.b].centre), map_id + " chamber-to-chamber path " + hall.region)
	check(map.find_route(map.spawn(0), map.relic_position(), ["D4"]).is_empty(), map_id + " locked vault blocks navigation")
	check(not map.find_route(map.spawn(0), map.relic_position(), ["D0"]).is_empty(), map_id + " alternate route survives Landing gate closure")
	check(map.find_route(map.spawn(0), map.room_specs.R4.centre, ["D5"]).is_empty(), map_id + " sealed refuge blocks navigation")
	check(not map.walkable(Vector2(30, 30)) and not map.line_of_sight(map.spawn(0), Vector2(30, 30)), map_id + " structural walls hide world void")
	check(not map.wall_segments().is_empty(), map_id + " cached real union boundaries")
	for segment: PackedVector2Array in map.wall_segments():
		var middle := (segment[0] + segment[1]) * 0.5
		var normal := Vector2(0.1, 0) if is_equal_approx(segment[0].x, segment[1].x) else Vector2(0, 0.1)
		check(map.contains_floor(middle - normal) != map.contains_floor(middle + normal), map_id + " walls follow floor boundary")
	test_oxygen(map)
	test_lighting(map)
	test_props(map)

func check_route(map, route: Array[Vector2], message: String) -> void:
	var valid := not route.is_empty()
	for number in range(route.size() - 1):
		var first: Vector2 = route[number]
		var last: Vector2 = route[number + 1]
		var steps := maxi(1, ceili(first.distance_to(last) / 8))
		for step in range(steps + 1):
			if not map.walkable(first.lerp(last, float(step) / steps)):
				valid = false
				break
	check(valid, message + " remains on floor at foot width")

func test_oxygen(map) -> void:
	var direction: Vector2 = (map.room_specs.R1.centre - map.room_specs.R0.centre).normalized()
	var start: Vector2 = map.door_position("D0") - direction * 15
	var water := {"C0": map.MAX_WATER_DEPTH}
	var blocked: Vector2 = map.move(start, direction, 0.25, [], 0.0, water)
	var submerged: Vector2 = map.move(start, direction, 0.25, [], 0.0, water, false, true)
	check(map.region_at(blocked) == "R0" and map.region_at(submerged) == "C0", map.id + " oxygen permits submerged-region entry")
	var closed: Vector2 = map.move(start, direction, 0.25, ["D0"], 0.0, water, false, true)
	check(map.region_at(closed) == "R0" and closed.distance_to(start) < 15, map.id + " oxygen never crosses shut gate")
	var carried: Vector2 = map.move(map.spawn(0), Vector2.RIGHT, 0.05, [], 0.0, {}, true)
	check(is_equal_approx(carried.distance_to(map.spawn(0)), 8.5 * map.CARRY_MULTIPLIER), map.id + " unchanged carry slowdown")

func test_lighting(map) -> void:
	var observer: Vector2 = map.room_specs.R0.centre
	var target := observer + Vector2(220, 0)
	check(map.vision_radius(observer) == 1250 and map.can_see(observer, target), map.id + " powered room local visibility")
	map.room_power.R0 = false
	check(map.vision_radius(observer) == 180 and map.vision_radius(observer, true) == 360, map.id + " darkness and held lantern radii")
	check(not map.can_see(observer, target) and map.can_see(observer, target, true), map.id + " lantern reveals dark target")
	map.room_power.R0 = true
	var hall_point: Vector2 = map.door_position("D0") + (map.room_specs.R1.centre - observer).normalized() * 120
	check(map.can_see(observer, hall_point), map.id + " powered open connector reveals nearby hall")
	map.room_power.C0 = false
	check(not map.can_see(observer, hall_point), map.id + " target darkness filters observer in powered room")
	var near_hall: Vector2 = map.door_position("D0") - (map.room_specs.R1.centre - observer).normalized() * 100
	check(map.can_see(near_hall, hall_point, true) and not map.can_see(near_hall, hall_point), map.id + " held light reaches dark hall from lit room")
	check(not map.can_see(near_hall, hall_point, true, ["D0"]), map.id + " light cannot cross closed door")
	map.room_power.C0 = true

func test_isolation() -> void:
	var a := Map.new("lagoon")
	var b := Map.new("lagoon")
	var c := Map.new("foundry")
	a.room_power.R0 = false
	check(b.room_power.R0 and c.room_power.R0, "Room power never crosses expedition instances")
	check(a.DOORS.is_read_only() and a.DOORS.D0.is_read_only() and a.REGIONS.is_read_only() and a.floors().is_read_only() and a.chest_anchors.is_read_only(), "Nested authored geometry and anchors are immutable")
	check(a.spawn(0) != c.spawn(0) and a.room_specs.R4.centre != c.room_specs.R4.centre, "Explicit distinct map permutations")
	var metadata := Map.catalogue()
	metadata[0].name = "Changed locally"
	check(Map.catalogue()[0].name != "Changed locally", "Catalogue metadata does not share mutable state")

func test_props(map) -> void:
	var heights := {"shelf": 85.0, "urns": 45.0, "sarcophagus": 90.0, "engine": 85.0, "pedestal": 48.0, "valve": 60.0, "boat": 82.0, "torch": 36.0}
	var torches := 0
	var refuge_props := 0
	var kinds: Dictionary = {}
	for spec: Dictionary in map.prop_specs:
		check(heights.has(spec.kind) and heights[spec.kind] == spec.height and map.region_at(spec.position) == spec.region, map.id + " shared raster prop anchor " + spec.kind)
		kinds[spec.kind] = true
		if spec.region == "R4":
			refuge_props += 1
			check(spec.kind == "torch", map.id + " refuge has no low obstacle")
		if spec.kind == "torch":
			torches += 1
			check(spec.position == map.room_specs[spec.region].centre + Vector2(-205, -143) and not map.prop_blocks_feet(spec.position), map.id + " wall torch has no foot collider")
		elif spec.kind in ["boat", "valve"]:
			check(map.walkable(spec.position), map.id + " physical interaction remains accessible " + spec.kind)
		else:
			var base: Vector2 = spec.position + Vector2(0, -25) if spec.kind == "pedestal" else spec.position
			check(map.prop_blocks_feet(base) and not map.walkable(base), map.id + " authored low base blocks feet " + spec.kind)
			var reach := 70.0
			check(map.line_of_sight(base - Vector2(reach, 0), base + Vector2(reach, 0)), map.id + " low prop never blocks nearby sight " + spec.kind)
			var half_depth: float = 9 if spec.kind in ["urns", "shelf"] else 7 if spec.kind == "pedestal" else 8 if spec.kind == "engine" else 32.5
			check(not map.walkable(base + Vector2(0, half_depth + 8)) and map.walkable(base + Vector2(0, half_depth + 10)), map.id + " feet stop at actual contact contour " + spec.kind)
			var start := base + Vector2(0, half_depth + 35)
			var stopped: Vector2 = map.move(start, Vector2.UP, 0.25)
			check(map.walkable(stopped) and stopped.y >= base.y + half_depth + map.FOOT_RADIUS and stopped.distance_to(start) < map.SPEED * 0.25, map.id + " fixed movement stops at low contact base " + spec.kind)
			if spec.kind == "urns": check(map.walkable(base + Vector2(26, 15)), map.id + " round urn has no rectangular corner blocker")
			if spec.kind == "sarcophagus": check(map.walkable(base + Vector2(30, 40)), map.id + " sarcophagus keeps bevelled corners")
	check(torches == 12 and refuge_props == 1 and map.prop_specs.size() == 23 and map.prop_polygons().size() == 9, map.id + " authored prop counts")
	check(map.walkable(map.relic_position()) and map.relic_position().distance_to(map.prop_specs.filter(func(spec): return spec.kind == "pedestal")[0].position) == 0, map.id + " pedestal remains aligned with reachable relic")
	check(map.prop_specs.is_read_only() and map.prop_specs[0].is_read_only(), map.id + " prop metadata immutable")
	check(kinds.has("engine") == (map.id == "foundry") and kinds.has("sarcophagus") == (map.id == "catacombs"), map.id + " map-specific low furniture")
	var before: Vector2 = map.prop_polygons()[0][0]
	var copy: Array[PackedVector2Array] = map.prop_polygons()
	copy[0][0] = Vector2.ZERO
	check(map.prop_polygons()[0][0] == before, map.id + " returned projected contours cannot mutate map")
