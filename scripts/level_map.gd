class_name RuinMap
extends RefCounted
## Shared authored floor, in logical 1440x900 coordinates. Geometry is invisible.
const SIZE := Vector2(1440, 900)
const ART_SIZE := Vector2(1586, 992)
const FOOT_RADIUS := 9.0
const SPEED := 170.0
const DARK_VISION := 105.0
const LANTERN_VISION := 220.0
const TORCH_VISION := 250.0
const TORCH_REACH := 110.0
const MAX_WATER_DEPTH := 2.2
const SHALLOW_DEPTH := 0.15
const WADING_DEPTH := 0.6
const DEEP_DEPTH := 1.2
const BLOCKING_DEPTH := 1.8
const USE_RADIUS := 64.0
const CARRY_MULTIPLIER := 0.75
const CONTROL_RADIUS := 24.0
const VAULT_CONTROLS := {"A": Vector2(1268, 350), "B": Vector2(1326, 350)}
const RELIC_ART_POSITION := Vector2(1300, 245)
const EXTRACTION_ART_RECT := Rect2(233, 746, 82, 36)
const VALVE_ART_POSITION := Vector2(897, 278)
const ART_TORCHES := [Vector2(245, 375), Vector2(460, 455), Vector2(790, 355), Vector2(1295, 425), Vector2(1295, 650), Vector2(190, 740), Vector2(365, 245), Vector2(790, 270), Vector2(1300, 205)]
const REGIONS := ["R0", "R1", "R2", "R3", "R4", "C0", "C1", "C2"]
const NAMES := {"R0": "Landing", "R1": "Archive", "R2": "Workshop", "R3": "Inner Vault", "R4": "Refuge", "C0": "West Hall", "C1": "Flood Crossing", "C2": "Service Passage"}
const REFUGES := ["R4"]
const DOORS := {
	"D0": {"art_position": Vector2(283, 695), "width": 100.0, "horizontal": true, "regions": ["R0", "C0"], "refuge": false, "initially_open": true, "locked": false},
	"D1": {"art_position": Vector2(283, 307), "width": 100.0, "horizontal": true, "regions": ["C0", "R1"], "refuge": false, "initially_open": true, "locked": false},
	"D2": {"art_position": Vector2(680, 201), "width": 55.0, "horizontal": false, "regions": ["C2", "R2"], "refuge": false, "initially_open": true, "locked": false},
	"D3": {"art_position": Vector2(788, 307), "width": 70.0, "horizontal": true, "regions": ["R2", "C1"], "refuge": false, "initially_open": true, "locked": false},
	"D4": {"art_position": Vector2(1297, 307), "width": 102.0, "horizontal": true, "regions": ["C1", "R3"], "refuge": false, "initially_open": false, "locked": true},
	"D5": {"art_position": Vector2(1297, 678), "width": 102.0, "horizontal": true, "regions": ["C1", "R4"], "refuge": true, "initially_open": true, "locked": false},
}
const CONNECTIONS := [
	{"a": "R0", "b": "C0", "door": "D0", "conductance": 0.5, "threshold": 0.02},
	{"a": "C0", "b": "R1", "door": "D1", "conductance": 0.5, "threshold": 0.03},
	{"a": "C0", "b": "C1", "door": "", "conductance": 0.55, "threshold": 0.0},
	{"a": "R1", "b": "C2", "door": "", "conductance": 0.5, "threshold": 0.02},
	{"a": "C2", "b": "R2", "door": "D2", "conductance": 0.5, "threshold": 0.03},
	{"a": "R2", "b": "C1", "door": "D3", "conductance": 0.5, "threshold": 0.02},
	{"a": "C1", "b": "R3", "door": "D4", "conductance": 0.4, "threshold": 0.06},
	{"a": "C1", "b": "R4", "door": "D5", "conductance": 0.45, "threshold": 0.08},
]
const ART_FLOORS := {
	"R0": [Rect2(115, 695, 305, 87)],
	"R1": [Rect2(130, 184, 265, 123)],
	"R2": [Rect2(680, 174, 65, 133), Rect2(745, 219, 175, 88)],
	"R3": [Rect2(1150, 184, 300, 123)],
	"R4": [Rect2(1200, 678, 245, 137)],
	"C0": [Rect2(233, 307, 100, 388)],
	"C1": [Rect2(333, 430, 913, 65), Rect2(753, 307, 70, 123), Rect2(1246, 307, 102, 371)],
	"C2": [Rect2(395, 174, 285, 55)],
}
# Ground contours of furniture, not opaque walls. The armillary's round
# plinth stops feet; its low, open structure does not cast a solid sight wedge.
const ART_PROP_COLLIDERS := [
	[Vector2(201, 250), Vector2(205, 239), Vector2(216, 228), Vector2(232, 223), Vector2(249, 224), Vector2(265, 231), Vector2(277, 242), Vector2(279, 254), Vector2(272, 265), Vector2(257, 275), Vector2(238, 279), Vector2(221, 275), Vector2(208, 265)],
	[Vector2(336, 184), Vector2(395, 184), Vector2(395, 202), Vector2(336, 202)],
]
const ART_SPAWNS := [Vector2(175, 741), Vector2(240, 741), Vector2(305, 741), Vector2(370, 741)]
static func from_art(point: Vector2) -> Vector2:
	return point * SIZE / ART_SIZE
static func floors(region: String = "") -> Array[Rect2]:
	var result: Array[Rect2] = []
	for id in REGIONS:
		if not region.is_empty() and id != region: continue
		for rect: Rect2 in ART_FLOORS[id]:
			result.append(Rect2(from_art(rect.position), from_art(rect.size)))
	return result
static func spawn(who: int) -> Vector2:
	return from_art(ART_SPAWNS[clampi(who, 0, 3)])
static func door_position(door_id: String) -> Vector2:
	return from_art(DOORS[door_id].art_position)
static func valve_position() -> Vector2:
	return from_art(VALVE_ART_POSITION)
static func vault_control_position(control: String) -> Vector2:
	return from_art(VAULT_CONTROLS[control])
static func relic_position() -> Vector2:
	return from_art(RELIC_ART_POSITION)
static func extraction_rect() -> Rect2:
	return Rect2(from_art(EXTRACTION_ART_RECT.position), from_art(EXTRACTION_ART_RECT.size))
static func extraction_position() -> Vector2:
	return extraction_rect().get_center()
static func door_segment(door_id: String) -> PackedVector2Array:
	var door: Dictionary = DOORS[door_id]
	var half: float = door.width * SIZE.x / ART_SIZE.x * 0.5
	var center: Vector2 = door_position(door_id)
	var across := Vector2(half, 0) if door.horizontal else Vector2(0, half)
	return PackedVector2Array([center - across, center + across])
static func door_barrier(door_id: String) -> Rect2:
	var segment := door_segment(door_id)
	var thickness := 5.0
	return Rect2(segment[0] - Vector2(thickness, thickness), segment[1] - segment[0] + Vector2(thickness * 2, thickness * 2))
static func door_shadow_polygon(door_id: String) -> PackedVector2Array:
	# Rendered wall faces have a 14px reveal band. A shut gate must meet that
	# boundary; otherwise light leaks around its jambs into a hidden room.
	var rect := door_barrier(door_id).grow(14.0)
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
static func door_distance(point: Vector2, door_id: String) -> float:
	var segment := door_segment(door_id)
	var a := segment[0]
	var delta := segment[1] - a
	var t := clampf((point - a).dot(delta) / maxf(delta.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(a + delta * t)
static func closed_door_ids(doors: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for door_id in doors:
		if doors[door_id].progress <= 0.0001: result.append(door_id)
	return result
static func region_at(point: Vector2) -> String:
	for id in REGIONS:
		for rect: Rect2 in floors(id):
			if rect.has_point(point): return id
	return ""
static func contains_floor(point: Vector2) -> bool:
	var art_point := point * ART_SIZE / SIZE
	for id in REGIONS:
		for rect: Rect2 in ART_FLOORS[id]:
			if rect.has_point(art_point): return true
	return false
static func segment_interval(a: Vector2, b: Vector2, rect: Rect2) -> Vector2:
	var near := 0.0
	var far := 1.0
	var difference := b - a
	for axis in range(2):
		if absf(difference[axis]) < 0.00001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]: return Vector2(-1, -1)
		else:
			var one: float = (rect.position[axis] - a[axis]) / difference[axis]
			var two: float = (rect.end[axis] - a[axis]) / difference[axis]
			near = maxf(near, minf(one, two))
			far = minf(far, maxf(one, two))
			if near > far: return Vector2(-1, -1)
	return Vector2(near, far)
static func line_of_sight(a: Vector2, b: Vector2, closed_doors: Array = []) -> bool:
	if not a.is_finite() or not b.is_finite(): return false
	var intervals: Array[Vector2] = []
	for rect: Rect2 in floors():
		var interval := segment_interval(a, b, rect)
		if interval.x >= 0: intervals.append(interval)
	intervals.sort_custom(func(one, two): return one.x < two.x)
	var covered := 0.0
	for interval in intervals:
		if interval.x > covered + 0.00001: return false
		covered = maxf(covered, interval.y)
	if covered < 0.99999: return false
	# Room furniture retains its painted contact shadow. Only architecture and
	# closed doors obstruct eye-level visibility, in both authority and renderer.
	for door_id: String in closed_doors:
		if not DOORS.has(door_id): continue
		var interval := segment_interval(a, b, door_barrier(door_id))
		if interval.x >= 0 and interval.y - interval.x > 0.00001: return false
	return true
static func vision_radius(point: Vector2, has_light: bool = false, closed_doors: Array = []) -> float:
	var radius := LANTERN_VISION if has_light else DARK_VISION
	for art_point: Vector2 in ART_TORCHES:
		var torch := from_art(art_point)
		var distance := point.distance_to(torch)
		if distance < TORCH_REACH and line_of_sight(point, torch, closed_doors):
			radius = maxf(radius, lerpf(DARK_VISION, TORCH_VISION, 1 - distance / TORCH_REACH))
	return radius
static func can_see(point: Vector2, target: Vector2, has_light: bool = false, closed_doors: Array = []) -> bool:
	return can_see_with_radius(point, target, vision_radius(point, has_light, closed_doors), closed_doors)
static func can_see_with_radius(point: Vector2, target: Vector2, radius: float, closed_doors: Array = []) -> bool:
	return point.distance_to(target) <= radius and line_of_sight(point, target, closed_doors)
static func region_visible(point: Vector2, region: String, has_light: bool, closed_doors: Array = []) -> bool:
	if region_at(point) == region: return true
	var radius := vision_radius(point, has_light, closed_doors)
	for rect: Rect2 in floors(region):
		var across := maxi(1, ceili(rect.size.x / 56.0))
		var down := maxi(1, ceili(rect.size.y / 56.0))
		for x in range(across):
			for y in range(down):
				var sample := rect.position + Vector2((float(x) + 0.5) * rect.size.x / across, (float(y) + 0.5) * rect.size.y / down)
				if can_see_with_radius(point, sample, radius, closed_doors): return true
	return false
static func wall_segments() -> Array[PackedVector2Array]:
	# Boundary of the floor union; internal room/corridor seams cast no shadow.
	var result: Array[PackedVector2Array] = []
	var xs: Array[float] = []
	var ys: Array[float] = []
	var all_floors: Array[Rect2] = []
	# Reveal a narrow raster wall face around floors; server LOS still uses the
	# exact floor union and actors are independently filtered with that rule.
	for rect: Rect2 in floors(): all_floors.append(rect.grow(14))
	for rect: Rect2 in all_floors:
		for x: float in [rect.position.x, rect.end.x]:
			if not xs.has(x): xs.append(x)
		for y: float in [rect.position.y, rect.end.y]:
			if not ys.has(y): ys.append(y)
	xs.sort()
	ys.sort()
	for x: float in xs:
		for i in range(ys.size() - 1):
			var middle := Vector2(x, (ys[i] + ys[i + 1]) * 0.5)
			if all_floors.any(func(rect): return rect.has_point(middle - Vector2(0.1, 0))) != all_floors.any(func(rect): return rect.has_point(middle + Vector2(0.1, 0))):
				result.append(PackedVector2Array([Vector2(x, ys[i]), Vector2(x, ys[i + 1])]))
	for y: float in ys:
		for i in range(xs.size() - 1):
			var middle := Vector2((xs[i] + xs[i + 1]) * 0.5, y)
			if all_floors.any(func(rect): return rect.has_point(middle - Vector2(0, 0.1))) != all_floors.any(func(rect): return rect.has_point(middle + Vector2(0, 0.1))):
				result.append(PackedVector2Array([Vector2(xs[i], y), Vector2(xs[i + 1], y)]))
	return result
static func prop_polygons() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for authored: Array in ART_PROP_COLLIDERS:
		var polygon := PackedVector2Array()
		for point: Vector2 in authored: polygon.append(from_art(point))
		result.append(polygon)
	return result
static func prop_blocks_feet(point: Vector2) -> bool:
	for polygon: PackedVector2Array in prop_polygons():
		if Geometry2D.is_point_in_polygon(point, polygon): return true
		for i in polygon.size():
			var closest := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
			if point.distance_to(closest) < FOOT_RADIUS: return true
	return false
static func walkable(point: Vector2, closed_doors: Array = []) -> bool:
	if not point.is_finite(): return false
	if prop_blocks_feet(point): return false
	var footprint := Rect2(point - Vector2.ONE * FOOT_RADIUS, Vector2.ONE * FOOT_RADIUS * 2)
	for door_id: String in closed_doors:
		if footprint.intersects(door_barrier(door_id)): return false
	# Partition the footprint at every floor edge: every resulting cell must be
	# covered. This permits seamless joins without accepting holes or void corners.
	var xs: Array[float] = [footprint.position.x, footprint.end.x]
	var ys: Array[float] = [footprint.position.y, footprint.end.y]
	var all_floors := floors()
	for rect: Rect2 in all_floors:
		for x: float in [rect.position.x, rect.end.x]:
			if x > footprint.position.x and x < footprint.end.x: xs.append(x)
		for y: float in [rect.position.y, rect.end.y]:
			if y > footprint.position.y and y < footprint.end.y: ys.append(y)
	xs.sort()
	ys.sort()
	for i in range(xs.size() - 1):
		for j in range(ys.size() - 1):
			var middle := Vector2((xs[i] + xs[i + 1]) * 0.5, (ys[j] + ys[j + 1]) * 0.5)
			if not all_floors.any(func(rect): return rect.has_point(middle)): return false
	return true
static func speed_multiplier(depth: float) -> float:
	if depth >= DEEP_DEPTH: return 0.35
	if depth >= WADING_DEPTH: return 0.55
	if depth >= SHALLOW_DEPTH: return 0.8
	return 1.0
static func move(point: Vector2, direction: Vector2, seconds: float, closed_doors: Array = [], start_depth: float = 0.0, region_depths: Dictionary = {}, carrying: bool = false) -> Vector2:
	if not direction.is_finite() or not is_finite(seconds) or seconds <= 0: return point
	var displacement := direction.limit_length(1.0) * SPEED * speed_multiplier(start_depth) * (CARRY_MULTIPLIER if carrying else 1.0) * minf(seconds, 0.25)
	var steps := maxi(1, ceili(displacement.length() / 4.0))
	var step := displacement / steps
	for i in range(steps):
		var next := point + Vector2(step.x, 0)
		var next_region := region_at(next)
		if walkable(next, closed_doors) and (next_region == region_at(point) or region_depths.get(next_region, 0.0) < BLOCKING_DEPTH): point = next
		next = point + Vector2(0, step.y)
		next_region = region_at(next)
		if walkable(next, closed_doors) and (next_region == region_at(point) or region_depths.get(next_region, 0.0) < BLOCKING_DEPTH): point = next
	return point
