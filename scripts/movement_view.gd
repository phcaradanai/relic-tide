class_name MovementPresentation
extends RefCounted
## Smooth only the local rendered feet. Authority and fixed-step prediction
## keep their own positions; small acknowledgements are not backwards steps.
const Map = preload("res://scripts/level_map.gd")
const Prediction = preload("res://scripts/movement_client.gd")
const MAX_ERROR := Map.SPEED * 0.2
const ERROR_EPSILON := 0.001
const CORRECTION_SPEED := 0.6
var offset := Vector2.ZERO
var previous_preview := Vector2.ZERO
var previous_direction := Vector2.ZERO
var initialized := false

func reset(point: Vector2) -> void:
	offset = Vector2.ZERO
	previous_preview = point
	previous_direction = Vector2.ZERO
	initialized = true

func reconcile(before: Vector2, after: Vector2) -> void:
	offset += before - after
	previous_preview += after - before
	if offset.length() > MAX_ERROR + ERROR_EPSILON: reset(after)

func _preview(prediction, direction: Vector2, seconds: float) -> Vector2:
	if not prediction.active or prediction.pending.size() >= Prediction.MAX_PENDING:
		return prediction.position
	var region: String = prediction.Map.region_at(prediction.position)
	return prediction.Map.move(prediction.position, direction * prediction.move_factor, seconds, prediction.closed_doors, prediction.water_depths.get(region, 0.0), prediction.water_depths, prediction.carrying, prediction.oxygen_enabled)

func _clear_offset(prediction, point: Vector2) -> bool:
	# Check the whole foot path, including low furniture and newly shut gates.
	var steps := maxi(1, ceili(prediction.position.distance_to(point) / 4.0))
	for i in range(1, steps + 1):
		if not prediction.Map.walkable(prediction.position.lerp(point, float(i) / steps), prediction.closed_doors): return false
	return true

func sample(prediction, direction: Vector2, fraction: float, delta: float) -> Vector2:
	var target := _preview(prediction, direction, clampf(fraction, 0.0, Prediction.STEP))
	if not initialized: reset(target)
	# A release/turn can change the fractional preview before the next input tick.
	# Keep that transition continuous rather than snapping back to the tick edge.
	var turning := not direction.is_equal_approx(previous_direction)
	if turning:
		offset += previous_preview - target
		if offset.length() > MAX_ERROR + ERROR_EPSILON: reset(target)
	previous_preview = target
	previous_direction = direction
	var speed := Map.SPEED
	if direction.length_squared() > 0.0:
		speed = prediction.position.distance_to(_preview(prediction, direction, Prediction.STEP)) / Prediction.STEP
	# A catch-up correction cannot outrun a valid forward step, even in water.
	if not turning:
		offset = offset.move_toward(Vector2.ZERO, speed * CORRECTION_SPEED * minf(delta, 0.05))
	var point := target + offset
	if not offset.is_zero_approx() and not _clear_offset(prediction, point):
		offset = Vector2.ZERO
		point = target
	return point
