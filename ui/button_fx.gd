class_name ButtonFx
## Extras for every Button in the game, installed once by the main menu (the game always starts
## there): a soft glare that sweeps across a button when the pointer enters it, and text that
## starts right after the icon on buttons that have both, so every label lines up at the same
## place (centred, a long label would run into the icon).

const GLARE := preload("res://ui/button_glare.gdshader")
const GLARE_SECONDS := 0.55


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
	if not is_instance_valid(button):
		return
	if button.icon and not button.text.is_empty():
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var material := ShaderMaterial.new()
	material.shader = GLARE
	button.material = material
	button.mouse_entered.connect(_glare.bind(button))


static func _glare(button: Button) -> void:
	if button.disabled or not button.material is ShaderMaterial:
		return
	# One sweep at a time: the pointer can enter again before the last one is done.
	var running: Tween = button.get_meta(&"glare_tween", null)
	if running and running.is_running():
		return
	var material := button.material as ShaderMaterial
	material.set_shader_parameter(&"size", button.size)
	var tween := button.create_tween()
	button.set_meta(&"glare_tween", tween)
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter(&"sweep", v), 0.0, 1.0, GLARE_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: material.set_shader_parameter(&"sweep", -1.0))
