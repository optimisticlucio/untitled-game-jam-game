extends SceneTree
## Builds assets/surgeon/surgeon_frames.tres (SpriteFrames) from Julia's surgeon sheets. Never edit it by hand.
## Inputs: assets/surgeon/surgeon_<anim>.png, one sheet per animation, and surgeon_frames.json (cell
## size, columns, fps, frame count, loop, hand point per frame). Julia's Spine 4.3 frame export
## (~/Desktop/spine-practice/surgeon/export/frames_<fps>fps_<version>, with anchors.json) becomes those
## sheets with:  python3 dev/surgeon/pack_surgeon.py <export folder> assets/surgeon
## Then run: Godot --headless --path <repo> --script res://dev/surgeon/build_surgeon_frames.gd
## The level places him for a 485 x 483 frame; a new frame size needs Surgeon and Target moved.

const FOLDER := "res://assets/surgeon/"


func _init() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "surgeon_frames.json"))
	var frame_size := Vector2(meta.frame_size[0], meta.frame_size[1])
	var cell := Vector2(meta.cell_size[0], meta.cell_size[1])
	var columns: int = meta.columns
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
		var sheet: Texture2D = load(FOLDER + "surgeon_%s.png" % anim_name)
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, meta.fps)
		frames.set_animation_loop(anim_name, anim.loop)
		for i in int(anim.frames):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(i % columns, i / columns) * cell, frame_size)
			frames.add_frame(anim_name, frame)
	frames.set_meta(&"hands", hands)
	var error := ResourceSaver.save(frames, FOLDER + "surgeon_frames.tres")
	print("build_surgeon_frames: ", error_string(error), " ", frames.get_animation_names())
	quit(error)
