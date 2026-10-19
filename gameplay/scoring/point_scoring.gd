class_name PointScoring
extends Scoring
## Points per hand-off: flat_points, plus a time bonus of up to bonus_points. The bonus is whole
## up to bonus_full_seconds, shrinks steadily after that, and is gone at bonus_zero_seconds
## (how a hand-off's seconds are counted: RunRecord). A wrong hand-off is worth the same amount
## times wrong_multiplier: at -1 it takes away what a right one would have given. Hints don't
## change the score. Higher is better.

@export var flat_points := 100.0
@export var bonus_points := 100.0
@export var bonus_full_seconds := 3.0
@export var bonus_zero_seconds := 12.0
@export var wrong_multiplier := -1.0


func kind() -> String:
	return "points"


func score(run: RunRecord) -> float:
	var total := 0.0
	for i in run.pick_right.size():
		total += pick_points(run.pick_right[i], run.pick_seconds[i])
	return total


func pick_points(right: bool, took_seconds: float) -> float:
	var points := flat_points + time_bonus(took_seconds)
	return points if right else points * wrong_multiplier


func time_bonus(took_seconds: float) -> float:
	if took_seconds <= bonus_full_seconds:
		return bonus_points
	if took_seconds >= bonus_zero_seconds:
		return 0.0
	return bonus_points * (bonus_zero_seconds - took_seconds) / (bonus_zero_seconds - bonus_full_seconds)


func format_score(value: float) -> String:
	return tr("%d pts") % roundi(value)


func explanation() -> String:
	var wrong := tr("But every wrong guess takes away the same amount of points, so play it safe.") if wrong_multiplier == -1.0 \
		else tr("But every wrong guess takes away %s times as many points, so play it safe.") % number(absf(wrong_multiplier))
	return tr("Every right guess gives %s points, plus some bonus points for speed!") % number(flat_points) \
		+ " " + wrong
