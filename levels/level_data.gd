class_name LevelData
extends Resource
## One level's settings. Make one .tres per level and give it to level.tscn.
## Tools are referred to by their SurgicalTool id. Unknown ids are reported
## when the level starts.

## What the doctor asks for. Repeats are fine. Asked in a random order each play.
@export var requested_ids: Array[StringName] = []
## Put in the tray but never asked for. Repeats are fine.
@export var distractor_ids: Array[StringName] = []
## Size of every tool on the tray, as a percentage of real size (the request
## picture always shows real size). Bigger fills a sparse tray, smaller eases
## a crowded one. All tools change together, so their sizes stay comparable.
@export_range(70.0, 150.0, 5.0, "suffix:%") var tool_size_percent := 100.0

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


## Every problem that would stop this level from starting, as readable lines.
func problems(known_ids: Array[StringName]) -> PackedStringArray:
	var found := PackedStringArray()
	if requested_ids.is_empty():
		found.append("Requests nothing.")
	for list_name in ["requested_ids", "distractor_ids", "name_only_ids"]:
		for id: StringName in get(list_name):
			if not known_ids.has(id):
				found.append("%s: no tool has the id \"%s\"." % [list_name, id])
	return found


## The requests split into trays, each in play order. Shuffled on every call.
func plan_trays() -> Array[Array]:
	var requests := requested_ids.duplicate()
	requests.shuffle()
	var trays: Array[Array] = []
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
