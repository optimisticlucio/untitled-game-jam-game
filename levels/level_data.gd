@tool
class_name LevelData
extends Resource
## One level's settings. Make one .tres per level and add it to levels/levels.tres (LevelList).
## Tools are referred to by their SurgicalTool id, picked from a dropdown of
## every tool in the inspector. Unknown ids (a tool renamed or removed since)
## are reported when the level starts.

## The properties that list tool ids.
const TOOL_LISTS: Array[StringName] = [&"requested_ids", &"distractor_ids", &"tutorial_ids", &"name_only_ids"]

## Names the level for good: the leaderboard saves scores under it, so changing
## it loses them. The file name doesn't matter.
@export var id: StringName
## Shown in the level selector and the leaderboard, through tr(). Empty = the id in words.
@export var title := ""
## How runs are scored (gameplay/scoring/: points.tres or time.tres, tuned there). Empty =
## ScoreBoard.DEFAULT_SCORING. Switching starts a fresh leaderboard for the level; the old one
## comes back if you switch back.
@export var scoring: Scoring
## What the doctor asks for. Repeats are fine. Asked in a random order each play.
@export var requested_ids: Array[StringName] = []
## Put in the tray but never asked for. Repeats are fine.
@export var distractor_ids: Array[StringName] = []
## Size of every tool on the tray, as a percentage of real size (the request
## picture always shows real size). Bigger fills a sparse tray, smaller eases
## a crowded one. All tools change together, so their sizes stay comparable.
@export_range(70.0, 150.0, 5.0, "suffix:%") var tool_size_percent := 100.0

@export_group("Tutorial")
## If any are listed, the level opens with a tutorial tray holding only these
## (no distractors), asked for in a random order, before the clock starts.
## Separate from requested_ids. Repeats are fine.
@export var tutorial_ids: Array[StringName] = []

@export_group("Reshuffle")
## Correct hand-offs per tray: then the tray leaves and comes back with the
## next requests and fresh distractors. Each tray holds exactly the requests
## it will be asked for (the last one whatever is left). 0 = never reshuffle.
@export var reshuffle_after := 0
## Distractors per tray, drawn at random from distractor_ids. Negative = all of them.
@export var distractors_per_tray := -1

@export_group("Hints")
## Requests for these tools show only the name, without the picture.
@export var name_only_ids: Array[StringName] = []
## Seconds into a request before one copy of the requested tool glows. 0 or less = never.
@export var hint_delay_seconds := 0.0
## The hint also waits until this many seconds after the player last let go of
## a tool, and never starts while they're holding one. 0 = no extra wait.
@export var hint_idle_seconds := 0.0
## How long the hint glows. Then it goes out and hint_delay_seconds starts
## over. 0 or less = it stays on until the request changes.
@export var hint_duration_seconds := 2.0


## Each entry of a tool list gets a dropdown of every tool id in the inspector.
## Still saved as the id, so adding or removing other tools never changes a level.
func _validate_property(property: Dictionary) -> void:
	if property.name in TOOL_LISTS:
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = "%d/%d:%s" % [TYPE_STRING_NAME, PROPERTY_HINT_ENUM, ",".join(SurgicalTool.ids())]


## Every problem that would stop this level from starting, as readable lines.
func problems(known_ids: Array[StringName]) -> PackedStringArray:
	var found := PackedStringArray()
	if id == &"":
		found.append("Has no id.")
	if requested_ids.is_empty():
		found.append("Requests nothing.")
	for list_name in TOOL_LISTS:
		for id: StringName in get(list_name):
			if not known_ids.has(id):
				found.append("%s: no tool has the id \"%s\"." % [list_name, id])
	return found


## title, or the id in words ("example_level" -> "Example Level").
func display_title() -> String:
	return tr(title) if not title.is_empty() else String(id).capitalize()


func has_tutorial() -> bool:
	return not tutorial_ids.is_empty()


## The requests split into trays, each in play order, the tutorial tray (if
## any) first. Shuffled on every call.
func plan_trays() -> Array[Array]:
	var trays: Array[Array] = []
	if has_tutorial():
		var tutorial := tutorial_ids.duplicate()
		tutorial.shuffle()
		trays.append(tutorial)
	var requests := requested_ids.duplicate()
	requests.shuffle()
	if reshuffle_after <= 0:
		trays.append(requests)
		return trays
	for start in range(0, requests.size(), reshuffle_after):
		trays.append(requests.slice(start, start + reshuffle_after))
	return trays


## A fresh random draw of distractors for one tray.
func draw_distractors() -> Array[StringName]:
	var pool := distractor_ids.duplicate()
	pool.shuffle()
	if distractors_per_tray >= 0:
		pool = pool.slice(0, distractors_per_tray)
	return pool
