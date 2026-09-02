extends RefCounted
## The body of `generate_biome_catalog.gd` (backlog brick 067).
##
## Split out for the reason that file's header gives: it is `load()`ed at runtime, after
## project autoloads exist, so it may reference `BiomeClassifier` and friends freely.
##
## The set of biomes is **not** listed here — it is read from `BiomeClassifier.IDS`, and a
## biome in that list with no row in `records()` is a hard failure of this script rather
## than a file quietly not written. That is what keeps `data/biomes/` from drifting away
## from the classifier in the one direction `BiomeRegistry.coverage_reason()` would
## otherwise only catch at load time.
##
## Colours are a **debug palette**, not terrain art (`BiomeDefinition.debug_color`): picked
## so six swatches on a biome-map overlay are tellable apart, and checked against
## `BiomeRegistry.MINIMUM_DEBUG_COLOR_DISTANCE` before anything is written.

const DATA_DIR := "res://data/biomes/"


## id -> [display_name, debug_color, surface_block_id, subsurface_block_id,
## vegetation_density, prop_density]. One row per `BiomeClassifier.IDS` entry, no more. A
## method rather than a `const`, because `Color8()` is a call and not a constant expression.
##
## The surface column (brick 075) reuses `generate_block_set.gd`'s three (grass, dirt,
## stone) for four of the six biomes — a forest floor and a swamp are both honestly mud,
## and bare rock is what a mountain's own ruggedness rule already means — and leans on
## `generate_surface_blocks.gd`'s two new ones (sand, snow) only where nothing already on
## disk is an honest stand-in. `docs/world-generation.md` §14.2 records the mapping and
## why each pairing (or sharing) was made.
##
## The subsurface column (brick 076) needs no new blocks at all: topsoil under grass or
## snow is dirt, topsoil under sand is more sand (real deserts are sand for a long way
## down), and mountain's topsoil is the same stone its surface already is. Every biome's
## bedrock below that is `SubsurfaceMaterial.DEEP_BLOCK_ID`, fixed and not part of this
## table — `docs/world-generation.md` §15.2.
##
## The vegetation-density column (brick 087) is candidates per column, `BiomeDefinition.
## vegetation_density`'s own unit — `forest` thickest, `wetland`/`grassland` scattered, and
## `desert`/`snow`/`mountain` bare (`0.0`, `DecorationMask.spacing_for_density()`'s own
## "disabled" value). Not fitted to any reference figure — none exists,
## `docs/world-generation.md` §26.6 — chosen only for the *ordering* a player can see from a
## distance: a forest reads denser than a wetland, a wetland denser than open grassland,
## and the three bare biomes read as bare.
##
## The prop-density column (brick 088) is the same unit for `BiomeDefinition.prop_density`
## — scattered rocks and props rather than trees. Every biome ships positive here: a
## boulder is at home on rock, sand and snow too, and `biome.mountain` ships the *highest*
## density, not the lowest, so a rugged column (which already classifies to `mountain`)
## reads as rockier without a second gate. Same "chosen for visible ordering, not a
## reference figure" basis, `docs/world-generation.md` §27.5: mountain > desert > grassland
## > forest > snow > wetland, all above zero.
static func records() -> Dictionary:
	return {
		BiomeClassifier.GRASSLAND: ["Grassland", Color8(106, 170, 74),
				"block.grass", "block.dirt", 0.0025, 0.005],
		BiomeClassifier.FOREST: ["Forest", Color8(34, 82, 40),
				"block.grass", "block.dirt", 0.04, 0.004],
		BiomeClassifier.DESERT: ["Desert", Color8(218, 192, 122),
				"block.sand", "block.sand", 0.0, 0.012],
		BiomeClassifier.SNOW: ["Snow", Color8(233, 240, 246),
				"block.snow", "block.dirt", 0.0, 0.003],
		BiomeClassifier.MOUNTAIN: ["Mountain", Color8(128, 128, 128),
				"block.stone", "block.stone", 0.0, 0.03],
		BiomeClassifier.WETLAND: ["Wetland", Color8(48, 116, 118),
				"block.dirt", "block.dirt", 0.01, 0.0015],
	}


## Writes every record and returns a process exit code (0 = OK).
func run() -> int:
	var ok := _ensure_dir(DATA_DIR)
	var table := records()

	var registry := BiomeRegistry.new()
	for id in BiomeClassifier.IDS:
		if not table.has(id):
			printerr("FAIL: no record for biome '%s'" % id)
			ok = false
			continue
		var definition := _definition_for(id, table[id])
		ok = _save_biome(definition) and ok
		registry.register_biome(definition)
	registry.lock()

	# A catalog is only correct as a whole, so check the whole thing before claiming a
	# successful run — the same check `BiomeCatalog.load_default()` makes at load time.
	var problem := registry.self_check()
	if not problem.is_empty():
		printerr("FAIL: generated catalog is incoherent: %s" % problem)
		ok = false

	print("RESULT=", "OK" if ok else "FAIL")
	return 0 if ok else 1


func _definition_for(id: String, row: Array) -> BiomeDefinition:
	var definition := BiomeDefinition.new()
	definition.id = id
	definition.display_name = row[0]
	definition.debug_color = row[1]
	definition.surface_block_id = row[2]
	definition.subsurface_block_id = row[3]
	definition.vegetation_density = row[4]
	definition.prop_density = row[5]
	return definition


func _save_biome(definition: BiomeDefinition) -> bool:
	var problem := definition.validate()
	if not problem.is_empty():
		printerr("FAIL: generated definition '%s' is invalid: %s" % [definition.id, problem])
		return false
	var path := DATA_DIR + BiomeCatalog.file_name_for(definition.id)
	var err := ResourceSaver.save(definition, path)
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
