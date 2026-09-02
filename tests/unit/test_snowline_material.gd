extends TestCase
## `world/generation/snowline_material.gd` — which columns above the frost line read as
## snow regardless of biome (brick 085).
##
## `test_shoreline_material.gd`, `test_temperature_field.gd` and `test_terrace_pass.gd`
## already cover the passes this file composes; nothing here re-asserts wet/shoreline
## classification, the raw climate reading or the terraced height on their own terms. What
## is specific to `SnowlineMaterial` is the combination itself: a column at or below
## `ElevationField.LAND_BASE_VOXELS` must never be touched (its biome already decided
## whether it is snow), a wet or shoreline column must never be touched (`ShorelineMaterial`
## already decided it), and a column standing high enough and cold enough — in *any* other
## biome, mountain included — must read the fixed snow block instead.


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
## both `ShorelineMaterial.SHORE_BLOCK_ID` and `SnowlineMaterial.SNOW_BLOCK_ID`.
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


func _blocks_without_snow() -> BlockRegistry:
	var registry := BlockRegistry.new()
	for id in ["block.grass", "block.dirt", "block.stone", "block.sand"]:
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


func _snowline_for(name: String, biomes: BiomeRegistry, blocks: BlockRegistry) -> SnowlineMaterial:
	return SnowlineMaterial.for_world(GenerationFixtures.hash_for(name), biomes, blocks)


## The digest of `block_id_at()` over `GenerationFixtures.columns()` for the `typed` world,
## against the shipped catalogs. **Identical to `test_shoreline_material.gd`'s and
## `test_surface_material.gd`'s own `PINNED_SIGNATURE`** — not a copy/paste mistake: none of
## `GenerationFixtures.columns()`'s 15 samples stands above `ElevationField.LAND_BASE_VOXELS`
## and reads cold enough at once (found by a design-time sweep, the same small-sample-vs-
## sparse-feature finding every brick since 077 has recorded), so `block_id_at()` falls
## straight through to `ShorelineMaterial.block_id_at()` — which, at these same 15 columns,
## already falls straight through to `SurfaceMaterial.block_id_at()` (084's own comment) — at
## every one of them. `KNOWN_MOUNTAIN_SNOW_COVERED_COLUMN` and
## `KNOWN_FOREST_SNOW_COVERED_COLUMN` below are what actually exercise the override.
const PINNED_SIGNATURE := "671f7833af3596ab"

## A real mountain-biome column on the `typed` world against the shipped catalogs: 32 voxels
## above `ElevationField.LAND_BASE_VOXELS`, warm enough (raw temperature `0.389`) that
## `BiomeClassifier` would never call it `SNOW`, but cold enough once lapsed
## (`0.389 - 32 * LAPSE_RATE_PER_VOXEL = 0.189 < TEMPERATURE_COLD`) to read as snow-covered
## regardless. Found by a design-time sweep of the standard 2304-column distribution.
const KNOWN_MOUNTAIN_SNOW_COVERED_COLUMN := Vector2i(-69581, -77767)

## A real mountain-biome column, also well above the baseline (40 voxels), whose climate
## (raw temperature `0.500`) stays too warm to cross `TEMPERATURE_COLD` even after lapsing —
## the property this column exists to exercise: altitude alone is not enough, the two must
## combine. Found by the same sweep.
const KNOWN_MOUNTAIN_UNCOVERED_COLUMN := Vector2i(-98232, 24558)

## A real forest-biome column, 24 voxels above the baseline, whose raw temperature (`0.224`)
## sits just on the warm side of `TEMPERATURE_COLD` — `BiomeClassifier` alone would call this
## `FOREST`, not `SNOW` — but which lapses to `0.074`, well under the threshold. The property
## this column exists to exercise: the override reaches biomes other than `mountain`, and the
## block it overrides really is the biome's own ground (`block.grass`), not already snow by
## coincidence. Found by the same sweep.
const KNOWN_FOREST_SNOW_COVERED_COLUMN := Vector2i(-94139, 61395)

## A real column 24 voxels above the baseline whose raw temperature (`0.974`) is high enough
## that even the full lapse at that height (`0.974 - 24 * LAPSE_RATE_PER_VOXEL = 0.824`)
## stays far from `TEMPERATURE_COLD`. Found by the same sweep.
const KNOWN_HIGH_BUT_WARM_COLUMN := Vector2i(-98232, -94139)

## A real column exactly at `ElevationField.LAND_BASE_VOXELS` (`height_above_land_base_at()
## == 0`) — the boundary the gate in `is_snow_covered_at()` sits on. Found by the same sweep.
const KNOWN_AT_BASELINE_COLUMN := Vector2i(-98232, -90046)

## `test_ocean_pass.gd::KNOWN_OCEAN_COLUMN`, reused rather than re-swept: an ordinary wet
## column, to exercise the "never touch water" exclusion.
const KNOWN_WATER_COLUMN := Vector2i(-98232, -85953)

## `test_shoreline_material.gd::KNOWN_SHORELINE_COLUMN`, reused rather than re-swept: a real
## dry shoreline column, to exercise the "never touch a beach either" exclusion.
const KNOWN_SHORELINE_COLUMN := Vector2i(-94296, -94139)

## Same sweep every Phase D brick since 060 uses, so this file's own fraction measurement is
## comparable column for column against every earlier one.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232


func _sweep_columns() -> Array[Vector2i]:
	var columns: Array[Vector2i] = []
	for ix in SWEEP_SIDE:
		for iz in SWEEP_SIDE:
			columns.append(Vector2i(SWEEP_ORIGIN + ix * SWEEP_SPACING,
					SWEEP_ORIGIN + iz * SWEEP_SPACING))
	return columns


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(SnowlineMaterial.for_world(null, _complete_biomes(), _small_blocks()))


func test_refuses_a_block_registry_without_the_snow_block() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SnowlineMaterial.for_world(hash, _complete_biomes(), _blocks_without_snow()))


func test_delegates_binding_failures_to_shoreline_material() -> void:
	# `ShorelineMaterial.for_world()` already refuses an unlocked biome registry; 085 does not
	# re-implement that, it just fails the same way through the same call.
	var biomes := BiomeRegistry.new()  # never locked
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SnowlineMaterial.for_world(hash, biomes, _small_blocks()))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		assert_not_null(_snowline_for(name, biomes, blocks), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# The lapse rate itself
# ---------------------------------------------------------------------------

func test_self_check_passes_for_the_shipped_constants() -> void:
	assert_eq(SnowlineMaterial.self_check(), "")


func test_the_tallest_possible_relief_is_always_snow_covered_at_the_hottest_climate() -> void:
	# The invariant `LAPSE_RATE_PER_VOXEL` was derived for, checked directly rather than only
	# through `self_check()`'s own algebraic form.
	var hottest_at_the_tallest_relief := (TemperatureField.MAXIMUM
			- SnowlineMaterial.LAPSE_RATE_PER_VOXEL * ElevationField.RELIEF_AMPLITUDE_VOXELS)
	assert_true(hottest_at_the_tallest_relief <= BiomeClassifier.TEMPERATURE_COLD + 1e-9,
			("the hottest possible climate at the tallest possible relief is %s, expected at "
					+ "or below TEMPERATURE_COLD (%s)")
					% [hottest_at_the_tallest_relief, BiomeClassifier.TEMPERATURE_COLD])


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var snowline := SnowlineMaterial.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> String: return snowline.block_id_at(column)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_signature_is_pinned() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var sampler := func(column: Vector2i) -> String: return snowline.block_id_at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


## `GenerationFixtures.columns()` reads no snow-covered column on the `typed` world (see
## `PINNED_SIGNATURE`'s own comment), so seed sensitivity needs the wider sweep the same way
## `test_ocean_pass.gd::test_is_seed_sensitive` already did for the identical reason.
func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		var snowline := SnowlineMaterial.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> bool: return snowline.is_snow_covered_at(column)
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, _sweep_columns()), "")


# ---------------------------------------------------------------------------
# The combination — the property no shared fixture check can see
# ---------------------------------------------------------------------------

func test_a_cold_high_mountain_column_reads_the_snow_block() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(snowline.height_above_land_base_at(KNOWN_MOUNTAIN_SNOW_COVERED_COLUMN) > 0.0,
			"fixture column is no longer above the land base; pick a new one")
	assert_true(snowline.is_snow_covered_at(KNOWN_MOUNTAIN_SNOW_COVERED_COLUMN))
	assert_eq(snowline.block_id_at(KNOWN_MOUNTAIN_SNOW_COVERED_COLUMN),
			SnowlineMaterial.SNOW_BLOCK_ID)


func test_the_snow_block_overrides_the_mountains_own_bare_stone() -> void:
	# The property that proves the override is real, not a coincidence of the ground already
	# being snow: the shoreline/surface answer underneath this column is a different block.
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var underneath := snowline.shoreline().block_id_at(KNOWN_MOUNTAIN_SNOW_COVERED_COLUMN)
	assert_ne(underneath, SnowlineMaterial.SNOW_BLOCK_ID,
			"fixture column's own ground is already snow; pick a new one")
	assert_eq(snowline.block_id_at(KNOWN_MOUNTAIN_SNOW_COVERED_COLUMN),
			SnowlineMaterial.SNOW_BLOCK_ID)


func test_altitude_alone_is_not_enough_a_warm_high_mountain_stays_bare() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(snowline.height_above_land_base_at(KNOWN_MOUNTAIN_UNCOVERED_COLUMN) > 0.0,
			"fixture column is no longer above the land base; pick a new one")
	assert_false(snowline.is_snow_covered_at(KNOWN_MOUNTAIN_UNCOVERED_COLUMN))
	assert_eq(snowline.block_id_at(KNOWN_MOUNTAIN_UNCOVERED_COLUMN),
			snowline.shoreline().block_id_at(KNOWN_MOUNTAIN_UNCOVERED_COLUMN))


func test_a_cold_high_column_outside_the_mountain_biome_still_reads_snow() -> void:
	# The override is not special-cased to `biome.mountain`: a forest column, high and cold
	# enough, is overridden exactly the same way.
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var underneath := snowline.shoreline().block_id_at(KNOWN_FOREST_SNOW_COVERED_COLUMN)
	assert_eq(underneath, "block.grass",
			"fixture column's own biome ground is no longer grass; pick a new one")
	assert_true(snowline.is_snow_covered_at(KNOWN_FOREST_SNOW_COVERED_COLUMN))
	assert_eq(snowline.block_id_at(KNOWN_FOREST_SNOW_COVERED_COLUMN),
			SnowlineMaterial.SNOW_BLOCK_ID)


func test_a_high_but_hot_column_is_unaffected() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(snowline.height_above_land_base_at(KNOWN_HIGH_BUT_WARM_COLUMN) > 0.0,
			"fixture column is no longer above the land base; pick a new one")
	assert_false(snowline.is_snow_covered_at(KNOWN_HIGH_BUT_WARM_COLUMN))
	assert_eq(snowline.block_id_at(KNOWN_HIGH_BUT_WARM_COLUMN),
			snowline.shoreline().block_id_at(KNOWN_HIGH_BUT_WARM_COLUMN))


func test_a_column_at_the_baseline_is_never_touched_however_cold() -> void:
	# The gate itself: at or below `ElevationField.LAND_BASE_VOXELS`, this file must defer
	# entirely, whatever the raw temperature says, rather than re-deciding the biome edge
	# `BiomeTransition`/`SurfaceMaterial` already dither smoothly across.
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_eq(snowline.height_above_land_base_at(KNOWN_AT_BASELINE_COLUMN), 0.0,
			"fixture column is no longer exactly at the land base; pick a new one")
	assert_false(snowline.is_snow_covered_at(KNOWN_AT_BASELINE_COLUMN))
	assert_eq(snowline.block_id_at(KNOWN_AT_BASELINE_COLUMN),
			snowline.shoreline().block_id_at(KNOWN_AT_BASELINE_COLUMN))


func test_a_wet_column_is_never_overridden_however_cold_and_high_its_climate_reads() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(snowline.shoreline().is_water_at(KNOWN_WATER_COLUMN),
			"fixture column is no longer water; pick a new one")
	assert_eq(snowline.block_id_at(KNOWN_WATER_COLUMN),
			snowline.shoreline().block_id_at(KNOWN_WATER_COLUMN))


func test_a_shoreline_column_is_never_overridden_either() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(snowline.shoreline().is_shoreline_at(KNOWN_SHORELINE_COLUMN),
			"fixture column is no longer a shoreline column; pick a new one")
	assert_eq(snowline.block_id_at(KNOWN_SHORELINE_COLUMN), ShorelineMaterial.SHORE_BLOCK_ID)
	assert_eq(snowline.block_id_at(KNOWN_SHORELINE_COLUMN),
			snowline.shoreline().block_id_at(KNOWN_SHORELINE_COLUMN))


func test_agrees_with_the_combination_at_every_sample_column() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_MOUNTAIN_SNOW_COVERED_COLUMN)
	columns.append(KNOWN_MOUNTAIN_UNCOVERED_COLUMN)
	columns.append(KNOWN_FOREST_SNOW_COVERED_COLUMN)
	columns.append(KNOWN_HIGH_BUT_WARM_COLUMN)
	columns.append(KNOWN_AT_BASELINE_COLUMN)
	columns.append(KNOWN_WATER_COLUMN)
	columns.append(KNOWN_SHORELINE_COLUMN)
	for column in columns:
		var shore_block := snowline.shoreline().block_id_at(column)
		var expected_covered := false
		if not (snowline.shoreline().is_water_at(column) or snowline.shoreline().is_shoreline_at(column)):
			var height := maxf(0.0, snowline.terrace().at(column) - ElevationField.LAND_BASE_VOXELS)
			if height > 0.0:
				var effective := (snowline.temperature().at(column)
						- SnowlineMaterial.LAPSE_RATE_PER_VOXEL * height)
				expected_covered = effective < BiomeClassifier.TEMPERATURE_COLD
		assert_eq(snowline.is_snow_covered_at(column), expected_covered, "column %s" % column)
		var expected_block := SnowlineMaterial.SNOW_BLOCK_ID if expected_covered else shore_block
		assert_eq(snowline.block_id_at(column), expected_block, "column %s" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		assert_eq(snowline.is_snow_covered_at_voxel(voxel), snowline.is_snow_covered_at(column),
				"voxel %s reads its column" % voxel)
		assert_eq(snowline.block_id_at_voxel(voxel), snowline.block_id_at(column),
				"voxel %s reads its column" % voxel)


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_snow_cover_is_a_real_minority_of_the_world_not_zero_and_not_dominant() -> void:
	# Measured at the shipped constants over the standard 2304-column sweep: 7.29% of columns
	# read snow-covered by altitude alone. Banded with headroom, `CaveMask`'s/`RiverPass`'s own
	# precedent for asserting a measured property rather than pinning the exact figure.
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var covered_count := 0
	var columns := _sweep_columns()
	for column in columns:
		if snowline.is_snow_covered_at(column):
			covered_count += 1
	var fraction := float(covered_count) / float(columns.size())
	assert_in_range(fraction, 0.01, 0.3,
			"snow-covered fraction %s is not a plausible minority of the world" % fraction)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var snowline := _snowline_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_not_null(snowline.shoreline())
	assert_not_null(snowline.temperature())
	assert_not_null(snowline.terrace())


# ---------------------------------------------------------------------------
# Cross-domain check
# ---------------------------------------------------------------------------

func test_snow_block_reason_for_reports_a_missing_block() -> void:
	assert_ne(SnowlineMaterial.snow_block_reason_for(_blocks_without_snow()), "")


func test_snow_block_reason_for_is_empty_for_the_shipped_catalog() -> void:
	assert_eq(SnowlineMaterial.snow_block_reason_for(BlockSet.load_default()), "")
