class_name SurgicalTool
extends RigidBody3D
## Base for every tool that can appear in the tray.
## Each tool is an inherited scene of surgical_tool.tscn that adds its model
## and CollisionShape3D children, and fills in the exports below.

## Append new values at the end only: scenes store these as numbers, so
## reordering or removing a value silently changes existing tools.
enum Speciality { GENERAL, HAND, PLASTIC, SILLY }

## Every tool scene lives here (subfolders are fine).
const FOLDER := "res://tools/"

## Stable identifier for code and data. Never shown to the player.
@export var id: StringName
@export var display_name: String
## Notable features, shown when explaining a right or wrong pick.
@export_multiline var description: String
@export var specialities: Array[Speciality]

static var _scenes_by_id: Dictionary[StringName, PackedScene] = {}


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
		_scan(FOLDER)
	return _scenes_by_id


static func _scan(folder: String) -> void:
	for dir in DirAccess.get_directories_at(folder):
		if not dir.begins_with("."):
			_scan(folder.path_join(dir))
	for file in DirAccess.get_files_at(folder):
		# Exported builds list scenes as .tscn.remap.
		var path := folder.path_join(file.trim_suffix(".remap"))
		if path.get_extension() != "tscn":
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("Skipping tool scene that failed to load: %s" % path)
			continue
		var node := scene.instantiate()
		if node is SurgicalTool and node.id != &"":
			if _scenes_by_id.has(node.id):
				push_error("Two tool scenes share the id %s: %s and %s" % [node.id, _scenes_by_id[node.id].resource_path, path])
			_scenes_by_id[node.id] = scene
		node.free()
