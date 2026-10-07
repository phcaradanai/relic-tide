extends SceneTree
const Directory = preload("res://scripts/room_directory.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	var directory := Directory.new()
	directory.packet.connect(func(peer, kind, data):
		if peer == 101 and kind == "lobby": scene._on_lobby(data))
	directory.create_room(101, 4, "lagoon")
	for peer in [202, 303, 404]: directory.join_room(peer, directory.members[101])
	scene._process(0.0)
	check(scene.game.explorers.size() == 4 and scene.token_positions.size() == 4, "New lobby slots render without indexing old snapshots")
	for peer in [404, 303, 202]:
		directory.leave(peer)
		scene._process(0.0)
		var size: int = scene.game.explorers.size()
		for i in range(4):
			check(scene.explorer_sprites[i].visible == (i < size), "Departing lobby actor is removed")
			check(scene.token_positions.has(i) == (i < size), "Departing feet cannot enter vision update")
	for map_id in ["foundry", "catacombs", "lagoon"]:
		directory.select_map(101, map_id)
		scene._process(0.0)
		check(scene.Map.id == map_id and scene.prediction.Map.id == map_id, "Waiting map replacement updates prediction and presentation")
		check(scene.camera.position == scene.Map.spawn(0), "Waiting camera follows real new-map feet")
	print("Waiting lifecycle: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

