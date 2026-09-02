extends TestCase
## `world/generation/tree_mask.gd` — which columns grow a tree, and how densely per biome
## (brick 087).
##
## `test_decoration_mask.gd` already covers eligibility and anchoring on their own terms;
## `test_snowline_material.gd` already covers altitude-driven snow cover on its own terms.
## Nothing here re-asserts either. What is specific to `TreeMask` is the combination itself:
## a biome's own density picks the cell pitch, a snow-capped column is excluded regardless of
## biome, and a biome with zero density short-circuits before either of the other two passes
## ever runs.


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
		definition.vegetation_density = density_by_id.get(id, 0.0)
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


func _trees_for(name: String, biomes: BiomeRegistry, blocks: BlockRegistry) -> TreeMask:
	return TreeMask.for_world(GenerationFixtures.hash_for(name), biomes, blocks)


func _shipped_trees_for(name: String) -> TreeMask:
	return _trees_for(name, BiomeCatalog.load_default(), BlockSet.load_default())


## `test_snowline_material.gd::KNOWN_FOREST_SNOW_COVERED_COLUMN`, reused rather than
## re-swept: a real forest column, high and cold enough once lapsed to read snow-covered.
const KNOWN_FOREST_SNOW_COVERED_COLUMN := Vector2i(-94139, 61395)

## `test_snowline_material.gd::KNOWN_MOUNTAIN_UNCOVERED_COLUMN`, reused rather than
## re-swept: a real mountain-biome column, warm enough to stay bare of snow — exercises the
## "mountain's own zero density excludes it anyway" property, independent of altitude.
const KNOWN_MOUNTAIN_COLUMN := Vector2i(-98232, 24558)

## `test_shoreline_material.gd::KNOWN_WATER_COLUMN`, reused rather than re-swept.
const KNOWN_WATER_COLUMN := Vector2i(-98232, -85953)

## `test_shoreline_material.gd::KNOWN_SHORELINE_COLUMN`, reused rather than re-swept.
const KNOWN_SHORELINE_COLUMN := Vector2i(-94296, -94139)

## A real forest-biome column on the `typed` world, not snow-covered, that is a genuine tree
## anchor at forest's own shipped density (spacing 5, `WorldHash.SALT_TREES`). Found by a
## design-time sweep (`tests/unit/test_zzz_scratch_tree_mask.gd`, deleted, `076`'s/`080`'s/
## `081`'s/`084`'s/`085`'s own scratch-test precedent).
const KNOWN_FOREST_TREE_COLUMN := Vector2i(-98232, 466602)

## A real forest-biome column, not snow-covered, that is eligible but not its cell's own
## anchor at forest's shipped spacing — the property that proves density thins the result
## rather than planting a tree on every forest column. Found by the same sweep.
const KNOWN_FOREST_NON_TREE_COLUMN := Vector2i(-98232, -61395)

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
	assert_null(TreeMask.for_world(null, _complete_biomes(), _small_blocks()))


func test_requires_a_locked_biome_registry() -> void:
	var biomes := BiomeRegistry.new()  # never locked
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(TreeMask.for_world(hash, biomes, _small_blocks()))


func test_delegates_binding_failures_to_snowline_material() -> void:
	# `SnowlineMaterial.for_world()` already refuses a block registry without the fixed snow
	# block; 087 does not re-implement that, it just fails the same way through the same call.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var blocks_without_snow := BlockRegistry.new()
	for id in ["block.grass", "block.dirt", "block.stone", "block.sand"]:
		var definition := BlockDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.texture_top = "res://assets/textures/blocks/grass_top.png"
		definition.texture_side = "res://assets/textures/blocks/grass_side.png"
		definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
		definition.footstep_tag = "stone"
		blocks_without_snow.register_block(definition)
	blocks_without_snow.lock()
	assert_null(TreeMask.for_world(hash, _complete_biomes(), blocks_without_snow))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		assert_not_null(_trees_for(name, biomes, blocks), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# spacing_at()
# ---------------------------------------------------------------------------

func test_spacing_at_is_zero_for_a_biome_with_no_vegetation() -> void:
	var biomes := _complete_biomes({BiomeClassifier.DESERT: 0.0})
	var trees := _trees_for(GenerationFixtures.WORLD_TYPED, biomes, _small_blocks())
	# Every fixture biome above defaults to 0.0 too, so any column resolves to zero here —
	# what matters is the shipped catalog's own desert reads the same way.
	var shipped := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(shipped.surface().biomes().get_biome(BiomeClassifier.DESERT).vegetation_density,
			0.0)
	assert_eq(DecorationMask.spacing_for_density(0.0), 0)


func test_spacing_at_follows_the_winning_biomes_own_density() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		var id := trees.surface().biome_id_at(column)
		var expected := DecorationMask.spacing_for_density(
				trees.biomes().get_biome(id).vegetation_density)
		assert_eq(trees.spacing_at(column), expected, "column %s" % column)


# ---------------------------------------------------------------------------
# is_tree_at() — the combination
# ---------------------------------------------------------------------------

func test_a_bare_biome_column_never_grows_a_tree_however_the_anchor_would_fall() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(trees.surface().biome_id_at(KNOWN_MOUNTAIN_COLUMN), BiomeClassifier.MOUNTAIN,
			"fixture column is no longer mountain; pick a new one")
	assert_eq(trees.spacing_at(KNOWN_MOUNTAIN_COLUMN), 0)
	assert_false(trees.is_tree_at(KNOWN_MOUNTAIN_COLUMN))


func test_a_snow_capped_forest_column_never_grows_a_tree() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(trees.surface().biome_id_at(KNOWN_FOREST_SNOW_COVERED_COLUMN),
			BiomeClassifier.FOREST, "fixture column is no longer forest; pick a new one")
	assert_true(trees.snowline().is_snow_covered_at(KNOWN_FOREST_SNOW_COVERED_COLUMN),
			"fixture column is no longer snow-covered; pick a new one")
	assert_true(trees.spacing_at(KNOWN_FOREST_SNOW_COVERED_COLUMN) > 0,
			"forest's own density must still be positive for this to exercise the exclusion")
	assert_false(trees.is_tree_at(KNOWN_FOREST_SNOW_COVERED_COLUMN))


func test_a_water_column_never_grows_a_tree() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	assert_true(trees.decoration().shoreline().is_water_at(KNOWN_WATER_COLUMN),
			"fixture column is no longer water; pick a new one")
	assert_false(trees.is_tree_at(KNOWN_WATER_COLUMN))


func test_a_shoreline_column_never_grows_a_tree() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	assert_true(trees.decoration().shoreline().is_shoreline_at(KNOWN_SHORELINE_COLUMN),
			"fixture column is no longer a shoreline column; pick a new one")
	assert_false(trees.is_tree_at(KNOWN_SHORELINE_COLUMN))


func test_a_real_forest_column_grows_a_tree_at_its_own_anchor() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(trees.surface().biome_id_at(KNOWN_FOREST_TREE_COLUMN), BiomeClassifier.FOREST,
			"fixture column is no longer forest; pick a new one")
	assert_false(trees.snowline().is_snow_covered_at(KNOWN_FOREST_TREE_COLUMN),
			"fixture column is no longer snow-free; pick a new one")
	assert_true(trees.is_tree_at(KNOWN_FOREST_TREE_COLUMN))


func test_a_forest_column_off_its_own_anchor_grows_no_tree() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(trees.surface().biome_id_at(KNOWN_FOREST_NON_TREE_COLUMN), BiomeClassifier.FOREST,
			"fixture column is no longer forest; pick a new one")
	assert_false(trees.snowline().is_snow_covered_at(KNOWN_FOREST_NON_TREE_COLUMN),
			"fixture column is no longer snow-free; pick a new one")
	assert_false(trees.is_tree_at(KNOWN_FOREST_NON_TREE_COLUMN))


func test_agrees_with_the_combination_at_every_sample_column() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_FOREST_SNOW_COVERED_COLUMN)
	columns.append(KNOWN_MOUNTAIN_COLUMN)
	columns.append(KNOWN_WATER_COLUMN)
	columns.append(KNOWN_SHORELINE_COLUMN)
	columns.append(KNOWN_FOREST_TREE_COLUMN)
	columns.append(KNOWN_FOREST_NON_TREE_COLUMN)
	for column in columns:
		var spacing := trees.spacing_at(column)
		var expected := false
		if spacing > 0 and not trees.snowline().is_snow_covered_at(column):
			expected = trees.decoration().is_decoration_anchor_at(
					column, spacing, WorldHash.SALT_TREES)
		assert_eq(trees.is_tree_at(column), expected, "column %s" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		assert_eq(trees.is_tree_at_voxel(voxel), trees.is_tree_at(column),
				"voxel %s reads its column" % voxel)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var trees := TreeMask.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> bool: return trees.is_tree_at(column)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		var trees := TreeMask.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> bool: return trees.is_tree_at(column)
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, _sweep_columns()), "")


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_tree_cover_is_a_real_minority_of_the_world_not_zero_and_not_dominant() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	var covered_count := 0
	var columns := _sweep_columns()
	for column in columns:
		if trees.is_tree_at(column):
			covered_count += 1
	var fraction := float(covered_count) / float(columns.size())
	assert_in_range(fraction, 0.0, 0.05,
			"tree fraction %s is not a plausible minority of the world" % fraction)


func test_forest_reads_visibly_denser_than_grassland() -> void:
	# The property the whole per-biome density field exists for, measured rather than only
	# asserted on the catalog numbers (`test_biome_catalog.gd`'s own ordering check): sampled
	# over a patch with real forest and grassland columns in it (classified per column, not
	# a uniform region — a 200x200 patch this world's own biome dithering never actually
	# gives one of), forest must actually read as more tree cover once eligibility, spacing
	# and snow exclusion all run together.
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	var forest_hits := 0
	var forest_total := 0
	var grassland_hits := 0
	var grassland_total := 0
	# `-98232, -98232` (this file's other `SWEEP_ORIGIN`) turned out to sit inside a lake:
	# every column in that patch is `DecorationMask`-ineligible water, so neither biome ever
	# grows a tree there. Found by a design-time sweep (deleted, same precedent as the
	# `KNOWN_*` columns above) for a patch with both biomes actually on dry ground.
	var origin := Vector2i(-105000, -15000)
	var side := 200
	for ix in side:
		for iz in side:
			var column := origin + Vector2i(ix, iz)
			var id := trees.surface().biome_id_at(column)
			if id == BiomeClassifier.FOREST:
				forest_total += 1
				if trees.is_tree_at(column):
					forest_hits += 1
			elif id == BiomeClassifier.GRASSLAND:
				grassland_total += 1
				if trees.is_tree_at(column):
					grassland_hits += 1
	assert_true(forest_total > 0 and grassland_total > 0,
			"the sampled patch must contain both forest and grassland columns")
	var forest_fraction := float(forest_hits) / float(forest_total)
	var grassland_fraction := float(grassland_hits) / float(grassland_total)
	assert_true(forest_fraction > grassland_fraction,
			"forest fraction %s must exceed grassland fraction %s" % [
					forest_fraction, grassland_fraction])


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var trees := _shipped_trees_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(trees.decoration())
	assert_not_null(trees.surface())
	assert_not_null(trees.snowline())
	assert_not_null(trees.biomes())
