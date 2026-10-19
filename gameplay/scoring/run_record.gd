class_name RunRecord
extends RefCounted
## What happened in one play of a level, for Scoring: every hand-off (right or wrong) with the
## seconds it took, the hints shown, and the clock's total. The level fills it in; the tutorial
## tray isn't recorded.
##
## A hand-off's seconds count from the previous hand-off, but only while the player can pick:
## not while a tray swaps or a correct tool is being taken. The first counts from when the
## requests start.

## The level's clock at the end. Rough: it also runs while trays swap.
var seconds := 0.0
var hints := 0
## One entry per hand-off, in order.
var pick_seconds: Array[float] = []
var pick_right: Array[bool] = []


func add_pick(right: bool, took_seconds: float) -> void:
	pick_right.append(right)
	pick_seconds.append(took_seconds)


func wrong_count() -> int:
	return pick_right.count(false)
