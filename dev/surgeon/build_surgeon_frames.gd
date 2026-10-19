extends SceneTree
## Builds the surgeon's SpriteFrames from Julia's sheets. Never edit them by hand.
##   assets/surgeon/surgeon_frames.tres        everything but the fingers (the Surgeon's Sprite)
##   assets/surgeon/surgeon_front_frames.tres  the fingers only, drawn over a tool on his hand (Front)
## Inputs, per layer: assets/surgeon/<layer>_<anim>.png (a long animation goes on: _2, _3, ...)
## and <layer>_frames.json (frame size, crop, cell size, columns and rows per sheet; per animation
## frame count, sheets, fps, loop, hand point per frame). Julia's Spine 4.3 frame export (~/Desktop/spine-practice/surgeon/export/
## frames_<fps>fps_<version>_back and _front, with anchors.json) becomes those sheets with:
##   python3 dev/surgeon/pack_surgeon.py <export>_back assets/surgeon surgeon
##   python3 dev/surgeon/pack_surgeon.py <export>_front assets/surgeon surgeon_front
## Then run: Godot --headless --path <repo> --script res://dev/surgeon/build_surgeon_frames.gd
## The level places him for a 485 x 483 frame; a new frame size needs Surgeon and Target moved.

const FOLDER := "res://assets/surgeon/"


func _init() -> void:
	var error := OK
	for layer in ["surgeon", "surgeon_front"]:
		error = maxi(error, _build(layer))
	quit(error)


func _build(layer: String) -> Error:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + layer + "_frames.json"))
	var frame_size := Vector2(meta.frame_size[0], meta.frame_size[1])
	# The sheets hold only the box that anything is drawn in; the margin puts it back in place.
	var crop := Rect2(meta.crop[0], meta.crop[1], meta.crop[2], meta.crop[3])
	var cell := Vector2(meta.cell_size[0], meta.cell_size[1])
	var columns: int = meta.columns
	var per_sheet: int = columns * int(meta.rows)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# Where his hand is in every frame (frame px, y down), so a tool can ride on it: Surgeon.hand_point().
	var hands := {}
	for anim_name: String in meta.animations:
		var anim: Dictionary = meta.animations[anim_name]
		var points := PackedVector2Array()
		for point: Array in anim.hand:
			points.append(Vector2(point[0], point[1]))
		hands[StringName(anim_name)] = points
		var sheets: Array[Texture2D] = []
		for p in int(anim.pages):
			sheets.append(load(FOLDER + "%s_%s%s.png" % [layer, anim_name, "" if p == 0 else "_%d" % (p + 1)]))
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, anim.fps)
		frames.set_animation_loop(anim_name, anim.loop)
		for i in int(anim.frames):
			var frame := AtlasTexture.new()
			frame.atlas = sheets[i / per_sheet]
			var cell_index := i % per_sheet
			frame.region = Rect2(Vector2(cell_index % columns, cell_index / columns) * cell, crop.size)
			frame.margin = Rect2(crop.position, frame_size - crop.size)
			frames.add_frame(anim_name, frame)
	frames.set_meta(&"hands", hands)
	var error := ResourceSaver.save(frames, FOLDER + layer + "_frames.tres")
	print("build_surgeon_frames: ", layer, " ", error_string(error), " ", frames.get_animation_names())
	return error
