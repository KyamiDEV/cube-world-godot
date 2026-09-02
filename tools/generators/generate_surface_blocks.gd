extends SceneTree
## One-off content generator for the two block kinds brick 075 needs and 038 did not add
## (backlog brick 075).
##
## Usage:
##   godot --headless --script res://tools/generators/generate_surface_blocks.gd
##
## `SurfaceMaterial` (`world/generation/surface_material.gd`) maps all six biomes onto
## block kinds; four of them (grassland, forest, mountain, wetland) reuse the grass/dirt/
## stone set brick 038 already wrote. Desert and snow have no honest stand-in among those
## three, so this writes the two block kinds that are actually new: `block.sand` and
## `block.snow`. Same speckled-placeholder-PNG technique as `generate_block_set.gd`, in a
## separate file rather than folded into that one so 038's "first three blocks" generator
## keeps meaning exactly what its own header says it means.
##
## Additive, not a replacement: re-running writes only these two files and never touches
## `data/blocks/grass.tres`, `dirt.tres` or `stone.tres`.

const TILE_SIZE := 16
const NOISE_AMPLITUDE := 12  # max +/- per channel

const TEXTURES_DIR := "res://assets/textures/blocks/"
const DATA_DIR := "res://data/blocks/"

const _SAND := Color8(219, 199, 143)
const _SNOW := Color8(240, 245, 250)


func _initialize() -> void:
	var ok := true
	ok = _ensure_dir(TEXTURES_DIR) and ok
	ok = _ensure_dir(DATA_DIR) and ok

	ok = _save_png(_make_flat_texture(_SAND, "sand"), TEXTURES_DIR + "sand.png") and ok
	ok = _save_png(_make_flat_texture(_SNOW, "snow"), TEXTURES_DIR + "snow.png") and ok

	ok = _save_block(_sand_definition()) and ok
	ok = _save_block(_snow_definition()) and ok

	print("RESULT=", "OK" if ok else "FAIL")
	quit(0 if ok else 1)


# ---------------------------------------------------------------------------
# Block definitions
# ---------------------------------------------------------------------------

func _sand_definition() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.sand"
	definition.display_name = "Sand"
	definition.texture_top = TEXTURES_DIR + "sand.png"
	definition.texture_side = TEXTURES_DIR + "sand.png"
	definition.texture_bottom = TEXTURES_DIR + "sand.png"
	definition.hardness = 0.4
	definition.footstep_tag = "sand"
	return definition


func _snow_definition() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.snow"
	definition.display_name = "Snow"
	definition.texture_top = TEXTURES_DIR + "snow.png"
	definition.texture_side = TEXTURES_DIR + "snow.png"
	definition.texture_bottom = TEXTURES_DIR + "snow.png"
	definition.hardness = 0.3
	definition.footstep_tag = "snow"
	return definition


func _save_block(definition: BlockDefinition) -> bool:
	var problem := definition.validate()
	if not problem.is_empty():
		printerr("FAIL: generated definition '%s' is invalid: %s" % [definition.id, problem])
		return false
	var path := DATA_DIR + definition.id.trim_prefix("block.") + ".tres"
	var err := ResourceSaver.save(definition, path)
	if err != OK:
		printerr("FAIL: could not save %s (error %d)" % [path, err])
		return false
	print("wrote ", path)
	return true


# ---------------------------------------------------------------------------
# Textures
# ---------------------------------------------------------------------------

func _make_flat_texture(base: Color, salt: String) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			image.set_pixel(x, y, _speckle(base, x, y, salt))
	return image


## Deterministic +/- NOISE_AMPLITUDE per channel from a hash of (x, y, salt) — same inputs
## always produce the same pixel, no seed/state to carry between runs. Identical formula
## to `generate_block_set.gd`'s, so every placeholder block texture reads as the same kind
## of surface, just a different base colour.
func _speckle(base: Color, x: int, y: int, salt: String) -> Color:
	var h: int = ("%d:%d:%s" % [x, y, salt]).hash()
	var delta: int = (h % (NOISE_AMPLITUDE * 2 + 1)) - NOISE_AMPLITUDE
	var r := clampi(int(base.r8) + delta, 0, 255)
	var g := clampi(int(base.g8) + delta, 0, 255)
	var b := clampi(int(base.b8) + delta, 0, 255)
	return Color8(r, g, b)


func _save_png(image: Image, path: String) -> bool:
	var err := image.save_png(path)
	if err != OK:
		printerr("FAIL: could not save %s (error %d)" % [path, err])
		return false
	print("wrote ", path)
	return true


func _ensure_dir(path: String) -> bool:
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	if err != OK and err != ERR_ALREADY_EXISTS:
		printerr("FAIL: could not create dir %s (error %d)" % [path, err])
		return false
	return true
