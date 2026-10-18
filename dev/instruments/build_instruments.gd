extends SceneTree
## Builds the instrument scenes from Julia's Blender export. Never edit the outputs by hand.
##   tools/<slug>.tscn             inherited scene of tools/surgical_tool.tscn (SurgicalTool)
##   assets/instruments/tray.tscn  the tray: a StaticBody3D, not a tool
## Inputs: assets/instruments/<slug>.glb (model) and dev/instruments/data/ (<slug>.json colliders
## in Godot space, spec.json: mass, display_name, description, specialities).
## Run: Godot --headless --path <repo> --script res://dev/instruments/build_instruments.gd
##
## Every tool also gets a "pick" Area3D: the same shapes, inflated (PICK_PAD per side, at least
## PICK_MIN across) on collision layer PICK_LAYER only, so a finger-sized touch can grab thin
## tools. It never affects physics.

const MODELS := "res://assets/instruments/"
const DATA := "res://dev/instruments/data/"
const BASE := "res://tools/surgical_tool.tscn"
const PICK_LAYER := 8
const PICK_PAD := 0.006
const PICK_MIN := 0.02


func _init() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "spec.json"))
	var base: PackedScene = load(BASE)
	var built := 0
	for key in spec["items"]:
		var it: Dictionary = spec["items"][key]
		var slug: String = it["slug"]
		var glb := MODELS + slug + ".glb"
		var cols := DATA + slug + ".json"
		if not ResourceLoader.exists(glb) or not FileAccess.file_exists(cols):
			continue
		var body: CollisionObject3D
		var out: String
		if it["body"] == "static":
			body = StaticBody3D.new()
			body.name = slug.capitalize().replace(" ", "")
			out = MODELS + slug + ".tscn"
		else:
			var tool := base.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED) as RigidBody3D
			tool.scene_file_path = ""
			tool.name = slug.capitalize().replace(" ", "")
			tool.set("id", StringName(slug))
			tool.set("display_name", it["display_name"])
			tool.set("description", it["description"])
			var sp: Array = tool.get("specialities")
			sp.clear()
			for v in it["specialities"]:
				sp.append(int(v))
			tool.mass = float(it["mass_g"]) / 1000.0
			tool.continuous_cd = true
			body = tool
			out = "res://tools/" + slug + ".tscn"
		var pm := PhysicsMaterial.new()
		pm.friction = 0.4
		pm.bounce = 0.05
		body.set("physics_material_override", pm)
		var visual: Node3D = (load(glb) as PackedScene).instantiate()
		visual.name = "Model"
		body.add_child(visual)
		visual.owner = body
		var i := 0
		for c in JSON.parse_string(FileAccess.get_file_as_string(cols)):
			var cs := CollisionShape3D.new()
			cs.name = "Collision%02d" % i
			cs.shape = _shape(c)
			var b: Array = c["basis_cols"]
			cs.transform = Transform3D(Basis(_v(b[0]), _v(b[1]), _v(b[2])), _v(c["origin"]))
			body.add_child(cs)
			cs.owner = body
			i += 1
		if body is RigidBody3D:
			_add_pick_area(body)
		var ps := PackedScene.new()
		ps.pack(body)
		var err := ResourceSaver.save(ps, out)
		if err == OK and body is RigidBody3D:
			err = _make_inherited(out)
		print("%s %s (%d shapes)" % ["saved" if err == OK else "ERROR %d" % err, out, i])
		body.free()
		built += 1
	print("built %d scenes" % built)
	quit()


## ResourceSaver writes the root as a plain RigidBody3D with the SurgicalTool script (scripts can't set
## a node's inherited state). Rewrite it into the editor's inherited-scene form: the root instances
## tools/surgical_tool.tscn, so later changes to the base reach every tool. Then verify on load.
func _make_inherited(path: String) -> Error:
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	var script_id := ""
	var out_lines: PackedStringArray = []
	var root_done := false
	var re_script := RegEx.create_from_string('^\\[ext_resource type="Script" path="res://tools/surgical_tool.gd" id="([^"]+)"\\]$')
	var re_root := RegEx.create_from_string('^\\[node name="([^"]+)" type="RigidBody3D"[^\\]]*\\]$')
	for line in lines:
		var m := re_script.search(line)
		if m:
			script_id = m.get_string(1)
			out_lines.append('[ext_resource type="PackedScene" path="%s" id="base_tool"]' % BASE)
			continue
		if not root_done:
			var r := re_root.search(line)
			if r:
				out_lines.append('[node name="%s" instance=ExtResource("base_tool")]' % r.get_string(1))
				root_done = true
				continue
		if script_id != "" and line == 'script = ExtResource("%s")' % script_id:
			continue
		out_lines.append(line)
	if script_id == "" or not root_done:
		return ERR_PARSE_ERROR
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(out_lines))
	f.close()
	var ps := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if ps == null or ps.get_state().get_base_scene_state() == null:
		return ERR_INVALID_DATA
	var n := ps.instantiate()
	var ok := n.get_script() != null and (n.get_script() as Script).resource_path == "res://tools/surgical_tool.gd"
	n.free()
	return OK if ok else ERR_INVALID_DATA


func _add_pick_area(body: Node3D) -> void:
	var area := Area3D.new()
	area.name = "Pick"
	area.collision_layer = 1 << (PICK_LAYER - 1)
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	body.add_child(area)
	area.owner = body
	for c in body.get_children():
		if not c is CollisionShape3D:
			continue
		var cs := CollisionShape3D.new()
		cs.name = c.name
		cs.transform = (c as CollisionShape3D).transform
		cs.shape = _inflate((c as CollisionShape3D).shape)
		area.add_child(cs)
		cs.owner = body


func _inflate(src: Shape3D) -> Shape3D:
	if src is BoxShape3D:
		var b := BoxShape3D.new()
		var s := (src as BoxShape3D).size + Vector3.ONE * 2.0 * PICK_PAD
		b.size = Vector3(maxf(s.x, PICK_MIN), maxf(s.y, PICK_MIN), maxf(s.z, PICK_MIN))
		return b
	if src is CylinderShape3D:
		var c := CylinderShape3D.new()
		c.radius = maxf((src as CylinderShape3D).radius + PICK_PAD, PICK_MIN / 2.0)
		c.height = (src as CylinderShape3D).height + 2.0 * PICK_PAD
		return c
	var k := CapsuleShape3D.new()
	k.radius = maxf((src as CapsuleShape3D).radius + PICK_PAD, PICK_MIN / 2.0)
	k.height = maxf((src as CapsuleShape3D).height + 2.0 * PICK_PAD, 2.0 * k.radius)
	return k


func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _shape(c: Dictionary) -> Shape3D:
	match c["type"]:
		"box":
			var box := BoxShape3D.new()
			box.size = _v(c["size"])
			return box
		"cylinder":
			var cyl := CylinderShape3D.new()
			cyl.radius = c["radius"]
			cyl.height = c["height"]
			return cyl
		_:
			var cap := CapsuleShape3D.new()
			cap.radius = c["radius"]
			cap.height = c["height"]
			return cap
