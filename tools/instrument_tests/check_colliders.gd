extends SceneTree
## Every instrument scene: the collision shapes must wrap the mesh (within 1.5 mm)
## without more than 5 mm extra per side (or the item's spec "overshoot_mm" + 1). Exit code 1 on any failure.
## Run: Godot --headless --path <repo> --script res://tools/instrument_tests/check_colliders.gd

const DIR := "res://assets/instruments/"


func _init() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "data/spec.json"))
	var fails := 0
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".tscn"):
			continue
		var root: Node3D = (load(DIR + f) as PackedScene).instantiate()
		var mesh_box := AABB()
		var col_box := AABB()
		var have_mesh := false
		var have_col := false
		for n in _all(root):
			if n is MeshInstance3D:
				var mb: AABB = _xf(n, root) * (n as MeshInstance3D).get_aabb()
				mesh_box = mesh_box.merge(mb) if have_mesh else mb
				have_mesh = true
			elif n is CollisionShape3D and n.get_parent() == root:  # physics shapes only, not the pick area
				var cb: AABB = _xf(n, root) * (n as CollisionShape3D).shape.get_debug_mesh().get_aabb()
				col_box = col_box.merge(cb) if have_col else cb
				have_col = true
		var id: String = root.get_meta("instrument_id", "")
		var limit := 0.005
		if spec["items"].has(id) and spec["items"][id].has("overshoot_mm"):
			limit = (float(spec["items"][id]["overshoot_mm"]) + 1.0) / 1000.0
		var extra := (col_box.size - mesh_box.size) / 2.0
		var ok := have_mesh and have_col and col_box.grow(0.0015).encloses(mesh_box) \
			and extra.x < limit and extra.y < limit and extra.z < limit
		print("%s %s mesh_mm=%s shapes_mm=%s" % ["OK  " if ok else "FAIL", f, mesh_box.size * 1000.0, col_box.size * 1000.0])
		if not ok:
			fails += 1
		root.free()
	quit(1 if fails > 0 else 0)


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _xf(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
