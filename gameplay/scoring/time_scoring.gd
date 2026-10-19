class_name TimeScoring
extends Scoring
## Score = the clock's time, plus a penalty in seconds per wrong hand-off and per hint.
## Lower is better.

@export var wrong_penalty_seconds := 15.0
@export var hint_penalty_seconds := 5.0


func kind() -> String:
	return "time"


func score(run: RunRecord) -> float:
	return run.seconds + wrong_penalty_seconds * run.wrong_count() + hint_penalty_seconds * run.hints


func higher_is_better() -> bool:
	return false


func format_score(value: float) -> String:
	return ScoreBoard.format_time(value)


func explanation() -> String:
	return tr("Time, plus %s s per wrong tool and %s s per hint. Lower is better.") % [
		number(wrong_penalty_seconds), number(hint_penalty_seconds)]
