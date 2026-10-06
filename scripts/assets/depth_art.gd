@tool
class_name DepthArt
extends Resource
## A matched raster/depth pair. Values describe visual relief, never flood/collision rules.

@export var image: Texture2D
@export var depth: Texture2D
@export var near_is_white := true

func is_valid() -> bool:
	return image != null and depth != null and image.get_size() == depth.get_size()
