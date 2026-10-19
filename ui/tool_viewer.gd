class_name ToolViewer
extends ToolPreview
## A ToolPreview you can turn with a finger or the mouse. It spins by itself until touched, and
## starts again resume_seconds after you let go.

@export var drag_sensitivity := 0.01
@export var resume_seconds := 2.0

var _idle := INF


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var motion := event as InputEventMouseMotion
		_pivot.global_rotate(Vector3.UP, motion.relative.x * drag_sensitivity)
		_pivot.global_rotate(Vector3.RIGHT, motion.relative.y * drag_sensitivity)
		_idle = 0.0
		accept_event()


func _process(delta: float) -> void:
	_idle += delta
	if _idle >= resume_seconds:
		super._process(delta)
	else:
		_update_rendering()
