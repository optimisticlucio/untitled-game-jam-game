class_name Tray
extends Node3D
## The tray the tools lie in. It lays tools out, and can slide off the bottom
## of the screen and back (for reshuffles), carrying its tools with it.
##
## The Zone's collision shapes are the tray's floor: tools are laid out,
## dropped and returned inside them, and nothing else knows the tray's size.
## To resize or reshape the tray, change the Body (looks and walls) and the
## Zone shapes together. Zone shapes can be any number of boxes and
## cylinders, each with its bottom face on the floor.

## Random spots tried per tool when laying out; the most open one wins.
@export var placement_tries := 40
## Where the tray goes when it slides away, relative to where it rests.
@export var away_offset := Vector3(0.0, 0.0, 0.7)
@export var slide_seconds := 0.6
## How long a freshly filled tray settles off screen before sliding in. The
## player doesn't see it, so the tools fall with settle_gravity times their
## gravity and settle_damping extra drag to get down fast. Whatever slight
## motion is left (about a centimetre) finishes after the tray arrives.
@export var settle_seconds := 0.4
@export var settle_gravity := 4.0
@export var settle_damping := 4.0

## Parent of the tools in the tray.
@onready var tools_root: Node3D = $Tools
## The tray's drop zone, on the drop_zones layer.
@onready var zone: Area3D = $Zone
@onready var _rest_position := position


func _ready() -> void:
	ToolLook.apply_to_tray($Body)


func tools() -> Array[SurgicalTool]:
	var result: Array[SurgicalTool] = []
	for child in tools_root.get_children():
		if child is SurgicalTool and not child.is_queued_for_deletion():
			result.append(child)
	return result


func clear() -> void:
	for tool in tools():
		tool.queue_free()


## True if the point is over the tray floor (its height is ignored), and at
## least margin inside its edge.
func contains(point: Vector3, margin := 0.0) -> bool:
	return _shape_at(point, margin) != null


## Height of the floor under the point, or of the lowest floor if it's off the tray.
func floor_height(point: Vector3) -> float:
	var shape := _shape_at(point)
	if shape:
		return _bottom(shape)
	var lowest := INF
	for each in _shapes():
		lowest = minf(lowest, _bottom(each))
	return lowest


## A random point on the tray floor.
func random_point() -> Vector3:
	var bounds := _bounds()
	for i in 100:
		var point := bounds.position + bounds.size * Vector3(randf(), 0.0, randf())
		if contains(point):
			point.y = floor_height(point)
			return point
	push_warning("Tray: couldn't find a point inside the Zone shapes")
	return _bounds().get_center()


## Where to put the tool so it lies whole on the floor (both ends at least
## margin inside the edge) as close as possible to point: a spot on the
## floor, and a heading near yaw.
## The heading turns in 15° steps, up to 90° either way, when that lets the
## tool sit closer; the smallest turn wins a tie. The result's origin is the
## spot (on the floor) and its basis the heading.
func nearest_placement(tool: SurgicalTool, point: Vector3, yaw: float, margin := 0.0) -> Transform3D:
	var bounds := tool.visual_bounds()
	var middle := _bounds().get_center()
	var start := _nearest_floor_point(point)
	var best := Transform3D(Basis(Vector3.UP, yaw), start)
	var best_distance := INF
	for step in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6]:
		var turn: float = yaw + deg_to_rad(15.0 * step)
		var spot := start
		for i in 50:
			var footprint := _Footprint.new(spot, turn, bounds)
			if contains(footprint.a, margin) and contains(footprint.b, margin):
				break
			spot = spot.move_toward(Vector3(middle.x, spot.y, middle.z), 0.01)
		var distance := Vector2(spot.x - point.x, spot.z - point.z).length()
		# A turn must bring it at least 1 cm closer to be worth it.
		if distance < best_distance - 0.01:
			best = Transform3D(Basis(Vector3.UP, turn), spot)
			best_distance = distance
	best.origin.y = floor_height(best.origin)
	return best


## The middle of the tray's far edge (the one furthest from the player), at
## the top of the zone, in world space. UI above the tray can keep clear of it.
func far_edge() -> Vector3:
	var bounds := _bounds()
	return Vector3(bounds.get_center().x, bounds.end.y, bounds.position.z)


## Slides off screen with all its tools. Await the returned signal.
func slide_away() -> Signal:
	# Out of the physics simulation, so they ride along with the tray. (Even
	# frozen bodies lag behind a moving parent: physics keeps writing back
	# their previous position.) They're cleared afterwards anyway.
	for tool in tools():
		tool.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", _rest_position + away_offset, slide_seconds)
	return tween.finished


## Slides back into place with its tools, which ride along out of the physics
## simulation (as in slide_away) and come back to life once it's in place.
## Await the returned signal.
func slide_back() -> Signal:
	for tool in tools():
		tool.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _rest_position, slide_seconds)
	tween.tween_callback(func() -> void:
		for tool in tools():
			tool.process_mode = Node.PROCESS_MODE_INHERIT)
	return tween.finished


## Jumps to where slide_away leaves it, without animating.
func place_away() -> void:
	position = _rest_position + away_offset


## Lets a freshly filled tray settle off screen (see settle_seconds), then
## puts the tools' physics back to normal.
func settle() -> void:
	var settling := tools()
	for tool in settling:
		tool.gravity_scale *= settle_gravity
		tool.linear_damp += settle_damping
		tool.angular_damp += settle_damping
	await get_tree().create_timer(settle_seconds, false, true).timeout
	for tool in settling:
		if is_instance_valid(tool):
			tool.gravity_scale /= settle_gravity
			tool.linear_damp -= settle_damping
			tool.angular_damp -= settle_damping


## Adds the tools spread over the floor at random angles, longest first. Each
## goes at the most open of placement_tries random spots, with both of its ends
## on the floor. If it still overlaps others (a crowded tray), it starts above
## them and falls onto the pile.
func fill(new_tools: Array[SurgicalTool]) -> void:
	# A new tray: the blood moves too (the tools get their own new look as they're made).
	ToolLook.reshuffle_tray($Body)
	var sizes: Dictionary[SurgicalTool, AABB] = {}
	for tool in new_tools:
		tools_root.add_child(tool)
		sizes[tool] = tool.visual_bounds()
	var ordered := new_tools.duplicate()
	ordered.sort_custom(func(a: SurgicalTool, b: SurgicalTool) -> bool:
		return _length(sizes[a]) > _length(sizes[b]))

	var placed: Array[_Footprint] = []
	for tool: SurgicalTool in ordered:
		var bounds := sizes[tool]
		var best: _Footprint
		for i in placement_tries:
			var candidate := _Footprint.new(random_point(), randf() * TAU, bounds)
			if not (contains(candidate.a) and contains(candidate.b)):
				continue
			candidate.clearance = INF
			for other in placed:
				candidate.clearance = minf(candidate.clearance, candidate.gap_to(other))
			if best == null or candidate.clearance > best.clearance:
				best = candidate
		if best == null:
			best = _Footprint.new(random_point(), randf() * TAU, bounds)
		# Start just above the floor, or above everything it overlaps.
		best.top = floor_height(best.center) + 0.01 + bounds.size.y
		for other in placed:
			if best.gap_to(other) < 0.0:
				best.top = maxf(best.top, other.top + 0.005 + bounds.size.y)
		placed.append(best)
		tool.rotation = Vector3(0.0, best.yaw, 0.0)
		var offset: Vector3 = tool.basis * bounds.get_center()
		tool.global_position = Vector3(best.center.x, best.top - bounds.size.y * 0.5, best.center.z) - offset


## A tool's spot on the floor, as a line along its long side (a to b) with a
## half-width around it.
class _Footprint:
	var center: Vector3
	var yaw: float
	var a: Vector3
	var b: Vector3
	var half_width: float
	var clearance := 0.0
	## Height of the tool's top when it starts.
	var top := 0.0

	func _init(at: Vector3, turn: float, bounds: AABB) -> void:
		center = at
		yaw = turn
		var long_along_x := bounds.size.x >= bounds.size.z
		var half_length := (bounds.size.x if long_along_x else bounds.size.z) * 0.5
		half_width = (bounds.size.z if long_along_x else bounds.size.x) * 0.5
		var axis := (Vector3.RIGHT if long_along_x else Vector3.BACK).rotated(Vector3.UP, yaw)
		a = center - axis * half_length
		b = center + axis * half_length

	## Space between the two tools' outlines; negative when they overlap.
	func gap_to(other: _Footprint) -> float:
		var closest := Geometry3D.get_closest_points_between_segments(a, b, other.a, other.b)
		var flat := closest[0] - closest[1]
		flat.y = 0.0
		return flat.length() - half_width - other.half_width


static func _length(bounds: AABB) -> float:
	return maxf(bounds.size.x, bounds.size.z)


func _shapes() -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	for child in zone.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
	return shapes


## The zone shape whose floor area holds the point (at least margin inside
## its edge), or null.
func _shape_at(point: Vector3, margin := 0.0) -> CollisionShape3D:
	for shape in _shapes():
		var local := shape.global_transform.affine_inverse() * point
		if shape.shape is BoxShape3D:
			var half := (shape.shape as BoxShape3D).size * 0.5
			if absf(local.x) <= half.x - margin and absf(local.z) <= half.z - margin:
				return shape
		elif shape.shape is CylinderShape3D:
			if Vector2(local.x, local.z).length() <= (shape.shape as CylinderShape3D).radius - margin:
				return shape
		else:
			push_warning("Tray: Zone shapes must be boxes or cylinders, not %s" % shape.shape.get_class())
	return null


## The point on the floor (any zone shape) closest to point, ignoring height.
func _nearest_floor_point(point: Vector3) -> Vector3:
	var best := point
	var best_distance := INF
	for shape in _shapes():
		var local := shape.global_transform.affine_inverse() * point
		if shape.shape is BoxShape3D:
			var half := (shape.shape as BoxShape3D).size * 0.5
			local.x = clampf(local.x, -half.x, half.x)
			local.z = clampf(local.z, -half.z, half.z)
		elif shape.shape is CylinderShape3D:
			var flat := Vector2(local.x, local.z).limit_length((shape.shape as CylinderShape3D).radius)
			local.x = flat.x
			local.z = flat.y
		var candidate := shape.global_transform * local
		var distance := Vector2(candidate.x - point.x, candidate.z - point.z).length()
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _bottom(shape: CollisionShape3D) -> float:
	var height := 0.0
	if shape.shape is BoxShape3D:
		height = (shape.shape as BoxShape3D).size.y
	elif shape.shape is CylinderShape3D:
		height = (shape.shape as CylinderShape3D).height
	return (shape.global_transform * Vector3(0.0, -height * 0.5, 0.0)).y


## World-space box around all the zone shapes.
func _bounds() -> AABB:
	var bounds: AABB
	var first := true
	for shape in _shapes():
		var box := shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
