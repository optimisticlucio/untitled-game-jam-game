class_name HeldSparkles
## Little stars that float off the held tool's surface in the neon's pastel colours, a magic touch
## on top of its outline (ToolGrabber starts and stops them). They stay behind in the air when the
## tool moves, like a trail. The look is held_sparkles.tscn and its material held_sparkle.tres;
## dev/neon_preview/neon_preview.tscn has sliders for both.

const SCENE := preload("res://gameplay/held_sparkles.tscn")
const NODE := &"HeldSparkles"
## Points on the tool's surface the stars start from.
const SURFACE_POINTS := 300


## Starts the stars on tool, adding them the first time.
static func start(tool: Node3D) -> void:
	var sparkles := tool.get_node_or_null(NodePath(NODE)) as CPUParticles3D
	if sparkles == null:
		sparkles = SCENE.instantiate()
		sparkles.name = NODE
		_spread_over_surface(sparkles, tool)
		tool.add_child(sparkles)
	sparkles.emitting = true


## Stops new stars on tool. The ones already out fade on their own.
static func stop(tool: Node3D) -> void:
	var sparkles := tool.get_node_or_null(NodePath(NODE)) as CPUParticles3D
	if sparkles:
		sparkles.emitting = false


## Gives the stars starting points all over the tool's surface (bigger faces get more), each
## heading out along the surface.
static func _spread_over_surface(sparkles: CPUParticles3D, tool: Node3D) -> void:
	var corners := PackedVector3Array()
	var corner_normals := PackedVector3Array()
	# Running total of the triangles' areas, one entry per triangle.
	var areas := PackedFloat32Array()
	var total := 0.0
	var to_tool := tool.global_transform.affine_inverse()
	for node in tool.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.name in [ToolGrabber.OUTLINE_NODE, ToolGrabber.GLOW_NODE]:
			continue
		var xform := to_tool * mesh_instance.global_transform
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if normals.size() != vertices.size():
				continue
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				indices = PackedInt32Array(range(vertices.size()))
			for i in range(0, indices.size() - 2, 3):
				for k in 3:
					corners.append(xform * vertices[indices[i + k]])
					corner_normals.append((xform.basis * normals[indices[i + k]]).normalized())
				var n := corners.size()
				total += (corners[n - 2] - corners[n - 3]).cross(corners[n - 1] - corners[n - 3]).length() * 0.5
				areas.append(total)
	var points := PackedVector3Array()
	var point_normals := PackedVector3Array()
	if total > 0.0:
		for p in SURFACE_POINTS:
			var first := areas.bsearch(randf() * total) * 3
			var u := randf()
			var v := randf()
			if u + v > 1.0:
				u = 1.0 - u
				v = 1.0 - v
			points.append(corners[first] + (corners[first + 1] - corners[first]) * u
					+ (corners[first + 2] - corners[first]) * v)
			point_normals.append((corner_normals[first] * (1.0 - u - v) + corner_normals[first + 1] * u
					+ corner_normals[first + 2] * v).normalized())
	sparkles.emission_points = points
	sparkles.emission_normals = point_normals
