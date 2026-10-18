class_name Tray
extends Node3D
## The tray the tools lie in. It lays tools out, and can slide off the bottom
## of the screen and back (for reshuffles), carrying its tools with it.

## Width and depth of the area in the tray that tools are laid out in.
@export var layout_size := Vector2(0.28, 0.40)
## How much neighbouring tools overlap when laid out (0 = just touching).
@export_range(0.0, 0.5) var overlap := 0.15
## Random turn given to each tool when laid out, in degrees either way.
@export var yaw_jitter_degrees := 8.0
## Where the tray goes when it slides away, relative to where it rests.
@export var away_offset := Vector3(0.0, 0.0, 0.7)
@export var slide_seconds := 0.6

## Parent of the tools in the tray. Give it to ToolGrabber.tools_root.
@onready var tools_root: Node3D = $Tools
## The tray's drop zone. Give it to ToolGrabber.tray_zone.
@onready var zone: Area3D = $Zone
@onready var _rest_position := position


func tools() -> Array[SurgicalTool]:
	var result: Array[SurgicalTool] = []
	for child in tools_root.get_children():
		if child is SurgicalTool and not child.is_queued_for_deletion():
			result.append(child)
	return result


func clear() -> void:
	for tool in tools():
		tool.queue_free()


## Slides off screen with all its tools. Await the returned signal.
func slide_away() -> Signal:
	# Frozen bodies follow their parent; free ones would stay behind.
	for tool in tools():
		tool.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		tool.freeze = true
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", _rest_position + away_offset, slide_seconds)
	return tween.finished


## Slides back into place. Await the returned signal.
func slide_back() -> Signal:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _rest_position, slide_seconds)
	return tween.finished


## Adds the tools and packs them into rows, long side across, longest first.
## When the rows run out of depth, the next tools go in a layer on top and
## fall onto the pile.
func fill(new_tools: Array[SurgicalTool]) -> void:
	var footprints: Dictionary[SurgicalTool, Vector3] = {}
	var centers: Dictionary[SurgicalTool, Vector3] = {}
	for tool in new_tools:
		tools_root.add_child(tool)
		var bounds := ToolPreview.visual_bounds(tool)
		var yaw := 0.0 if bounds.size.x >= bounds.size.z else PI / 2.0
		yaw += deg_to_rad(randf_range(-yaw_jitter_degrees, yaw_jitter_degrees))
		tool.rotation.y = yaw
		var size := bounds.size
		footprints[tool] = Vector3(maxf(size.x, size.z), size.y, minf(size.x, size.z))
		centers[tool] = bounds.get_center().rotated(Vector3.UP, yaw)
	var ordered := new_tools.duplicate()
	ordered.sort_custom(func(a: SurgicalTool, b: SurgicalTool) -> bool:
		return footprints[a].x > footprints[b].x)

	var x := 0.0
	var z := 0.0
	var row_depth := 0.0
	var height := 0.02
	for tool in ordered:
		var size := footprints[tool] * (1.0 - overlap)
		if x > 0.0 and x + size.x > layout_size.x:
			x = 0.0
			z += row_depth
			row_depth = 0.0
		if z > 0.0 and z + size.z > layout_size.y:
			z = 0.0
			height += 0.03
		var slot := Vector3(x + size.x * 0.5 - layout_size.x * 0.5, 0.0, z + size.z * 0.5 - layout_size.y * 0.5)
		var center := centers[tool]
		tool.position = slot - Vector3(center.x, 0.0, center.z) + Vector3.UP * height
		# Staggered so overlapping neighbours don't start inside each other.
		height += 0.004
		x += size.x
		row_depth = maxf(row_depth, size.z)
