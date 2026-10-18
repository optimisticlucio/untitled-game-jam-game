class_name ToolLook
## The look of the tools and the tray: the toon shaders in assets/shaders (Julia tunes them in her
## browser shader lab; the shader defaults are her values). Every tool gets a new random look each
## time it's set up, and the tray's blood moves for every new tray, so a tool can never be
## recognised by a tint, a scratch or a stain, only by its shape.

const TOOL_SHADER := preload("res://assets/shaders/tool_toon.gdshader")
const TRAY_SHADER := preload("res://assets/shaders/tray.gdshader")
## R = scratches, G = stains, B = soft hue patches. Tiles.
const WEAR := preload("res://assets/shaders/wear.png")
## A soft field of blood splats, spread evenly. Tiles.
const BLOOD := preload("res://assets/shaders/blood.png")

## How far a tool's hue can drift from plain steel (0 = all the same).
const TINT_STRENGTH := 0.22
## Share of tools that get scratches / stains, and how strong they can be.
const SCRATCH_CHANCE := 0.6
const SCRATCH_STRENGTH := 0.45
const STAIN_CHANCE := 0.5
const STAIN_STRENGTH := 0.35


## Gives the tool's meshes the tool shader with a new random look. Meshes without an albedo
## texture keep their own material.
static func apply_to_tool(tool: Node3D) -> void:
	var hue := Color.from_hsv(randf(), 0.5, 1.0)
	var look := {
		"tint": Color.WHITE.lerp(hue, TINT_STRENGTH * randf_range(0.3, 1.0)),
		"wear_offset": Vector2(randf(), randf()),
		"wear_angle": randf() * TAU,
		"patch_offset": Vector2(randf(), randf()),
		"scratch_amount": SCRATCH_STRENGTH * randf_range(0.5, 1.0) if randf() < SCRATCH_CHANCE else 0.0,
		"stain_amount": STAIN_STRENGTH * randf_range(0.5, 1.0) if randf() < STAIN_CHANCE else 0.0,
	}
	for node in tool.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var textures := _textures(mesh_instance.get_active_material(surface))
			if textures[0] == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = TOOL_SHADER
			material.set_shader_parameter("albedo_tex", textures[0])
			material.set_shader_parameter("orm_tex", textures[1])
			material.set_shader_parameter("wear_tex", WEAR)
			for key in look:
				material.set_shader_parameter(key, look[key])
			mesh_instance.set_surface_override_material(surface, material)


## Gives the tray model the tray shader (silver with a turquoise cloth, plastic blood).
static func apply_to_tray(tray_model: Node3D) -> void:
	for mesh_instance in _meshes(tray_model):
		var bounds := mesh_instance.mesh.get_aabb()
		for surface in mesh_instance.mesh.get_surface_count():
			var material := ShaderMaterial.new()
			material.shader = TRAY_SHADER
			material.set_shader_parameter("blood_tex", BLOOD)
			# The blood is mapped over the floor from the mesh's own bounds.
			material.set_shader_parameter("tray_min", bounds.position)
			material.set_shader_parameter("tray_size", bounds.size)
			mesh_instance.set_surface_override_material(surface, material)
	reshuffle_tray(tray_model)


## Moves the blood to new places (the texture tiles, so any offset works).
static func reshuffle_tray(tray_model: Node3D) -> void:
	var offset := Vector2(randf(), randf())
	for mesh_instance in _meshes(tray_model):
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_surface_override_material(surface) as ShaderMaterial
			if material and material.shader == TRAY_SHADER:
				material.set_shader_parameter("blood_offset", offset)


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).mesh:
			result.append(node)
	return result


## [albedo, orm] from an imported glTF material. The importer may keep ORM as an ORMMaterial3D,
## or split it into roughness/metallic textures that point at the same image.
static func _textures(material: Material) -> Array[Texture2D]:
	if material is ORMMaterial3D:
		var orm := material as ORMMaterial3D
		return [orm.albedo_texture, orm.orm_texture]
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		return [standard.albedo_texture, standard.roughness_texture if standard.roughness_texture else standard.metallic_texture]
	return [null, null]
