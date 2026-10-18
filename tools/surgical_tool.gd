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
