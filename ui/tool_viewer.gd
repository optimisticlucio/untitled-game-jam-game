class_name ToolViewer
extends ToolPreview
## A ToolPreview you can turn with a finger or the mouse. It spins by itself until touched, and
## starts again resume_seconds after you let go. reset_view() turns it back to how it started.

@export var drag_sensitivity := 0.01
@export var resume_seconds := 2.0
@export var reset_seconds := 0.35

var _idle := INF
var _reset_tween: Tween


## Every tool opens the right way up, whatever the last one was turned to.
func show_tool(scene: PackedScene) -> void:
	if not is_node_ready():
		await ready
	if _reset_tween:
		_reset_tween.kill()
	_pivot.quaternion = Quaternion.IDENTITY
	_idle = INF
	super.show_tool(scene)


## Turns the tool smoothly back to how it started; it rests a moment, then spins again.
func reset_view() -> void:
	if _reset_tween:
		_reset_tween.kill()
	_idle = 0.0
	_reset_tween = create_tween()
	_reset_tween.tween_property(_pivot, "quaternion", Quaternion.IDENTITY, reset_seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var motion := event as InputEventMouseMotion
		_pivot.global_rotate(Vector3.UP, motion.relative.x * drag_sensitivity)
		_pivot.global_rotate(Vector3.RIGHT, motion.relative.y * drag_sensitivity)
		if _reset_tween:
			_reset_tween.kill()
		_idle = 0.0
		accept_event()


func _process(delta: float) -> void:
	_idle += delta
	if _idle >= resume_seconds:
		super._process(delta)
	else:
		_update_rendering()
