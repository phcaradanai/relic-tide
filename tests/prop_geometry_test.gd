extends SceneTree
const Map = preload("res://scripts/level_map.gd")
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	check(not Map.walkable(Map.from_art(Vector2(240, 250))), "Round plinth remains a physical obstacle")
	check(Map.walkable(Map.from_art(Vector2(212, 214))), "Empty corner of former rectangular globe box is traversable")
	var point := Map.from_art(Vector2(180, 250))
	for i in 40: point = Map.move(point, Vector2.RIGHT, Rules.STEP)
	var art_point := point * Map.ART_SIZE / Map.SIZE
	check(art_point.x > 185 and art_point.x < 201, "Moving feet stop at the actual curved plinth")
	for waypoint: Vector2 in [Vector2(190, 210), Vector2(290, 210), Vector2(290, 250)]:
		var target := Map.from_art(waypoint)
		for i in 100:
			if point.distance_to(target) < 1: break
			point = Map.move(point, (target - point) / (Map.SPEED * Rules.STEP), Rules.STEP)
		check(point.distance_to(target) < 1, "Walk around curved furniture without an invisible corner")
	var game := Rules.new(1, 2)
	for i in 2:
		game.explorers[i].position = Map.from_art(Vector2(180 if i == 0 else 300, 250))
		game.explorers[i].region = "R1"
	game.explorers[0].has_light = true
	var packet: Dictionary = bytes_to_var(var_to_bytes(View.project(game, 0)))
	check(packet.explorers[1].has("position"), "Low open furniture does not hide a lit nearby companion")
	check(Map.line_of_sight(game.explorers[0].position, game.explorers[1].position), "Room props have no rectangular sight wedge")
	check(Map.contains_floor(Map.valve_position()), "Painted valve hand position is reachable on the floor")
	check(Map.walkable(Map.extraction_position()), "Original painted pier has a reachable extraction approach")
	print("Prop geometry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
