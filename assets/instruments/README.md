# Surgical instruments

18 items (tray + 17 tools), real size in metres, real mass. Generated from Blender, so don't
edit the `.tscn`/`.glb` by hand: ask Julia, or rebuild with `tools/build_instruments.gd`.

- **Catalog:** `instruments.json` holds id, `name_he`, `name_en`, `lookalike` group and scene path.
  The lookalike groups (`scalpel`, `clamp`, `scissors`, `forceps`, `micro`) are the pairs players
  confuse. Kelly vs Crile: Crile's serrations run the whole jaw, Kelly's only the distal half.
- **Scene:** `RigidBody3D` (tray: `StaticBody3D`) with metadata `instrument_id`, `name_he`,
  `name_en` and `lookalike`, then `visual` (mesh), then box/capsule `CollisionShape3D`s.
- **Grabbing:** each tool has a `pick` Area3D on **collision layer 8** only. It holds the same shapes,
  inflated to at least 2 cm, so a finger can hit thin tools. To grab, raycast from the touch with
  `collide_with_areas = true` and `collision_mask = 1 << 7`, then take the hit's parent. It does not
  affect physics.
- **Rummaging hand:** a kinematic body has infinite mass. Keep it above the floor (centre about 2 cm up)
  or it crushes thin tools through the tray. Move it and lift it; never teleport it inside the pile.
- **Tray:** its walls collide 5 cm above the visible rim (invisible), so tools stay inside.
- **Metal needs reflections:** add a WorldEnvironment with a sky, or a ReflectionProbe, or the
  tools look dark.
- **Lifting a tool to look at it:** move it toward the camera rather than scaling it up. Textures
  are 512 px so close-ups stay sharp.
- **Physics:** `project.godot` lowers Jolt's penetration slop (0.001) and speculative contact
  distance (0.004) for millimetre-thin tools.
- **Tests (headless):** `tools/instrument_tests/` holds `check_colliders.gd` (script),
  `drop_test.tscn` and `rummage_test.tscn`. Set `DROP_COPIES=2` for a bigger pile. `drop_view.tscn`
  renders the same drop.
