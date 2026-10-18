extends Node3D
## Drops every built instrument onto the tray; after SETTLE_S all must rest inside it.
## Run headless: Godot --headless --path <repo> res://tools/instrument_tests/drop_test.tscn
## Exit code 0 = pass. Prints one line per instrument and the physics frame time.

const SETTLE_S := 6.0
const DIR := "res://assets/instruments/"
const TRAY_ID := "t1"

var bodies: Array[RigidBody3D] = []
var elapsed := 0.0
var frame_ms: Array[float] = []
var tray_half := Vector3.ZERO


func _ready() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "data/spec.json"))
	var t: Dictionary = spec["items"][TRAY_ID]
	var d: Array = t["dims_mm"]  # [length (Blender Y -> Godot -Z), width (X), height (Z -> Y)]
	tray_half = Vector3(d[1], d[2], d[0]) / 2000.0
	add_child((load(DIR + "%s_%s.tscn" % [TRAY_ID, t["slug"]]) as PackedScene).instantiate())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y := 0.06
	for id in spec["items"]:
		var path := DIR + "%s_%s.tscn" % [id, spec["items"][id]["slug"]]
		if id == TRAY_ID or not ResourceLoader.exists(path):
			continue
		for copy in range(int(OS.get_environment("DROP_COPIES")) if OS.has_environment("DROP_COPIES") else 1):
			var b := (load(path) as PackedScene).instantiate() as RigidBody3D
			b.name = "%s_%d" % [b.name, copy]
			b.position = Vector3(rng.randf_range(-0.6, 0.6) * tray_half.x, y, rng.randf_range(-0.6, 0.6) * tray_half.z)
			b.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, TAU), rng.randf_range(-0.4, 0.4))
			add_child(b)
			bodies.append(b)
			y += 0.025


func _physics_process(delta: float) -> void:
	elapsed += delta
	frame_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if elapsed < SETTLE_S:
		return
	var fails := 0
	for b in bodies:
		var p := b.global_position
		var inside := absf(p.x) < tray_half.x and absf(p.z) < tray_half.z and p.y > -tray_half.y and p.y < 0.1
		var still := b.sleeping or (b.linear_velocity.length() < 0.01 and b.angular_velocity.length() < 0.2)
		print("%s %s pos_mm=%s speed=%.4f" % ["OK  " if inside and still else "FAIL", b.name, p * 1000.0, b.linear_velocity.length()])
		if not (inside and still):
			fails += 1
	frame_ms.sort()
	print("bodies=%d physics_ms median=%.3f max=%.3f" % [bodies.size(), frame_ms[frame_ms.size() / 2], frame_ms[-1]])
	get_tree().quit(1 if fails > 0 else 0)
