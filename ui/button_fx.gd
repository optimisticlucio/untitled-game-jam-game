class_name ButtonFx
## Extras for every Button with text and an icon, installed once by the main menu (the game
## always starts there): the text starts right after the icon, so every label lines up (centred, a
## long label would run into the icon), and the icon moves a little when the pointer enters the
## button. Which move: the button's "icon_motion" metadata (set in its scene), hop if it has none:
##   hop    a small jump that lands with a bounce
##   spin   one smooth turn (the gear)
##   sway   rocks on its base like a trophy just won
##   nudge  a step to the right and back (Play)
##   open   widens and settles, like a book opening

const HOP_HEIGHT := 8.0
const SPIN_SECONDS := 0.9
const SWAY_DEGREES := 12.0
const NUDGE_PIXELS := 7.0
const OPEN_SCALE := 1.14
## A pointer resting on a button's edge can leave and enter again at once: no new move this soon.
const REST_MSEC := 700


static func install(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	for node in tree.root.find_children("*", "Button", true, false):
		_on_node_added(node)


static func _on_node_added(node: Node) -> void:
	var button := node as Button
	if button == null or button.has_meta(&"button_fx"):
		return
	button.set_meta(&"button_fx", true)
	# After the button has finished entering the tree (its theme and children are in place).
	_set_up.call_deferred(button)


static func _set_up(button: Button) -> void:
	if not is_instance_valid(button) or button.icon == null or button.text.is_empty():
		return
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var icon := _detach_icon(button)
	var motion: StringName = button.get_meta(&"icon_motion", &"hop")
	button.mouse_entered.connect(_move.bind(button, icon, motion))


## The real icon becomes a child the hop can move. The button keeps an invisible stand-in of the
## same size, so it still lays its text out after the icon.
static func _detach_icon(button: Button) -> TextureRect:
	var style := button.get_theme_stylebox(&"normal")
	var size := button.icon.get_size()
	var width := minf(size.x, button.get_theme_constant(&"icon_max_width"))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = button.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.anchor_bottom = 1.0
	icon.offset_left = style.content_margin_left if style else 0.0
	icon.offset_right = icon.offset_left + width
	icon.offset_top = style.content_margin_top if style else 0.0
	icon.offset_bottom = -(style.content_margin_bottom if style else 0.0)
	var stand_in := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	stand_in.set_size_override(Vector2i(size))
	button.icon = stand_in
	button.add_child(icon)
	return icon


static func _move(button: Button, icon: TextureRect, motion: StringName) -> void:
	if button.disabled or not is_instance_valid(icon):
		return
	var now := Time.get_ticks_msec()
	if now - int(icon.get_meta(&"moved_at", -REST_MSEC)) < REST_MSEC:
		return
	icon.set_meta(&"moved_at", now)
	var tween := icon.create_tween()
	match motion:
		&"spin":
			icon.pivot_offset = icon.size / 2.0
			tween.tween_property(icon, "rotation", TAU, SPIN_SECONDS).from(0.0) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(func() -> void: icon.rotation = 0.0)
		&"sway":
			icon.pivot_offset = Vector2(icon.size.x / 2.0, _drawn_bottom(icon))
			var a := deg_to_rad(SWAY_DEGREES)
			for step: Vector2 in [Vector2(a, 0.12), Vector2(-a * 0.8, 0.18), Vector2(a * 0.5, 0.16),
					Vector2(-a * 0.25, 0.14), Vector2(0.0, 0.12)]:
				tween.tween_property(icon, "rotation", step.x, step.y).set_trans(Tween.TRANS_SINE)
		&"nudge":
			var rest := icon.position.x
			tween.tween_property(icon, "position:x", rest + NUDGE_PIXELS, 0.14) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "position:x", rest - NUDGE_PIXELS * 0.25, 0.14) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(icon, "position:x", rest, 0.14).set_trans(Tween.TRANS_SINE)
		&"open":
			icon.pivot_offset = icon.size / 2.0
			tween.tween_property(icon, "scale:x", OPEN_SCALE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "scale:x", 1.0, 0.36).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_:
			var rest := icon.position.y
			tween.tween_property(icon, "position:y", rest - HOP_HEIGHT, 0.11) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "position:y", rest, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Where the bottom of the drawn picture is inside the icon's rect (it's centred, keeping its shape).
static func _drawn_bottom(icon: TextureRect) -> float:
	var tex := icon.texture.get_size()
	var drawn := tex.y * minf(icon.size.x / tex.x, icon.size.y / tex.y)
	return (icon.size.y + drawn) / 2.0
