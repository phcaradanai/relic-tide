extends SceneTree
## Headless central room server; clients and server share the same RPC node path.
const Network = preload("res://scripts/session.gd")
var session
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var port := 24567
	var address := "127.0.0.1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): port = int(arg.substr(7))
		elif arg.begins_with("--bind="): address = arg.substr(7)
	var parent := Node.new()
	parent.name = "RelicTide"
	root.add_child(parent)
	session = Network.new()
	session.name = "Session"
	parent.add_child(session)
	var error: Error = session.serve(port, address)
	if error != OK:
		printerr("Room server could not start: ", error_string(error))
		quit(1)
	else: print("Relic Tide room server ready on %s:%d" % [address, port])
