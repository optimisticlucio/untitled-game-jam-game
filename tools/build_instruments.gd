extends SceneTree
## Builds res://assets/instruments/<id>_<slug>.tscn for every exported instrument:
## a RigidBody3D (the tray: StaticBody3D) holding the GLB mesh and simple collision shapes.
## Inputs come from the Blender export: <id>_<slug>.glb, data/<id>.json (colliders), data/spec.json.
## Run: Godot --headless --path <repo> --script res://tools/build_instruments.gd

const DIR := "res://assets/instruments/"


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
		var ps := PackedScene.new()
		ps.pack(body)
		var err := ResourceSaver.save(ps, DIR + base + ".tscn")
		print("%s %s (%d shapes)" % ["saved" if err == OK else "ERROR %d" % err, base, i])
		body.free()
		built += 1
	print("built %d instrument scenes" % built)
	quit()


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
