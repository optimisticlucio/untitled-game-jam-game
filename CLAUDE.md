# Notes for Claude

Game jam project in Godot 4.7 (GDScript). Several people work on it with Claude. The design is in README.md and IDEAS.md and changes often, so read those rather than relying on this file for design.

- If a request conflicts with README/IDEAS, or looks likely to cause problems later, say so before building it.
- Keep this file short: only conventions and decisions that the code depends on. Ideas belong in IDEAS.md.

## Decisions
- Renderer: Compatibility, so a web build stays possible. Physics: Jolt.
- Export presets: add `addons/godot_ai/*` to "Filters to exclude files". The plugin already strips its autoload from exports, but its files still ship otherwise.
- Lookalike pairs will live in one central list, not on each tool (avoids out-of-sync data). Not built yet.
- Instrument naming language: undecided. Refer to tools by `id` in code, and pass display names through `tr()`.
- Tool pictures in dialogs: render the model at runtime (`ui/tool_preview.tscn`, slow spin). No PNGs from the artists.

## Tools (`tools/`)
- Each tool is an inherited scene of `tools/surgical_tool.tscn`, with its model and `CollisionShape3D` children added, and its data set in the `SurgicalTool` exports. No separate data files per tool.
- Collision: boxes or convex shapes only. Never concave/trimesh: tools are dynamic bodies.
- `SurgicalTool.Speciality` is append-only, because scenes store it as numbers.
- Models lie flat as they would on a tray (Y up), at real size in meters.
