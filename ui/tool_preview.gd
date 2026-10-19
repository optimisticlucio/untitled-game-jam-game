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
	var bounds := tool.visual_bounds()
	if bounds.size == Vector3.ZERO:
		return
	tool.position = -bounds.get_center()
	var radius := bounds.size.length() * 0.5
	var distance := radius / sin(deg_to_rad(_camera.fov) * 0.5)
	# Tiny tools sit closer than the default 5 cm near plane.
	_camera.near = maxf(distance * 0.05, 0.001)
	var elevation := deg_to_rad(camera_elevation_degrees)
	_camera.position = Vector3(0.0, sin(elevation), cos(elevation)) * distance
	_camera.look_at(Vector3.ZERO)
