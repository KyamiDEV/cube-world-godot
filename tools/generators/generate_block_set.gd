extends SceneTree
## One-off content generator for the first grass/dirt/stone block set (backlog brick 038).
##
## Usage:
##   godot --headless --script res://tools/generators/generate_block_set.gd
##
## Writes speckled placeholder PNGs to `assets/textures/blocks/` and three
## `BlockDefinition` resources to `data/blocks/`. Re-run to regenerate both from
## scratch (deterministic — same pixels and fields every time) after editing the
## constants below; it always overwrites, never merges.
##
## Textures are flat colors with small deterministic per-pixel brightness noise
## (`String.hash()` of the pixel coordinates and a salt) so blocks read as distinct
## material surfaces rather than solid swatches. This is placeholder art, not gameplay
## RNG — `core/random/deterministic_rng.gd`'s world-generation contract does not apply
## to a one-off asset-authoring script.

const TILE_SIZE := 16
const NOISE_AMPLITUDE := 12  # max +/- per channel

const TEXTURES_DIR := "res://assets/textures/blocks/"
const DATA_DIR := "res://data/blocks/"

const _GRASS_TOP := Color8(70, 148, 48)
const _DIRT := Color8(121, 85, 58)
const _STONE := Color8(122, 122, 122)


func _initialize() -> void:
	var ok := true
	ok = _ensure_dir(TEXTURES_DIR) and ok
	ok = _ensure_dir(DATA_DIR) and ok

	ok = _save_png(_make_flat_texture(_GRASS_TOP, "grass_top"),
			TEXTURES_DIR + "grass_top.png") and ok
	ok = _save_png(_make_grass_side_texture(), TEXTURES_DIR + "grass_side.png") and ok
	ok = _save_png(_make_flat_texture(_DIRT, "dirt"), TEXTURES_DIR + "dirt.png") and ok
	ok = _save_png(_make_flat_texture(_STONE, "stone"), TEXTURES_DIR + "stone.png") and ok

	ok = _save_block(_grass_definition()) and ok
	ok = _save_block(_dirt_definition()) and ok
	ok = _save_block(_stone_definition()) and ok

	print("RESULT=", "OK" if ok else "FAIL")
	quit(0 if ok else 1)


# ---------------------------------------------------------------------------
# Block definitions
# ---------------------------------------------------------------------------

func _grass_definition() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.grass"
	definition.display_name = "Grass"
	definition.texture_top = TEXTURES_DIR + "grass_top.png"
	definition.texture_side = TEXTURES_DIR + "grass_side.png"
	definition.texture_bottom = TEXTURES_DIR + "dirt.png"
	definition.hardness = 0.5
	definition.footstep_tag = "grass"
	return definition


func _dirt_definition() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.dirt"
	definition.display_name = "Dirt"
	definition.texture_top = TEXTURES_DIR + "dirt.png"
	definition.texture_side = TEXTURES_DIR + "dirt.png"
	definition.texture_bottom = TEXTURES_DIR + "dirt.png"
	definition.hardness = 0.75
	definition.footstep_tag = "dirt"
	return definition


func _stone_definition() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.stone"
	definition.display_name = "Stone"
	definition.texture_top = TEXTURES_DIR + "stone.png"
	definition.texture_side = TEXTURES_DIR + "stone.png"
	definition.texture_bottom = TEXTURES_DIR + "stone.png"
	definition.hardness = 3.0
	definition.footstep_tag = "stone"
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


## Bottom three quarters dirt, top quarter a grass fringe — the reference "grass block"
## silhouette (green cap bleeding a couple pixels down the side).
func _make_grass_side_texture() -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var fringe_height := int(TILE_SIZE * 0.25)
	for y in TILE_SIZE:
		var base := _GRASS_TOP if y < fringe_height else _DIRT
		for x in TILE_SIZE:
			image.set_pixel(x, y, _speckle(base, x, y, "grass_side"))
	return image


## Deterministic +/- NOISE_AMPLITUDE per channel from a hash of (x, y, salt) — same
## inputs always produce the same pixel, no seed/state to carry between runs.
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
