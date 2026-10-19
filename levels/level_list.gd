class_name LevelList
extends Resource
## Every level the player can pick, in the order the level selector and the leaderboard show
## them. The one list is levels/levels.tres: a new level goes in levels/ and must be added there.

const PATH := "res://levels/levels.tres"

@export var levels: Array[LevelData] = []

## The level levels/level.tscn plays next, set by the level selector. Null: the scene plays its
## own `level`, so it still runs straight from the editor.
static var chosen: LevelData


## The levels in levels.tres, in order. Empty slots, and levels with no id or a repeated id
## (the leaderboard files scores by id), are left out with an error.
static func all() -> Array[LevelData]:
	var result: Array[LevelData] = []
	var list := load(PATH) as LevelList
	if list == null:
		push_error("%s is missing or isn't a LevelList." % PATH)
		return result
	var seen: Dictionary[StringName, LevelData] = {}
	for level in list.levels:
		if level == null:
			push_error("%s has an empty slot." % PATH)
		elif level.id == &"":
			push_error("Level %s has no id." % level.resource_path)
		elif seen.has(level.id):
			push_error("Levels %s and %s share the id %s." % [seen[level.id].resource_path, level.resource_path, level.id])
		else:
			seen[level.id] = level
			result.append(level)
	return result
