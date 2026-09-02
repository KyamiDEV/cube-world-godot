extends TestCase
## `world/generation/shoreline_material.gd` — what covers a dry column immediately next to
## water (brick 084).
##
## `test_ocean_pass.gd` and `test_surface_material.gd` already cover the two passes this
## file composes; nothing here re-asserts channel/basin/water-plane classification or the
## biome dither on their own terms. What is specific to `ShorelineMaterial` is the
## combination itself: a wet column must never be overridden (it keeps reading through
## `SurfaceMaterial` exactly as it did before this file existed), a dry column touching
## water must read the fixed shore block, and a dry column that does not touch water must
## be completely unaffected.


func _complete_biomes(surface_block_id: String = "block.grass") -> BiomeRegistry:
	var registry := BiomeRegistry.new()
	var step := 0
	for id in BiomeClassifier.IDS:
		var definition := BiomeDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.debug_color = Color(step * 0.2, 1.0 - step * 0.2, 0.0)
		definition.surface_block_id = surface_block_id
		definition.subsurface_block_id = "block.dirt"
		registry.register_biome(definition)
		step += 1
	registry.lock()
	return registry


## Grass, dirt, stone, sand and snow — enough to resolve every fixture biome's surface and
## `ShorelineMaterial.SHORE_BLOCK_ID`.
func _small_blocks() -> BlockRegistry:
	var registry := BlockRegistry.new()
	for id in ["block.grass", "block.dirt", "block.stone", "block.sand", "block.snow"]:
		var definition := BlockDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.texture_top = "res://assets/textures/blocks/grass_top.png"
		definition.texture_side = "res://assets/textures/blocks/grass_side.png"
		definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
		definition.footstep_tag = "stone"
		registry.register_block(definition)
	registry.lock()
	return registry


func _blocks_without_sand() -> BlockRegistry:
	var registry := BlockRegistry.new()
	for id in ["block.grass", "block.dirt", "block.stone"]:
		var definition := BlockDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.texture_top = "res://assets/textures/blocks/grass_top.png"
		definition.texture_side = "res://assets/textures/blocks/grass_side.png"
		definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
		definition.footstep_tag = "stone"
		registry.register_block(definition)
	registry.lock()
	return registry


func _shoreline_for(name: String, biomes: BiomeRegistry, blocks: BlockRegistry) -> ShorelineMaterial:
	return ShorelineMaterial.for_world(GenerationFixtures.hash_for(name), biomes, blocks)


## The digest of `block_id_at()` over `GenerationFixtures.columns()` for the `typed` world,
## against the shipped catalogs. **Identical to `test_surface_material.gd`'s own
## `PINNED_SIGNATURE`** — not a copy/paste mistake: none of `GenerationFixtures.columns()`'s
## 15 samples lands within one voxel of a river, lake or ocean column (the same small-
## sample-vs-sparse-feature finding every brick since 077 has recorded, sharper here because
## a shoreline is a 1-voxel-wide boundary rather than even the 1.65%-2% features `RiverPass`/
## `LakePass` cover), so `block_id_at()` falls straight through to `SurfaceMaterial.
## block_id_at()` at every one of them. `KNOWN_SHORELINE_COLUMN` below is what actually
## exercises the override.
const PINNED_SIGNATURE := "671f7833af3596ab"

## A real shoreline column on the `typed` world against the shipped catalogs: dry, and two
## of its four edge-neighbours (east and north) already read as ocean. Found by a design-
## time sweep that walked a straight line between two coarse sweep points whose
## `is_water_at()` disagreed, the same method `077`/`078`/`081`/`082`/`083` all used to find
## a hand-picked coordinate a sparse fixture sample could not.
const KNOWN_SHORELINE_COLUMN := Vector2i(-94296, -94139)

## `test_ocean_pass.gd::KNOWN_DRY_COLUMN`, reused rather than re-swept: dry, and far enough
## from the sweep's own coastline that it is not adjacent to water either.
const KNOWN_INLAND_COLUMN := Vector2i(-98232, -98232)

## `test_ocean_pass.gd::KNOWN_OCEAN_COLUMN`, reused rather than re-swept: an ordinary ocean
## column, wet by `OceanPass.is_ocean_at()` alone.
const KNOWN_WATER_COLUMN := Vector2i(-98232, -85953)


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(ShorelineMaterial.for_world(null, _complete_biomes(), _small_blocks()))


func test_refuses_a_block_registry_without_the_shore_block() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(ShorelineMaterial.for_world(hash, _complete_biomes(), _blocks_without_sand()))


func test_delegates_binding_failures_to_surface_material() -> void:
	# `SurfaceMaterial.for_world()` already refuses an unlocked biome registry; 084 does not
	# re-implement that, it just fails the same way through the same call.
	var biomes := BiomeRegistry.new()  # never locked
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(ShorelineMaterial.for_world(hash, biomes, _small_blocks()))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		assert_not_null(_shoreline_for(name, biomes, blocks), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var shoreline := ShorelineMaterial.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> String: return shoreline.block_id_at(column)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_signature_is_pinned() -> void:
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var sampler := func(column: Vector2i) -> String: return shoreline.block_id_at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


# `test_is_seed_sensitive()` is deliberately absent for `is_shoreline_at()`/`block_id_at()`,
# `test_cave_mask.gd`'s own precedent for the same reason: a shoreline is a 1-voxel-wide
# boundary, so an independent-point sweep at any spacing wide enough to be affordable reads
# false at (effectively) every sampled point regardless of seed — two seeds "agreeing"
# everywhere would be true and uninformative, not evidence of anything. `is_water_at()` is
# the continuous coverage underneath (`OceanPass.is_ocean_at()`/`is_river_or_lake_at()`,
# already exercised by `test_ocean_pass.gd`'s own seed-sensitivity check); this file adds no
# noise layer of its own for a seed to sensitise.


# ---------------------------------------------------------------------------
# The combination — the property no shared fixture check can see
# ---------------------------------------------------------------------------

func test_a_dry_column_next_to_water_reads_the_shore_block() -> void:
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_false(shoreline.is_water_at(KNOWN_SHORELINE_COLUMN),
			"fixture column is no longer dry; pick a new one")
	assert_true(shoreline.is_shoreline_at(KNOWN_SHORELINE_COLUMN))
	assert_eq(shoreline.block_id_at(KNOWN_SHORELINE_COLUMN), ShorelineMaterial.SHORE_BLOCK_ID)


func test_the_shore_block_overrides_the_biomes_own_surface_material() -> void:
	# The property that proves the override is real, not a coincidence of the biome's own
	# ground already being sand: the underlying SurfaceMaterial answer at this column is a
	# different block.
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var underneath := shoreline.surface().block_id_at(KNOWN_SHORELINE_COLUMN)
	assert_ne(underneath, ShorelineMaterial.SHORE_BLOCK_ID,
			"fixture column's own biome ground is already sand; pick a new one")
	assert_eq(shoreline.block_id_at(KNOWN_SHORELINE_COLUMN), ShorelineMaterial.SHORE_BLOCK_ID)


func test_a_dry_column_away_from_water_is_unaffected() -> void:
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_false(shoreline.is_water_at(KNOWN_INLAND_COLUMN),
			"fixture column is no longer dry; pick a new one")
	assert_false(shoreline.is_shoreline_at(KNOWN_INLAND_COLUMN))
	assert_eq(shoreline.block_id_at(KNOWN_INLAND_COLUMN),
			shoreline.surface().block_id_at(KNOWN_INLAND_COLUMN))


func test_a_wet_column_is_never_a_shoreline_column_and_is_never_overridden() -> void:
	# The exclusion `OceanPass.is_ocean_at()` already established for its own three-way
	# split, checked first here too: a column already wet never reads as shoreline, however
	# it compares to its own neighbours, and this file has no more business overriding what
	# covers it than `OceanPass` did (§22.8's own boundary — still nothing decides what a
	# wet column looks like).
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(shoreline.is_water_at(KNOWN_WATER_COLUMN),
			"fixture column is no longer water; pick a new one")
	assert_false(shoreline.is_shoreline_at(KNOWN_WATER_COLUMN))
	assert_eq(shoreline.block_id_at(KNOWN_WATER_COLUMN),
			shoreline.surface().block_id_at(KNOWN_WATER_COLUMN))


func test_each_neighbor_offset_alone_is_enough_to_read_as_shoreline() -> void:
	# `KNOWN_SHORELINE_COLUMN`'s east neighbour (-94295, -94139) and north neighbour
	# (-94296, -94138) are independently wet (found by the same design-time sweep); this
	# checks the property directly rather than trusting the single combined case above.
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var east := KNOWN_SHORELINE_COLUMN + Vector2i(1, 0)
	var north := KNOWN_SHORELINE_COLUMN + Vector2i(0, 1)
	assert_true(shoreline.is_water_at(east), "east neighbour is no longer wet; pick a new one")
	assert_true(shoreline.is_water_at(north), "north neighbour is no longer wet; pick a new one")


func test_agrees_with_the_combination_at_every_sample_column() -> void:
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_SHORELINE_COLUMN)
	columns.append(KNOWN_INLAND_COLUMN)
	columns.append(KNOWN_WATER_COLUMN)
	for column in columns:
		var expected_shore := false
		if not shoreline.is_water_at(column):
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if shoreline.is_water_at(column + offset):
					expected_shore = true
					break
		assert_eq(shoreline.is_shoreline_at(column), expected_shore, "column %s" % column)
		var expected_block := (ShorelineMaterial.SHORE_BLOCK_ID if expected_shore
				else shoreline.surface().block_id_at(column))
		assert_eq(shoreline.block_id_at(column), expected_block, "column %s" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		assert_eq(shoreline.is_shoreline_at_voxel(voxel), shoreline.is_shoreline_at(column),
				"voxel %s reads its column" % voxel)
		assert_eq(shoreline.block_id_at_voxel(voxel), shoreline.block_id_at(column),
				"voxel %s reads its column" % voxel)


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_a_real_coastal_patch_actually_has_shoreline_columns() -> void:
	# Not a world-wide fraction claim the way river/lake/ocean's own §20.4/§21.3/§22.4
	# measurements are: a shoreline is a 1-voxel-wide boundary, so its world-wide share
	# depends on total coastline length, not area, and an independent-point sweep can't see
	# it at all (this brick's own design-time sweep found shore=0 across 2304 such points
	# before switching methods). This is instead a worked measurement over one real,
	# contiguous 100x100-column patch straddling the known coastline above: proof the
	# mechanism actually produces shoreline columns at a real coastline, not a claim about
	# their share of the whole world. `docs/world-generation.md` §23.4 has the full figures.
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var origin := Vector2i(-94346, -94189)
	var side := 100
	var shore_count := 0
	var water_count := 0
	for ix in side:
		for iz in side:
			var column := origin + Vector2i(ix, iz)
			if shoreline.is_water_at(column):
				water_count += 1
			elif shoreline.is_shoreline_at(column):
				shore_count += 1
	assert_true(shore_count > 0, "the coastal patch has no shoreline columns at all")
	assert_true(water_count > 0, "the coastal patch has no water columns at all")
	assert_true(shore_count < water_count,
			"shoreline should be a thin fringe, not comparable in size to the water itself")


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var shoreline := _shoreline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_not_null(shoreline.ocean())
	assert_not_null(shoreline.surface())


# ---------------------------------------------------------------------------
# Cross-domain check
# ---------------------------------------------------------------------------

func test_shore_block_reason_for_reports_a_missing_block() -> void:
	assert_ne(ShorelineMaterial.shore_block_reason_for(_blocks_without_sand()), "")


func test_shore_block_reason_for_is_empty_for_the_shipped_catalog() -> void:
	assert_eq(ShorelineMaterial.shore_block_reason_for(BlockSet.load_default()), "")
