extends Control
## Shows tools in the team's ToolPreview (ui/tool_preview.tscn) in a grid and, if SNAPSHOT is set,
## saves one frame there and quits. Run WITHOUT --headless:
## SNAPSHOT=/abs/path.png Godot --path <repo> res://dev/instruments/tests/preview_check.tscn

const SLUGS := ["scalpel_10", "scalpel_11", "scalpel_15", "kelly_clamp", "crile_clamp", "mayo_hegar",
	"mayo_scissors", "adson_forceps", "micro_needle_holder", "vannas_scissors", "acland_clamp"]

var frames := 0


func _ready() -> void:
	var grid := GridContainer.new()
	grid.columns = 6
	add_child(grid)
	for slug in SLUGS:
		var p := (load("res://ui/tool_preview.tscn") as PackedScene).instantiate() as ToolPreview
		p.custom_minimum_size = Vector2(200, 200)
		grid.add_child(p)
		p.show_tool(load("res://tools/%s.tscn" % slug))


func _process(_delta: float) -> void:
	frames += 1
	if frames == 40 and OS.has_environment("SNAPSHOT"):
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SNAPSHOT"))
		get_tree().quit()
