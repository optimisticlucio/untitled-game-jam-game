extends "res://tools/instrument_tests/drop_test.gd"
## Rummaging: after the drop settles, a finger (kinematic sphere, r = 1 cm) sweeps through the pile
## in a zigzag (centre 2 cm above the floor), lifts out smoothly, then the pile settles again.
## Game note: a kinematic hand has infinite mass; never drive it into the floor or it crushes
## thin tools through it. Keep it above the floor, and move/lift it, never teleport it. Pass = every tool still inside the tray and at rest.
## Then a grab check: a vertical ray onto every tool's centre, against the "pick" areas (layer 8);
## reports how many tools the ray grabs directly (the rest are covered by others).
## Run: Godot --headless --path <repo> res://tools/instrument_tests/rummage_test.tscn

const SETTLE_1 := 3.0
const SWEEP_S := 5.0
const LIFT_S := 0.5
const SETTLE_2 := 3.0
const PICK_MASK := 1 << 7

var finger: AnimatableBody3D


func _ready() -> void:
	super._ready()
	finger = AnimatableBody3D.new()
	finger.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.01
	cs.shape = sp
	finger.add_child(cs)
	finger.position = Vector3(0, 0.3, 0)
	add_child(finger)


func _physics_process(delta: float) -> void:
	elapsed += delta
	frame_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if elapsed < SETTLE_1:
		return
	if elapsed < SETTLE_1 + SWEEP_S:
		var t := (elapsed - SETTLE_1) / SWEEP_S
		var x := sin(t * TAU * 2.0) * tray_half.x * 0.8
		var z := lerpf(-tray_half.z * 0.8, tray_half.z * 0.8, t)
		finger.global_position = Vector3(x, -tray_half.y + 0.02, z)
		return
	if elapsed < SETTLE_1 + SWEEP_S + LIFT_S:
		finger.global_position.y += 0.4 * delta
		return
	if elapsed < SETTLE_1 + SWEEP_S + LIFT_S + SETTLE_2:
		return
	var fails := 0
	var grabbed := 0
	var space := get_world_3d().direct_space_state
	for b in bodies:
		var p := b.global_position
		var inside := absf(p.x) < tray_half.x and absf(p.z) < tray_half.z and p.y > -tray_half.y and p.y < 0.1
		var still := b.sleeping or (b.linear_velocity.length() < 0.01 and b.angular_velocity.length() < 0.2)
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 0.1, 0), PICK_MASK)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		var hit := space.intersect_ray(q)
		var got: bool = not hit.is_empty() and (hit["collider"] as Node).get_parent() == b
		if got:
			grabbed += 1
		print("%s %s pos_mm=%s grab=%s" % ["OK  " if inside and still else "FAIL", b.name, p * 1000.0, "yes" if got else "covered"])
		if not (inside and still):
			fails += 1
	frame_ms.sort()
	print("bodies=%d grabbed_directly=%d physics_ms median=%.3f max=%.3f" % [bodies.size(), grabbed, frame_ms[frame_ms.size() / 2], frame_ms[-1]])
	get_tree().quit(1 if fails > 0 else 0)
