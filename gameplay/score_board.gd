class_name ScoreBoard
extends RefCounted
## Local leaderboard: each player name's best score per level, saved on this device
## (user://scores.cfg), plus sample rivals so a fresh install has something to beat.
## How a run is scored is up to the level's Scoring (LevelData.scoring); this only saves and
## ranks. A level has one board per scoring kind, so switching its scoring starts a fresh board
## and keeps the old one for switching back. Names only, no titles: players are any OR staff.
## Levels are keyed by their LevelData id.

const PATH := "user://scores.cfg"
## For levels that don't set LevelData.scoring.
const DEFAULT_SCORING := preload("res://gameplay/scoring/points.tres")
const MAX_NAME_LENGTH := 16
## Sample rivals take about PAR_SECONDS_PER_PICK times their factor per hand-off (lower is
## faster), and the clock adds PAR_EXTRA_SECONDS (tray slides and such).
const PAR_SECONDS_PER_PICK := 8.0
const PAR_EXTRA_SECONDS := 10.0
const SAMPLE_NAMES: Array[String] = ["Noa", "Avi", "Maya", "Yoni", "Shira", "Eitan", "Dana", "Omer"]
const SAMPLE_FACTORS: Array[float] = [0.85, 0.95, 1.05, 1.15, 1.3, 1.45, 1.7, 2.0]

## The level the leaderboard screen opens on (set before changing to it).
static var focus_level_key := ""


static func level_key(level: LevelData) -> String:
	return String(level.id)


static func scoring_for(level: LevelData) -> Scoring:
	return level.scoring if level.scoring else DEFAULT_SCORING


## m:ss, e.g. 83.4 -> "1:23".
static func format_time(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]


## The name entered last on this device ("" before the first save).
static func last_name() -> String:
	return _load().get_value("player", "name", "")


## name's saved best on the level ({score, seconds, wrong, hints, date}), or {} if none.
static func best(level: LevelData, name: String) -> Dictionary:
	var runs: Dictionary = _load().get_value(_section(scoring_for(level)), level_key(level), {})
	return runs.get(name, {})


## Saves a run under name; each name keeps only its best per level. Returns this run's
## {score, rank, count, new_best}: rank among everyone on the board, sample rivals included.
static func submit(level: LevelData, name: String, run: RunRecord) -> Dictionary:
	name = name.strip_edges().left(MAX_NAME_LENGTH)
	if name.is_empty():
		name = "You"
	var scoring := scoring_for(level)
	var section := _section(scoring)
	var key := level_key(level)
	var this_score := scoring.score(run)
	var cfg := _load()
	cfg.set_value("player", "name", name)
	var runs: Dictionary = cfg.get_value(section, key, {})
	var previous: Dictionary = runs.get(name, {})
	var new_best := previous.is_empty() or scoring.is_better(this_score, float(previous["score"]))
	if new_best:
		runs[name] = {"score": this_score, "seconds": run.seconds, "wrong": run.wrong_count(),
			"hints": run.hints, "date": Time.get_date_string_from_system()}
		cfg.set_value(section, key, runs)
	cfg.save(PATH)
	var table := entries(level)
	var ahead := table.filter(func(e: Dictionary) -> bool: return scoring.is_better(e["score"], this_score)).size()
	return {"score": this_score, "rank": ahead + 1,
		"count": table.size() if new_best else table.size() + 1, "new_best": new_best}


## The board for a level, best first: {name, score, seconds, wrong, hints, sample}.
static func entries(level: LevelData) -> Array[Dictionary]:
	var scoring := scoring_for(level)
	var key := level_key(level)
	var rows: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for i in SAMPLE_NAMES.size():
		rows.append(_sample_row(level, scoring, i, rng))
	var runs: Dictionary = _load().get_value(_section(scoring), key, {})
	for name in runs:
		var run: Dictionary = runs[name]
		rows.append({"name": name, "score": float(run["score"]), "seconds": float(run["seconds"]),
			"wrong": int(run["wrong"]), "hints": int(run["hints"]), "sample": false})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return scoring.is_better(a["score"], b["score"]))
	return rows


## Sample rival number i: a made-up run, scored by the level's own scoring. The slower rivals
## (further down SAMPLE_FACTORS) also make more mistakes and see more hints.
static func _sample_row(level: LevelData, scoring: Scoring, i: int, rng: RandomNumberGenerator) -> Dictionary:
	var run := RunRecord.new()
	var wrong := rng.randi_range(0, 1 + i / 3)
	var total := 0.0
	for pick in wrong + level.request_count():
		var took := PAR_SECONDS_PER_PICK * SAMPLE_FACTORS[i] * rng.randf_range(0.8, 1.2)
		run.add_pick(pick >= wrong, took)
		total += took
	run.seconds = total + PAR_EXTRA_SECONDS
	run.hints = rng.randi_range(0, i / 4)
	return {"name": SAMPLE_NAMES[i], "score": scoring.score(run), "seconds": run.seconds,
		"wrong": wrong, "hints": run.hints, "sample": true}


## Each scoring kind keeps its own boards.
static func _section(scoring: Scoring) -> String:
	return "scores_" + scoring.kind()


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # A missing file just gives an empty board.
	return cfg
