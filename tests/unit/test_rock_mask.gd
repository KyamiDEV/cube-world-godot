extends TestCase
## `world/generation/rock_mask.gd` — which columns host a scattered rock/prop, and how
## densely per biome (brick 088).
##
## `test_decoration_mask.gd` already covers eligibility and anchoring on their own terms;
## `test_surface_material.gd` already covers the biome pick. Nothing here re-asserts either.
## What is specific to `RockMask` is the combination: a biome's own `prop_density` picks the
## cell pitch, `WorldHash.SALT_PROPS` draws an independent anchor from `TreeMask`'s, and —
## unlike `TreeMask` — a snow-capped column is **not** excluded.


func _complete_biomes(density_by_id: Dictionary = {}) -> BiomeRegistry:
	var registry := BiomeRegistry.new()
	var step := 0
	for id in BiomeClassifier.IDS:
		var definition := BiomeDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.debug_color = Color(step * 0.2, 1.0 - step * 0.2, 0.0)
		definition.surface_block_id = "block.grass"
		definition.subsurface_block_id = "block.dirt"
		definition.prop_density = density_by_id.get(id, 0.0)
		registry.register_biome(definition)
		step += 1
	registry.lock()
	return registry


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


func _rocks_for(name: String, biomes: BiomeRegistry, blocks: BlockRegistry) -> RockMask:
	return RockMask.for_world(GenerationFixtures.hash_for(name), biomes, blocks)


func _shipped_rocks_for(name: String) -> RockMask:
	return _rocks_for(name, BiomeCatalog.load_default(), BlockSet.load_default())


## A real dry mountain-biome column on the `typed` world that is a genuine rock anchor at
## mountain's shipped density (spacing 6, `WorldHash.SALT_PROPS`). Found by a design-time
## sweep (`tests/unit/test_zzz_scratch_rock_mask.gd`, deleted, same precedent as 087's own
## `KNOWN_*` columns).
const KNOWN_ROCK_COLUMN := Vector2i(-98232, 24567)

## A real dry mountain-biome column, eligible but not its cell's own anchor at mountain's
## shipped spacing — the property that proves density thins the result. Also
## `test_tree_mask.gd::KNOWN_MOUNTAIN_COLUMN` (a mountain column reads bare of trees but is
## still a candidate for rocks). Found by the same sweep.
const KNOWN_NON_ROCK_COLUMN := Vector2i(-98232, 24558)

## `test_tree_mask.gd::KNOWN_FOREST_SNOW_COVERED_COLUMN`, reused: a real forest column high
## and cold enough to read snow-covered. `TreeMask` refuses it; `RockMask` must not.
const KNOWN_FOREST_SNOW_COVERED_COLUMN := Vector2i(-94139, 61395)

## `test_tree_mask.gd::KNOWN_WATER_COLUMN`, reused rather than re-swept.
const KNOWN_WATER_COLUMN := Vector2i(-98232, -85953)

## `test_tree_mask.gd::KNOWN_SHORELINE_COLUMN`, reused rather than re-swept.
const KNOWN_SHORELINE_COLUMN := Vector2i(-94296, -94139)

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
	assert_null(RockMask.for_world(null, _complete_biomes(), _small_blocks()))


func test_requires_a_locked_biome_registry() -> void:
	var biomes := BiomeRegistry.new()  # never locked
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(RockMask.for_world(hash, biomes, _small_blocks()))


func test_delegates_binding_failures_to_the_passes_underneath() -> void:
	# `SurfaceMaterial.for_world()` already refuses a biome whose surface block the registry
	# has no record for; 088 does not re-implement that, it fails the same way through it.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var blocks_without_grass := BlockRegistry.new()
	for id in ["block.dirt", "block.stone", "block.sand", "block.snow"]:
		var definition := BlockDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.texture_top = "res://assets/textures/blocks/grass_top.png"
		definition.texture_side = "res://assets/textures/blocks/grass_side.png"
		definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
		definition.footstep_tag = "stone"
		blocks_without_grass.register_block(definition)
	blocks_without_grass.lock()
	assert_null(RockMask.for_world(hash, _complete_biomes(), blocks_without_grass))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		assert_not_null(_rocks_for(name, biomes, blocks), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# spacing_at()
# ---------------------------------------------------------------------------

func test_spacing_at_is_zero_for_a_biome_with_no_props() -> void:
	# The shipped catalog ships every biome positive, but a hand-built registry can disable a
	# biome, and `is_rock_at()`'s short-circuit depends on that reading exactly zero.
	var biomes := _complete_biomes()  # every biome defaults to 0.0
	var rocks := _rocks_for(GenerationFixtures.WORLD_TYPED, biomes, _small_blocks())
	for column in GenerationFixtures.columns():
		assert_eq(rocks.spacing_at(column), 0, "column %s" % column)
	assert_eq(DecorationMask.spacing_for_density(0.0), 0)


func test_spacing_at_follows_the_winning_biomes_own_density() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		var id := rocks.surface().biome_id_at(column)
		var expected := DecorationMask.spacing_for_density(
				rocks.biomes().get_biome(id).prop_density)
		assert_eq(rocks.spacing_at(column), expected, "column %s" % column)


func test_every_shipped_biome_has_a_positive_spacing() -> void:
	# The divergence from `TreeMask`: no biome is bare of rocks, so no column short-circuits
	# on density alone the way half of every column does for trees.
	var registry := BiomeCatalog.load_default()
	for id in BiomeClassifier.IDS:
		assert_true(DecorationMask.spacing_for_density(registry.get_biome(id).prop_density) > 0,
				"%s must scatter some props" % id)


# ---------------------------------------------------------------------------
# is_rock_at() — the combination
# ---------------------------------------------------------------------------

func test_a_disabled_biome_column_never_hosts_a_rock() -> void:
	var biomes := _complete_biomes()  # all 0.0
	var rocks := _rocks_for(GenerationFixtures.WORLD_TYPED, biomes, _small_blocks())
	for column in GenerationFixtures.columns():
		assert_false(rocks.is_rock_at(column), "column %s" % column)


func test_a_water_column_never_hosts_a_rock() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	assert_true(rocks.decoration().shoreline().is_water_at(KNOWN_WATER_COLUMN),
			"fixture column is no longer water; pick a new one")
	assert_false(rocks.is_rock_at(KNOWN_WATER_COLUMN))


func test_a_shoreline_column_never_hosts_a_rock() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	assert_true(rocks.decoration().shoreline().is_shoreline_at(KNOWN_SHORELINE_COLUMN),
			"fixture column is no longer a shoreline column; pick a new one")
	assert_false(rocks.is_rock_at(KNOWN_SHORELINE_COLUMN))


func test_a_real_column_hosts_a_rock_at_its_own_anchor() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	assert_true(rocks.spacing_at(KNOWN_ROCK_COLUMN) > 0)
	assert_true(rocks.is_rock_at(KNOWN_ROCK_COLUMN))


func test_a_column_off_its_own_anchor_hosts_no_rock() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	assert_true(rocks.decoration().is_eligible_at(KNOWN_NON_ROCK_COLUMN),
			"fixture column is no longer eligible ground; pick a new one")
	assert_true(rocks.spacing_at(KNOWN_NON_ROCK_COLUMN) > 0)
	assert_false(rocks.is_rock_at(KNOWN_NON_ROCK_COLUMN))


func test_snow_cover_does_not_exclude_a_rock() -> void:
	# The one place `RockMask` and `TreeMask` deliberately disagree. At a genuinely
	# snow-covered column, `RockMask`'s answer is fully explained by density + decoration
	# with no altitude term, and `TreeMask`'s answer at the same column is false *because* of
	# the snow it does read.
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	var trees := TreeMask.for_world(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED),
			BiomeCatalog.load_default(), BlockSet.load_default())
	var column := KNOWN_FOREST_SNOW_COVERED_COLUMN
	assert_true(trees.snowline().is_snow_covered_at(column),
			"fixture column is no longer snow-covered; pick a new one")
	var spacing := rocks.spacing_at(column)
	var explained_without_snow := spacing > 0 and rocks.decoration().is_decoration_anchor_at(
			column, spacing, WorldHash.SALT_PROPS)
	assert_eq(rocks.is_rock_at(column), explained_without_snow,
			"RockMask must not consult the snowline")
	# And trees, at the same column, are refused purely for the snow.
	assert_true(trees.spacing_at(column) > 0)
	assert_false(trees.is_tree_at(column))


func test_agrees_with_the_combination_at_every_sample_column() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_ROCK_COLUMN)
	columns.append(KNOWN_NON_ROCK_COLUMN)
	columns.append(KNOWN_FOREST_SNOW_COVERED_COLUMN)
	columns.append(KNOWN_WATER_COLUMN)
	columns.append(KNOWN_SHORELINE_COLUMN)
	for column in columns:
		var spacing := rocks.spacing_at(column)
		var expected := false
		if spacing > 0:
			expected = rocks.decoration().is_decoration_anchor_at(
					column, spacing, WorldHash.SALT_PROPS)
		assert_eq(rocks.is_rock_at(column), expected, "column %s" % column)


func test_a_rock_anchor_and_a_tree_anchor_are_independent() -> void:
	# Same cell grid, different salts: the two passes draw from independent streams and can
	# pick different anchor columns inside a shared cell (`DecorationMask` §25.3).
	var decoration := DecorationMask.for_world(
			GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED),
			BiomeCatalog.load_default(), BlockSet.load_default())
	var spacing := 6
	var disagreements := 0
	for ix in 40:
		for iz in 40:
			var cell := Vector2i(ix - 20, iz - 20)
			if decoration.anchor_column_in_cell(cell, spacing, WorldHash.SALT_TREES) \
					!= decoration.anchor_column_in_cell(cell, spacing, WorldHash.SALT_PROPS):
				disagreements += 1
	assert_true(disagreements > 0,
			"tree and rock anchors coincided in every sampled cell; salts are not separating them")


func test_a_voxel_reads_its_own_column() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		assert_eq(rocks.is_rock_at_voxel(voxel), rocks.is_rock_at(column),
				"voxel %s reads its column" % voxel)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var rocks := RockMask.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> bool: return rocks.is_rock_at(column)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		var rocks := RockMask.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> bool: return rocks.is_rock_at(column)
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, _sweep_columns()), "")


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_rock_cover_is_a_real_minority_of_the_world_not_zero_and_not_dominant() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	var covered_count := 0
	var columns := _sweep_columns()
	for column in columns:
		if rocks.is_rock_at(column):
			covered_count += 1
	var fraction := float(covered_count) / float(columns.size())
	assert_in_range(fraction, 0.0, 0.08,
			"rock fraction %s is not a plausible minority of the world" % fraction)


func test_mountain_reads_visibly_rockier_than_grassland() -> void:
	# The property the whole per-biome density field exists for, measured rather than only
	# asserted on the catalog numbers (`test_biome_catalog.gd`'s own ordering check): every
	# column of the wide sweep classified per column and bucketed by its own winning biome,
	# so a scattered mountain column counts as mountain wherever it falls. Mountain
	# (`prop_density` 0.03) must actually read as more rock cover than grassland (0.005) once
	# eligibility and the anchor draw run together.
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	var hits := {BiomeClassifier.MOUNTAIN: 0, BiomeClassifier.GRASSLAND: 0}
	var total := {BiomeClassifier.MOUNTAIN: 0, BiomeClassifier.GRASSLAND: 0}
	for column in _sweep_columns():
		var id := rocks.surface().biome_id_at(column)
		if not total.has(id):
			continue
		total[id] += 1
		if rocks.is_rock_at(column):
			hits[id] += 1
	assert_true(total[BiomeClassifier.MOUNTAIN] > 0 and total[BiomeClassifier.GRASSLAND] > 0,
			"the sweep must contain both mountain and grassland columns (saw %s)" % total)
	var mountain_fraction := float(hits[BiomeClassifier.MOUNTAIN]) \
			/ float(total[BiomeClassifier.MOUNTAIN])
	var grassland_fraction := float(hits[BiomeClassifier.GRASSLAND]) \
			/ float(total[BiomeClassifier.GRASSLAND])
	assert_true(mountain_fraction > grassland_fraction,
			"mountain fraction %s must exceed grassland fraction %s" % [
					mountain_fraction, grassland_fraction])


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var rocks := _shipped_rocks_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(rocks.decoration())
	assert_not_null(rocks.surface())
	assert_not_null(rocks.biomes())
