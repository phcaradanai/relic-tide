extends SceneTree
const Rules = preload("res://scripts/game.gd")
const Map = preload("res://scripts/level_map.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	for count in range(2, 5):
		var game := Rules.new(1, count)
		check(game.explorers.size() == count, "2–4 human seats")
		for p in game.explorers: check(Map.walkable(p.position) and p.region == "R0", "Every spawn is on Landing floor")
		game.set_input(0, Vector2.RIGHT, 0)
		var before: Vector2 = game.explorers[0].position
		var stationary: Vector2 = game.explorers[1].position
		game.step()
		check(is_equal_approx(game.explorers[0].position.distance_to(before), 8.5), "One tick moves 170px/s without waiting")
		check(game.explorers[1].position == stationary, "Another player can remain stationary")
		check(game.tick == 1, "Server clock advances independently")
	var a := Rules.new()
	check(not a.set_input(-1, Vector2.RIGHT, 0), "Invalid identity rejected")
	check(not a.set_input(0, Vector2(INF, 0), 0), "Nonfinite input rejected")
	check(not a.set_input(0, Vector2(2, 0), 0), "Speed amplification rejected")
	check(a.set_input(0, Vector2(1, -1), 10), "Diagonal intention accepted")
	check(not a.set_input(0, Vector2.ZERO, 10) and not a.set_input(0, Vector2.ZERO, 9), "Duplicate/reordered input rejected")
	var origin: Vector2 = a.explorers[0].position
	a.step()
	check(is_equal_approx(origin.distance_to(a.explorers[0].position), 8.5), "Diagonal has the same speed")
	for i in range(10): a.step()
	var stopped: Vector2 = a.explorers[0].position
	for i in range(10): a.step()
	check(a.explorers[0].position == stopped and a.explorers[0].velocity == Vector2.ZERO, "Stale input expires after 250ms")
	var wall := Rules.new()
	for i in range(100):
		wall.set_input(0, Vector2.LEFT, i)
		wall.step()
		check(Map.walkable(wall.explorers[0].position), "Authority never leaves floor")
	check(wall.explorers[0].position.x >= Map.from_art(Vector2(115, 0)).x + Map.FOOT_RADIUS, "Wall stops full footprint")
	check(not Map.walkable(Map.from_art(Vector2(240, 245))), "Painted Archive fountain blocks feet")
	check(Map.REFUGES == ["R4"], "Exactly one refuge; Landing is ordinary")
	var lantern := Rules.new()
	check(lantern.use_light(0, "take_light", 0), "Nearby physical lantern can be picked up")
	check(not lantern.use_light(1, "take_light", 0), "Contested pickup has exactly one holder")
	check(lantern.lantern.holder == 0 and lantern.explorers[0].has_light, "Light belongs to the successful holder")
	check(not lantern.use_light(0, "drop_light", 0), "Duplicate light event cannot reverse pickup")
	check(lantern.use_light(0, "drop_light", 1), "Holder can drop light at their feet")
	check(lantern.lantern.position == lantern.explorers[0].position and not lantern.explorers[0].has_light, "Drop preserves physical ground position")
	lantern.explorers[1].position = Map.from_art(Vector2(1295, 742))
	check(not lantern.use_light(1, "take_light", 1), "Remote pickup rejected")
	var dark_point := Map.from_art(Vector2(1030, 460))
	check(is_equal_approx(Map.vision_radius(dark_point), 105), "No light gives short local vision")
	check(is_equal_approx(Map.vision_radius(dark_point, true), 220), "Held light gives wider vision")
	check(is_equal_approx(Map.vision_radius(Map.from_art(Vector2(790, 355))), 250), "Standing near torch widens vision")
	check(not Map.line_of_sight(Map.from_art(Vector2(850, 460)), Map.from_art(Vector2(850, 266))), "Walls block sight")
	check(Map.line_of_sight(Map.from_art(Vector2(790, 320)), Map.from_art(Vector2(790, 280))), "Open connector has uninterrupted sight")
	# Navigate every connection and both routes using the same motion as play.
	var path := [Vector2(280, 741), Vector2(280, 480), Vector2(280, 296), Vector2(318, 218), Vector2(460, 218), Vector2(715, 200), Vector2(715, 266), Vector2(790, 266), Vector2(790, 460), Vector2(1295, 460), Vector2(1295, 230), Vector2(1295, 742)]
	var position := Map.spawn(1)
	for waypoint in path:
		var target := Map.from_art(waypoint)
		for i in range(300):
			if position.distance_to(target) < 2: break
			position = Map.move(position, (target - position) / (Map.SPEED * Rules.STEP), Rules.STEP)
		check(position.distance_to(target) < 2, "Connected floor reaches %s" % waypoint)
	var left := Rules.new(7, 4)
	var right := Rules.new(7, 4)
	for i in range(400):
		for who in range(4):
			var direction := Vector2(sin(i * 0.13 + who), cos(i * 0.21 + who))
			left.set_input(who, direction, i)
			right.set_input(who, direction, i)
		left.step()
		right.step()
		check(left.explorers == right.explorers, "Supplied fixed ticks reproduce simulation")
	test_doors_and_water()
	test_valve()
	print("Rules: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func place(game, who: int, position: Vector2) -> void:
	game.explorers[who].position = position
	game.explorers[who].region = Map.region_at(position)
func test_doors_and_water() -> void:
	var game := Rules.new()
	check(not game.toggle_door(0, "D5", 0), "Remote door interaction rejected")
	place(game, 0, Map.door_position("D5") + Vector2(0, 35))
	check(game.toggle_door(0, "D5", 1), "Nearby refuge can begin closing")
	check(not game.toggle_door(0, "D5", 1), "Repeated door event cannot reverse closure")
	for i in range(16): game.step()
	check(game.doors.D5.progress == 0.0, "Unoccupied refuge seals completely")
	place(game, 0, Map.door_position("D5") + Vector2(0, 15))
	for i in range(3): game.step()
	check(game.doors.D5.progress == 0.0, "Standing beside a sealed door cannot reopen it")
	place(game, 0, Map.door_position("D4") + Vector2(0, 35))
	check(not game.toggle_door(0, "D4", 2), "Stage-4 vault latch cannot be bypassed by use")
	game = Rules.new()
	place(game, 0, Map.door_position("D5"))
	game.doors.D5.target_open = false
	for i in range(20): game.step()
	check(game.doors.D5.obstructed and game.doors.D5.progress >= 0.2, "Occupied doorway cannot crush or seal an explorer")
	place(game, 0, Map.door_position("D5") + Vector2(0, 35))
	for i in range(4): game.step()
	check(game.doors.D5.progress == 0.0, "Clearing doorway permits closure")
	var above := Map.door_position("D3") - Vector2(0, 30)
	var below := Map.door_position("D3") + Vector2(0, 30)
	check(Map.line_of_sight(above, below) and not Map.line_of_sight(above, below, ["D3"]), "Actual closed gate blocks sight")
	check(not Map.walkable(Map.door_position("D3"), ["D3"]), "Actual closed gate blocks the walking footprint")
	var sealed := Rules.new()
	sealed.tick = int(7200.0 / Rules.STEP)
	for region in Map.REGIONS: sealed.water_depths[region] = Map.MAX_WATER_DEPTH
	sealed.water_depths.R4 = 0.0
	sealed.doors.D5.progress = Rules.STEP / Rules.DOOR_CLOSE_SECONDS
	sealed.doors.D5.target_open = false
	sealed.step()
	check(sealed.doors.D5.progress == 0.0 and sealed.water_depths.R4 == 0.0, "Final closure precedes same-tick inflow at maximum tide")
	for i in range(1200): sealed.step()
	check(sealed.water_depths.R4 == 0.0, "Dry sealed refuge remains dry far beyond expedition duration")
	sealed.water_depths.R4 = 0.4
	for i in range(40): sealed.step()
	check(is_equal_approx(sealed.water_depths.R4, 0.4), "Late closure retains admitted water")
	place(sealed, 0, Map.door_position("D5") + Vector2(0, 35))
	check(sealed.toggle_door(0, "D5", 0), "Refuge can be deliberately reopened")
	sealed.step()
	check(sealed.water_depths.R4 > 0.4, "Reopening refuge restores physical inflow")
	var open := Rules.new()
	var delayed := Rules.new()
	open.water_depths.C1 = 1.0
	delayed.water_depths.C1 = 1.0
	delayed.doors.D3.progress = 0.0
	delayed.doors.D3.target_open = false
	var volume_before := water_volume(open)
	open.step()
	delayed.step()
	check(delayed.water_depths.R2 > 0.0 and delayed.water_depths.R2 < open.water_depths.R2, "Ordinary closure delays water without creating another refuge")
	check(absf(water_volume(open) - volume_before) < 0.001, "Internal flow conserves water volume across differently sized rooms")
	var wet := below
	var depths := {"C1": Map.MAX_WATER_DEPTH, "R2": 0.0}
	var moved := Map.move(wet, Vector2.UP, Rules.STEP, [], Map.MAX_WATER_DEPTH, depths)
	check(moved.y < wet.y, "Flooded explorer can move toward safety")
	for i in range(30): wet = Map.move(wet, Vector2.UP, Rules.STEP, [], depths.get(Map.region_at(wet), 0.0), depths)
	check(Map.region_at(wet) == "R2", "Flooded explorer can leave a submerged corridor")
	var dry := above
	for i in range(15): dry = Map.move(dry, Vector2.DOWN, Rules.STEP, [], 0.0, depths)
	check(Map.region_at(dry) == "R2", "Dry explorer cannot enter a fully submerged region")
func water_volume(game) -> float:
	var result := 0.0
	for region in Map.REGIONS: result += game.water_depths[region] * game.region_areas[region]
	return result
func test_valve() -> void:
	var game := Rules.new()
	check(not game.begin_valve(0, 0), "Remote valve use rejected")
	place(game, 0, Map.valve_position())
	place(game, 1, Map.valve_position())
	check(game.begin_valve(0, 1), "Nearby explorer can hold physical valve")
	check(not game.begin_valve(1, 0), "One valve has one active operator")
	for i in range(29): game.step()
	check(game.valve_mode == "main", "Valve cannot switch before hold completes")
	game.step()
	check(game.valve_mode == "service" and game.valve_holds.is_empty(), "Completed hold redirects exactly once")
	check(game.begin_valve(0, 2) and game.cancel_interaction(0, 3), "Releasing key cancels a hold")
	for i in range(35): game.step()
	check(game.valve_mode == "service", "Cancelled hold never completes later")
	check(game.begin_valve(1, 1), "Second explorer can operate released valve")
	place(game, 1, Map.spawn(1))
	game.step()
	check(game.valve_holds.is_empty(), "Leaving range cancels valve operation")
	var main_feed := Rules.new()
	var service_feed := Rules.new()
	main_feed.tick = int(120.0 / Rules.STEP)
	service_feed.tick = main_feed.tick
	service_feed.valve_mode = "service"
	for i in range(20):
		main_feed.step()
		service_feed.step()
	check(main_feed.water_depths.C1 > service_feed.water_depths.C1, "Valve route changes actual main crossing water")
	check(service_feed.water_depths.C2 > main_feed.water_depths.C2, "Service route receives the redirected incoming tide")
	service_feed.tick = 0
	service_feed.water_depths.C1 = 1.0
	var before_drain := water_volume(service_feed)
	service_feed.step()
	check(water_volume(service_feed) < before_drain, "Explicit service outlet removes existing water volume")
