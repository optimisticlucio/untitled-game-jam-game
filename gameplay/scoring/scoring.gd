class_name Scoring
extends Resource
## How a finished run (RunRecord) becomes a score. A level picks one with LevelData.scoring;
## the kinds are TimeScoring and PointScoring, each tuned in its .tres next to this script.
## ScoreBoard does the saving and ranking, so a new kind only overrides these functions.


## Short fixed name the leaderboard files this kind's scores under (scores of different kinds
## don't compare). Changing it loses the saved scores.
func kind() -> String:
	push_error("%s must override Scoring.kind()" % resource_path)
	return ""


func score(_run: RunRecord) -> float:
	push_error("%s must override Scoring.score()" % resource_path)
	return 0.0


func higher_is_better() -> bool:
	return true


func format_score(value: float) -> String:
	return number(value)


## One line for the end-of-level card on how the score is made.
func explanation() -> String:
	return ""


## 15.0 -> "15", 2.5 -> "2.5", for the explanations.
static func number(value: float) -> String:
	return str(int(value)) if value == int(value) else str(value)


## True if score a beats score b.
func is_better(a: float, b: float) -> bool:
	return a > b if higher_is_better() else a < b
