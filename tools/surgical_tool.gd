class_name SurgicalTool
extends RigidBody3D
## Base for every tool that can appear in the tray.
## Each tool is an inherited scene of surgical_tool.tscn that adds its model
## and CollisionShape3D children, and fills in the exports below.

## Append new values at the end only: scenes store these as numbers, so
## reordering or removing a value silently changes existing tools.
enum Speciality { GENERAL, HAND, PLASTIC, SILLY }
## What the tool does: groups the Pocket Guide. Append-only, like Speciality.
enum Category { CUTTING, GRASPING, CLAMPING, RETRACTING, SUTURING, OTHER }

## Every tool scene lives here (subfolders are fine).
const FOLDER := "res://tools/"

## Stable identifier for code and data. Never shown to the player.
@export var id: StringName
@export var display_name: String
## Notable features, shown when explaining a right or wrong pick.
@export_multiline var description: String
@export var specialities: Array[Speciality]
@export var category: Category = Category.OTHER
## Played when the tool lands after being let go (dropped on the tray, or
## flown back to it). The base scene plays one of the metal drop sounds at
## random; give a tool its own to override that.
@export var drop_sound: AudioStream

static var _scenes_by_id: Dictionary[StringName, PackedScene] = {}
static var _ids: Array[StringName] = []
static var _ids_scanned_at := 0


## A new random look (tint, scratches, stains) every time a tool is set up.
func _ready() -> void:
	ToolLook.apply_to_tool(self)


## Scales the tool by factor: model, collision and grab shapes alike. The
## body itself stays unscaled, because physics bodies don't scale well.
func resize(factor: float) -> void:
	for child in get_children():
		if child is Node3D:
			child.scale *= factor
			child.position *= factor


## Bounding box of the tool's visible meshes, in its local space.
## The tool must be inside the scene tree.
func visual_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for node in find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box := global_transform.affine_inverse() * visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## Every tool scene under FOLDER, by id. Scenes whose tool has no id (like the
## base surgical_tool.tscn) are skipped. Scanned once, then cached.
static func scenes_by_id() -> Dictionary[StringName, PackedScene]:
	if _scenes_by_id.is_empty():
		_scan(FOLDER, _scenes_by_id, true)
	return _scenes_by_id


## Every tool id under FOLDER, sorted. Unlike scenes_by_id(), rescanned (at
## most once a second, no errors reported), so the editor sees tools added
## since it started: LevelData's inspector dropdowns use this.
static func ids() -> Array[StringName]:
	if Time.get_ticks_msec() - _ids_scanned_at > 1000 or _ids.is_empty():
		var found: Dictionary[StringName, PackedScene] = {}
		_scan(FOLDER, found, false)
		_ids.assign(found.keys())
		_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		_ids_scanned_at = Time.get_ticks_msec()
	return _ids.duplicate()


static func _scan(folder: String, found: Dictionary[StringName, PackedScene], report_errors: bool) -> void:
	for dir in DirAccess.get_directories_at(folder):
		if not dir.begins_with("."):
			_scan(folder.path_join(dir), found, report_errors)
	for file in DirAccess.get_files_at(folder):
		# Exported builds list scenes as .tscn.remap.
		var path := folder.path_join(file.trim_suffix(".remap"))
		if path.get_extension() != "tscn":
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			if report_errors:
				push_error("Skipping tool scene that failed to load: %s" % path)
			continue
		var id := _id_of(scene)
		if id == &"":
			continue
		if found.has(id) and report_errors:
			push_error("Two tool scenes share the id %s: %s and %s" % [id, found[id].resource_path, path])
		found[id] = scene


## The id a tool scene sets, read from the scene file without making the tool
## (so it also works in the editor). Empty if the scene isn't a SurgicalTool or
## sets no id.
static func _id_of(scene: PackedScene) -> StringName:
	var id := &""
	var is_tool := false
	# An inherited scene stores only what it changes; its base holds the rest.
	var state := scene.get_state()
	while state:
		for i in state.get_node_property_count(0):
			var property := state.get_node_property_name(0, i)
			if property == &"id" and id == &"":
				id = state.get_node_property_value(0, i)
			elif property == &"script" and state.get_node_property_value(0, i) == SurgicalTool:
				is_tool = true
		var base := state.get_node_instance(0)
		state = base.get_state() if base else null
	return id if is_tool else &""
