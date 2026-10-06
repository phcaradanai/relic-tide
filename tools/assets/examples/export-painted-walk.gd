extends SceneTree
## Authoring only: reuse the game's existing silhouette isolation unchanged.
const Atlas = preload("res://scripts/sprite_atlas.gd")

func _init() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var target := root.path_join(".asset-work/carry-study")
	DirAccess.make_dir_recursive_absolute(target)
	var source := Image.load_from_file(root.path_join("assets/explorers-unlit-walk.png"))
	var poses := Atlas.extract(source, 6, 4)
	var metadata: Array = []
	for index in range(6):
		var pose: Dictionary = poses[index]
		var name := "frame_%03d.png" % index
		assert(pose.texture.get_image().save_png(target.path_join(name)) == OK)
		var origin: Vector2i = pose.bounds.position - pose.cell_origin
		metadata.append({"file": name, "x": origin.x, "y": origin.y})
	var file := FileAccess.open(target.path_join("poses.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	print("Exported six intact painted walk poses for Aseprite authoring.")
	quit()
