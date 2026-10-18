class_name ToolPreview
extends SubViewportContainer
## Shows a single tool slowly spinning, e.g. in a request dialog.

@export var degrees_per_second := 20.0
## Camera angle above the tray plane. Tools lie flat, so a side-on view
## would mostly show their edge.
@export var camera_elevation_degrees := 40.0

@onready var _pivot: Node3D = %Pivot
@onready var _camera: Camera3D = %Camera3D


func show_tool(scene: PackedScene) -> void:
	if not is_node_ready():
		await ready
	for child in _pivot.get_children():
		child.queue_free()
	var tool := scene.instantiate() as SurgicalTool
	tool.freeze = true
	_pivot.add_child(tool)
	_frame(tool)


func _process(delta: float) -> void:
	_pivot.rotate_y(deg_to_rad(degrees_per_second) * delta)


## Centers the tool on the pivot and pulls the camera back until it fits.
func _frame(tool: SurgicalTool) -> void:
	var bounds := visual_bounds(tool)
	if bounds.size == Vector3.ZERO:
		return
	tool.position = -bounds.get_center()
	var radius := bounds.size.length() * 0.5
	var distance := radius / sin(deg_to_rad(_camera.fov) * 0.5)
	var elevation := deg_to_rad(camera_elevation_degrees)
	_camera.position = Vector3(0.0, sin(elevation), cos(elevation)) * distance
	_camera.look_at(Vector3.ZERO)


## Bounding box of every visible mesh under root, in root's local space.
## Root must be inside the scene tree.
static func visual_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box := root.global_transform.affine_inverse() * visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
