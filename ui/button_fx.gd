class_name ButtonFx
## Extras for every Button with text and an icon, installed once by the main menu (the game
## always starts there): the text starts right after the icon, so every label lines up (centred, a
## long label would run into the icon), and the icon makes a small hop when the pointer enters the
## button.

const HOP_HEIGHT := 8.0
const HOP_UP_SECONDS := 0.11
const HOP_DOWN_SECONDS := 0.32
## A pointer resting on a button's edge can leave and enter again at once: no new hop this soon.
const HOP_REST_MSEC := 700


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
	button.mouse_entered.connect(_hop.bind(button, icon))


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


static func _hop(button: Button, icon: TextureRect) -> void:
	if button.disabled or not is_instance_valid(icon):
		return
	var now := Time.get_ticks_msec()
	if now - int(icon.get_meta(&"hopped_at", -HOP_REST_MSEC)) < HOP_REST_MSEC:
		return
	icon.set_meta(&"hopped_at", now)
	var rest := icon.position.y
	var tween := icon.create_tween()
	tween.tween_property(icon, "position:y", rest - HOP_HEIGHT, HOP_UP_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "position:y", rest, HOP_DOWN_SECONDS) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
