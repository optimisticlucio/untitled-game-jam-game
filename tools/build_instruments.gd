extends SceneTree
## Builds res://assets/instruments/<id>_<slug>.tscn for every exported instrument:
## a RigidBody3D (the tray: StaticBody3D) holding the GLB mesh and simple collision shapes.
## Inputs come from the Blender export: <id>_<slug>.glb, data/<id>.json (colliders), data/spec.json.
## Run: Godot --headless --path <repo> --script res://tools/build_instruments.gd
##
## Every movable tool also gets a "pick" Area3D: the same shapes, inflated (PICK_PAD per side,
## at least PICK_MIN across) on collision layer PICK_LAYER only, so a finger-sized touch can grab
## thin tools. Raycast with collide_with_areas and mask (1 << (PICK_LAYER - 1)); the area's
## parent is the tool. It never affects physics.

const DIR := "res://assets/instruments/"
const PICK_LAYER := 8
const PICK_PAD := 0.006
const PICK_MIN := 0.02


func _init() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "data/spec.json"))
	var built := 0
	for id in spec["items"]:
		var it: Dictionary = spec["items"][id]
		var base := "%s_%s" % [id, it["slug"]]
		var glb := DIR + base + ".glb"
		var cols := DIR + "data/%s.json" % id
		if not ResourceLoader.exists(glb) or not FileAccess.file_exists(cols):
			continue
		var body: CollisionObject3D
		if it["body"] == "static":
			body = StaticBody3D.new()
		else:
			var rb := RigidBody3D.new()
			rb.mass = float(it["mass_g"]) / 1000.0
			rb.continuous_cd = true
			body = rb
		body.name = base
		var pm := PhysicsMaterial.new()
		pm.friction = 0.4
		pm.bounce = 0.05
		body.set("physics_material_override", pm)
		body.set_meta("instrument_id", id)
		body.set_meta("name_he", it["he"])
		body.set_meta("name_en", it["en"])
		body.set_meta("lookalike", it["lookalike"] if it["lookalike"] != null else "")
		var visual: Node3D = (load(glb) as PackedScene).instantiate()
		visual.name = "visual"
		body.add_child(visual)
		visual.owner = body
		var i := 0
		for c in JSON.parse_string(FileAccess.get_file_as_string(cols)):
			var cs := CollisionShape3D.new()
			cs.name = "col_%02d_%s" % [i, c["type"]]
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
		var err := ResourceSaver.save(ps, DIR + base + ".tscn")
		print("%s %s (%d shapes)" % ["saved" if err == OK else "ERROR %d" % err, base, i])
		body.free()
		built += 1
	print("built %d instrument scenes" % built)
	quit()


func _add_pick_area(body: Node3D) -> void:
	var area := Area3D.new()
	area.name = "pick"
	area.collision_layer = 1 << (PICK_LAYER - 1)
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	body.add_child(area)
	area.owner = body
	for c in body.get_children():
		if not c is CollisionShape3D:
			continue
		var src: Shape3D = (c as CollisionShape3D).shape
		var cs := CollisionShape3D.new()
		cs.name = c.name
		cs.transform = (c as CollisionShape3D).transform
		cs.shape = _inflate(src)
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
