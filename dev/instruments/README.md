# Instrument pipeline (dev only, never ships)

Julia builds the instruments in Blender (`~/Desktop/כלי-ניתוח`). The outputs in the game are
generated, so don't hand-edit them. Ask Julia, or rebuild with `build_instruments.gd`.

| Output | What |
|---|---|
| `tools/<slug>.tscn` | 16 tools, each an inherited scene of `tools/surgical_tool.tscn`. Exports filled: `id` (= slug), `display_name` (English, goes through `tr()`), `description`, `specialities` |
| `assets/instruments/<slug>.glb` | Models with embedded 512 px textures (albedo + ORM) |
| `assets/instruments/tray.tscn` | The tray's look and walls: a `StaticBody3D`, not a tool. Origin = middle of its underside; floor top at 1.2 mm. It is the `Body` of `gameplay/tray.tscn`, whose `Zone` box (28×40 cm, bottom on the floor) must match it |
| `assets/instruments/kidney_dish.tscn` | Prop: a plain `RigidBody3D`, not a tool |
| `assets/instruments/kidney_dish.tscn` | A prop (`"body": "prop"` in spec.json): a plain `RigidBody3D`, not a tool |

- `display_name`, `description` and `specialities` are **drafts**. A clinician should check them,
  and the source is Julia's `scripts/spec.json`.
- **Grabbing:** each tool has a `Pick` Area3D on **collision layer 8** only. It holds the same shapes,
  inflated to at least 2 cm, so a finger can hit thin tools. Raycast with `collide_with_areas = true`
  and `collision_mask = 1 << 7`, then take the hit's parent. It does not affect physics.
- **Rummaging hand:** a kinematic body has infinite mass. Keep it above the floor (centre about 2 cm up)
  or it crushes thin tools through the tray. Move it and lift it; never teleport it inside the pile.
- **Tray:** its walls collide 5 cm above the visible rim (invisible), so tools stay inside. Rebuilding
  it keeps `gameplay/tray.tscn` working; if its size changes, update that scene's `Zone` too.
- **Lookalike groups**, ready for the central list:
  - scalpels: `scalpel_10`, `scalpel_11`, `scalpel_15`
  - clamps: `kelly_clamp`, `crile_clamp`, `mayo_hegar`
  - scissors: `mayo_scissors`, `metzenbaum_scissors`, `vannas_scissors`
  - forceps: `adson_forceps`, `debakey_forceps`
  - micro: `micro_needle_holder`, `micro_hook`, `beaver_handle`
- **Tests** (headless unless noted): `tests/check_colliders.gd` (`--script`), `tests/drop_test.tscn`,
  `tests/rummage_test.tscn` (set `DROP_COPIES=2` for a bigger pile), and `tests/drop_view.tscn` and
  `tests/preview_check.tscn`, which render (not headless, `SNAPSHOT=/abs/path.png`).
- **Rebuild:** export from Blender, then run
  `Godot --headless --path . --import` and
  `Godot --headless --path . --script res://dev/instruments/build_instruments.gd`.
