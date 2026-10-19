class_name ScoreBoard
extends RefCounted
## Local leaderboard: each player name's best score per level, saved on this device
## (user://scores.cfg), plus sample rivals so a fresh install has something to beat.
## Score = seconds + WRONG_PENALTY per wrong hand-off + HINT_PENALTY per hint shown. Lower is
## better: a mistake costs more than being slow. Names only, no titles: players are any OR staff.
## Levels are keyed by their LevelData id.

const PATH := "user://scores.cfg"
const LEVELS_FOLDER := "res://levels/"
const WRONG_PENALTY := 15.0
const HINT_PENALTY := 5.0
const MAX_NAME_LENGTH := 16
## A rough good run, used to place the sample rivals: PAR_SECONDS_PER_REQUEST per request,
## plus PAR_EXTRA_SECONDS (tray slides and such).
const PAR_SECONDS_PER_REQUEST := 8.0
const PAR_EXTRA_SECONDS := 10.0
## Sample rivals, and their scores as a multiple of the level's par time.
const SAMPLE_NAMES: Array[String] = ["Noa", "Avi", "Maya", "Yoni", "Shira", "Eitan", "Dana", "Omer"]
const SAMPLE_FACTORS: Array[float] = [0.85, 0.95, 1.05, 1.15, 1.3, 1.45, 1.7, 2.0]

## The level the leaderboard screen opens on (set before changing to it).
static var focus_level_key := ""


static func level_key(level: LevelData) -> String:
	return String(level.id)


## "example_level" -> "Example Level".
static func level_title(key: String) -> String:
	return key.capitalize()


static func score(seconds: float, wrong: int, hints: int) -> float:
	return seconds + WRONG_PENALTY * wrong + HINT_PENALTY * hints


## m:ss, e.g. 83.4 -> "1:23".
static func format_time(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]


static func par_seconds(level: LevelData) -> float:
	return PAR_SECONDS_PER_REQUEST * level.requested_ids.size() + PAR_EXTRA_SECONDS


## The name entered last on this device ("" before the first save).
static func last_name() -> String:
	return _load().get_value("player", "name", "")


## Every LevelData in LEVELS_FOLDER, by key, sorted by key.
static func levels() -> Dictionary[String, LevelData]:
	var found: Dictionary[String, LevelData] = {}
	var keys: Array[String] = []
	for file in DirAccess.get_files_at(LEVELS_FOLDER):
		var path := LEVELS_FOLDER.path_join(file.trim_suffix(".remap"))
		if path.get_extension() != "tres":
			continue
		var data := load(path) as LevelData
		if data == null:
			continue
		var key := level_key(data)
		if key.is_empty():
			push_error("Level %s has no id, so it has no leaderboard." % path)
		elif found.has(key):
			push_error("Levels %s and %s share the id %s." % [found[key].resource_path, path, key])
		else:
			keys.append(key)
			found[key] = data
	keys.sort()
	var sorted: Dictionary[String, LevelData] = {}
	for key in keys:
		sorted[key] = found[key]
	return sorted


## Saves a run under name; each name keeps only its best per level. Returns this run's
## {score, rank, count, new_best}: rank among everyone on the board, sample rivals included.
static func submit(level: LevelData, name: String, seconds: float, wrong: int, hints: int) -> Dictionary:
	name = name.strip_edges().left(MAX_NAME_LENGTH)
	if name.is_empty():
		name = "You"
	var key := level_key(level)
	var this_score := score(seconds, wrong, hints)
	var cfg := _load()
	cfg.set_value("player", "name", name)
	var runs: Dictionary = cfg.get_value("levels", key, {})
	var previous: Dictionary = runs.get(name, {})
	var new_best := previous.is_empty() or this_score < float(previous["score"])
	if new_best:
		runs[name] = {"score": this_score, "seconds": seconds, "wrong": wrong, "hints": hints,
			"date": Time.get_date_string_from_system()}
		cfg.set_value("levels", key, runs)
	cfg.save(PATH)
	var table := entries(level)
	var ahead := table.filter(func(e: Dictionary) -> bool: return e["score"] < this_score).size()
	return {"score": this_score, "rank": ahead + 1,
		"count": table.size() if new_best else table.size() + 1, "new_best": new_best}


## The board for a level, best first: {name, score, seconds, wrong, hints, sample}.
static func entries(level: LevelData) -> Array[Dictionary]:
	var key := level_key(level)
	var rows: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var par := par_seconds(level)
	for i in SAMPLE_NAMES.size():
		var seconds := par * SAMPLE_FACTORS[i] * rng.randf_range(0.95, 1.05)
		var wrong := rng.randi_range(0, 1 + i / 3)
		var hints := rng.randi_range(0, i / 4)
		rows.append({"name": SAMPLE_NAMES[i], "score": score(seconds, wrong, hints), "seconds": seconds,
			"wrong": wrong, "hints": hints, "sample": true})
	var runs: Dictionary = _load().get_value("levels", key, {})
	for name in runs:
		var run: Dictionary = runs[name]
		rows.append({"name": name, "score": float(run["score"]), "seconds": float(run["seconds"]),
			"wrong": int(run["wrong"]), "hints": int(run["hints"]), "sample": false})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	return rows


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # A missing file just gives an empty board.
	return cfg
