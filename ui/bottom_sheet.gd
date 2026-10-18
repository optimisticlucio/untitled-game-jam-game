class_name BottomSheet
extends PanelContainer
## A panel anchored to the bottom edge (anchor it bottom-wide) that slides up into view and back
## down, sized to its content. Used by the HUD's pause sheet and the main menu's settings.

@export var slide_seconds := 0.25

var is_open := false
var _tween: Tween


func _ready() -> void:
	hide()


func toggle() -> void:
	set_open(not is_open)


func set_open(open: bool) -> void:
	is_open = open
	get_node(^"/root/UiSounds/Slide").play()
	if _tween:
		_tween.kill()
	show()
	var height := get_combined_minimum_size().y
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_parallel()
	_tween.tween_property(self, "offset_top", -height if open else 0.0, slide_seconds)
	_tween.tween_property(self, "offset_bottom", 0.0 if open else height, slide_seconds)
	if not open:
		_tween.chain().tween_callback(hide)


## Re-fits an open sheet after its content changed size.
func refit() -> void:
	if is_open:
		set_open(true)
