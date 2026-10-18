# Notes for Claude

Game jam project in Godot 4.7 (GDScript). Several people work on it with Claude. The design is in README.md and IDEAS.md and changes often, so read those rather than relying on this file for design.

- If a request conflicts with README/IDEAS, or looks likely to cause problems later, say so before building it.
- Keep this file short: only conventions and decisions that the code depends on. Ideas belong in IDEAS.md.

## Decisions

- Renderer: Compatibility, so a web build stays possible. Physics: Jolt.
- Portrait, designed for 720×1280 (9:16).
- Collision layers: 8 = `pick` (instruments' enlarged grab areas), 9 = `drop_zones` (flat areas at table level, see `gameplay/tool_grabber.gd`).
- Gameplay code never names specific instruments. It finds `SurgicalTool` scenes at runtime with `SurgicalTool.scenes_by_id()`; which tools exist is the artists' call.
- The tray's size and shape come only from its `Zone` collision shapes (boxes/cylinders) in `gameplay/tray.tscn`. Code asks the `Tray` (`contains`, `floor_height`, `random_point`, `nearest_placement`) and never assumes dimensions.
- Levels are data: one `LevelData` `.tres` per level in `levels/`, naming tools by `id`, played by `levels/level.tscn`. New per-level settings go on `LevelData`, not in a new scene or subclass.
- UI is English for now, through `tr()`. The placeholder look lives in one theme, `ui/theme.tres`, plus `ui/icons/` (artists restyle there). The screens are `ui/main_menu.tscn` (Play, Pocket Guide, Leaderboard, Settings), `ui/pocket_guide.tscn` and `ui/hud.tscn`, all generated at first but fine to edit by hand.
- Audio: players use the `Music` or `SFX` bus (`default_bus_layout.tres`). `SettingsPanel` saves both volumes to `user://settings.cfg`.
- Export presets: add `addons/godot_ai/*` and `dev/*` to "Filters to exclude files". The plugin already strips its autoload from exports, but its files still ship otherwise.
- Lookalike pairs will live in one central list, not on each tool (avoids out-of-sync data). Not built yet.
- Instrument naming language: undecided. Refer to tools by `id` in code, and pass display names through `tr()`.
- Tool pictures in dialogs: render the model at runtime (`ui/tool_preview.tscn`, slow spin). No PNGs from the artists.

## Surgical tools

- `SurgicalTool` is only for items the player must recognize and hand over. The silly items count (they're `Speciality.SILLY`). Scenery and props don't: trays, tables, dishes, the doctor, the patient. Those are ordinary scenes, and never go in `tools/`.
- Tool scenes live in `tools/` (subfolders fine). Code reads the path from `SurgicalTool.FOLDER`, never a literal.
- Each tool is an inherited scene of `tools/surgical_tool.tscn`, with its model and `CollisionShape3D` children added, and its data set in the `SurgicalTool` exports. No separate data files per tool.
- Collision: boxes or convex shapes only. Never concave/trimesh: tools are dynamic bodies.
- `SurgicalTool.Speciality` and `SurgicalTool.Category` (what the tool does, which groups the Pocket Guide) are append-only, because scenes store them as numbers.
- Models lie flat as they would on a tray (Y up), at real size in meters.
- The instrument scenes (`tools/<slug>.tscn`, `assets/instruments/`) are generated from Julia's Blender export by `dev/instruments/build_instruments.gd`, so don't hand-edit them. See `dev/instruments/README.md`.
- Grabbing: each tool has a `Pick` Area3D on collision layer 8 only (inflated shapes). Raycast that layer with `collide_with_areas`.
- `project.godot` sets Jolt penetration slop 0.001 and speculative distance 0.004; the defaults (0.02) sink millimetre-thin tools.
- Looks: tools and the tray get their materials at runtime from `ToolLook` (`gameplay/tool_look.gd`; shaders and textures in `assets/shaders/`), with a new random tint, scratches, stains and blood placement every tray, so tools are recognised by shape only. Don't set materials in tool scenes. Julia tunes the values in her browser shader lab; `dev/shader_lab/lab.tscn` renders them in Godot.
