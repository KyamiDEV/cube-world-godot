extends TestCase
## `world/generation/decoration_mask.gd` — which columns may host natural decoration at all,
## and which ones are a candidate placement point at a given spacing (brick 086).
##
## `test_shoreline_material.gd` already covers wet/shoreline classification on its own
## terms; nothing here re-asserts it. What is specific to `DecorationMask` is the two things
## it adds on top: the eligibility exclusion reused rather than re-decided, and the
## spacing/cell/anchor mechanism that has no other test coverage anywhere else.


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


func _decoration_for(name: String, biomes: BiomeRegistry, blocks: BlockRegistry) -> DecorationMask:
	return DecorationMask.for_world(GenerationFixtures.hash_for(name), biomes, blocks)


## `test_shoreline_material.gd::KNOWN_WATER_COLUMN`, reused rather than re-swept.
const KNOWN_WATER_COLUMN := Vector2i(-98232, -85953)

## `test_shoreline_material.gd::KNOWN_SHORELINE_COLUMN`, reused rather than re-swept.
const KNOWN_SHORELINE_COLUMN := Vector2i(-94296, -94139)

## `test_shoreline_material.gd::KNOWN_INLAND_COLUMN`, reused rather than re-swept: dry, and
## not adjacent to water either.
const KNOWN_INLAND_COLUMN := Vector2i(-98232, -98232)


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(DecorationMask.for_world(null, _complete_biomes(), _small_blocks()))


func test_delegates_binding_failures_to_shoreline_material() -> void:
	# `ShorelineMaterial.for_world()` already refuses a block registry without its own fixed
	# shore block; 086 does not re-implement that, it just fails the same way through the
	# same call.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var blocks_without_sand := BlockRegistry.new()
	for id in ["block.grass", "block.dirt", "block.stone"]:
		var definition := BlockDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.texture_top = "res://assets/textures/blocks/grass_top.png"
		definition.texture_side = "res://assets/textures/blocks/grass_side.png"
		definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
		definition.footstep_tag = "stone"
		blocks_without_sand.register_block(definition)
	blocks_without_sand.lock()
	assert_null(DecorationMask.for_world(hash, _complete_biomes(), blocks_without_sand))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		assert_not_null(_decoration_for(name, biomes, blocks), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# Eligibility
# ---------------------------------------------------------------------------

func test_a_water_column_is_not_eligible() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(decoration.shoreline().is_water_at(KNOWN_WATER_COLUMN),
			"fixture column is no longer water; pick a new one")
	assert_false(decoration.is_eligible_at(KNOWN_WATER_COLUMN))


func test_a_shoreline_column_is_not_eligible() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(decoration.shoreline().is_shoreline_at(KNOWN_SHORELINE_COLUMN),
			"fixture column is no longer a shoreline column; pick a new one")
	assert_false(decoration.is_eligible_at(KNOWN_SHORELINE_COLUMN))


func test_an_ordinary_inland_column_is_eligible() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_false(decoration.shoreline().is_water_at(KNOWN_INLAND_COLUMN),
			"fixture column is no longer dry; pick a new one")
	assert_false(decoration.shoreline().is_shoreline_at(KNOWN_INLAND_COLUMN),
			"fixture column is no longer inland; pick a new one")
	assert_true(decoration.is_eligible_at(KNOWN_INLAND_COLUMN))


func test_eligibility_agrees_with_the_underlying_classification() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	for column in GenerationFixtures.columns():
		var expected := not (decoration.shoreline().is_water_at(column)
				or decoration.shoreline().is_shoreline_at(column))
		assert_eq(decoration.is_eligible_at(column), expected, "column %s" % column)


func test_a_voxel_reads_its_own_column_for_eligibility() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		assert_eq(decoration.is_eligible_at_voxel(voxel), decoration.is_eligible_at(column),
				"voxel %s reads its column" % voxel)


# ---------------------------------------------------------------------------
# spacing_for_density()
# ---------------------------------------------------------------------------

func test_spacing_for_density_is_zero_for_a_disabled_density() -> void:
	assert_eq(DecorationMask.spacing_for_density(0.0), 0)
	assert_eq(DecorationMask.spacing_for_density(-1.0), 0)


func test_spacing_for_density_follows_the_inverse_square_root() -> void:
	assert_eq(DecorationMask.spacing_for_density(1.0), 1)
	assert_eq(DecorationMask.spacing_for_density(0.25), 2)
	assert_eq(DecorationMask.spacing_for_density(0.01), 10)
	assert_eq(DecorationMask.spacing_for_density(1.0 / 64.0), 8)


func test_spacing_for_density_never_returns_less_than_one_for_a_positive_density() -> void:
	assert_eq(DecorationMask.spacing_for_density(100.0), 1)


# ---------------------------------------------------------------------------
# cell_of()
# ---------------------------------------------------------------------------

func test_cell_of_floors_toward_negative_infinity() -> void:
	assert_eq(DecorationMask.cell_of(Vector2i(0, 0), 10), Vector2i(0, 0))
	assert_eq(DecorationMask.cell_of(Vector2i(9, 9), 10), Vector2i(0, 0))
	assert_eq(DecorationMask.cell_of(Vector2i(10, 10), 10), Vector2i(1, 1))
	assert_eq(DecorationMask.cell_of(Vector2i(-1, -1), 10), Vector2i(-1, -1))
	assert_eq(DecorationMask.cell_of(Vector2i(-10, -10), 10), Vector2i(-1, -1))
	assert_eq(DecorationMask.cell_of(Vector2i(-11, -11), 10), Vector2i(-2, -2))


# ---------------------------------------------------------------------------
# Anchoring
# ---------------------------------------------------------------------------

func test_is_anchor_at_is_always_false_for_a_disabled_spacing() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_false(decoration.is_anchor_at(KNOWN_INLAND_COLUMN, 0, WorldHash.SALT_TREES))
	assert_false(decoration.is_anchor_at(KNOWN_INLAND_COLUMN, -5, WorldHash.SALT_TREES))


func test_anchor_column_in_cell_stays_inside_the_cell() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var spacing := 8
	for cell in [Vector2i(0, 0), Vector2i(-3, 5), Vector2i(-1, -1)]:
		var anchor := decoration.anchor_column_in_cell(cell, spacing, WorldHash.SALT_TREES)
		assert_eq(DecorationMask.cell_of(anchor, spacing), cell,
				"anchor %s is not inside cell %s" % [anchor, cell])


func test_anchor_column_in_cell_is_deterministic() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var cell := Vector2i(4, -7)
	var first := decoration.anchor_column_in_cell(cell, 8, WorldHash.SALT_TREES)
	var second := decoration.anchor_column_in_cell(cell, 8, WorldHash.SALT_TREES)
	assert_eq(first, second)


func test_a_different_salt_picks_a_different_anchor_stream() -> void:
	# Not guaranteed to land on a different column for every cell, but pinned against the
	# shipped seed/cell/spacing below: proof the salt actually reaches the draw rather than
	# being ignored.
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var cell := Vector2i(4, -7)
	var trees := decoration.anchor_column_in_cell(cell, 8, WorldHash.SALT_TREES)
	var props := decoration.anchor_column_in_cell(cell, 8, WorldHash.SALT_PROPS)
	assert_ne(trees, props,
			"WorldHash.SALT_TREES and WorldHash.SALT_PROPS picked the same anchor at cell %s; "
			+ "pick a different cell to prove the salt reaches the draw")


func test_exactly_one_column_in_a_cell_is_an_anchor() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var spacing := 8
	var cell := Vector2i(-3, 5)
	var anchor_count := 0
	for ix in spacing:
		for iz in spacing:
			var column := Vector2i(cell.x * spacing + ix, cell.y * spacing + iz)
			if decoration.is_anchor_at(column, spacing, WorldHash.SALT_TREES):
				anchor_count += 1
	assert_eq(anchor_count, 1)


func test_is_decoration_anchor_at_requires_both_eligibility_and_anchoring() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var spacing := 8
	var salt := WorldHash.SALT_TREES
	# The known water column can never be a decoration anchor, whatever the cell's own chosen
	# candidate happens to be.
	assert_false(decoration.is_decoration_anchor_at(KNOWN_WATER_COLUMN, spacing, salt))


func test_is_decoration_anchor_at_agrees_with_the_combination() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var spacing := 8
	var salt := WorldHash.SALT_TREES
	var origin := Vector2i(-94232, -94232)
	var side := 64
	for ix in side:
		for iz in side:
			var column := origin + Vector2i(ix, iz)
			var expected := decoration.is_eligible_at(column) and decoration.is_anchor_at(
					column, spacing, salt)
			assert_eq(decoration.is_decoration_anchor_at(column, spacing, salt), expected,
					"column %s" % column)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_eligibility_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var decoration := DecorationMask.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> bool: return decoration.is_eligible_at(column)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_anchoring_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var decoration := DecorationMask.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> bool:
			return decoration.is_decoration_anchor_at(column, 8, WorldHash.SALT_TREES)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		var decoration := DecorationMask.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> bool:
			return decoration.is_anchor_at(column, 8, WorldHash.SALT_TREES)
	var samples: Array[Vector2i] = []
	var origin := Vector2i(-100, -100)
	for ix in 40:
		for iz in 40:
			samples.append(origin + Vector2i(ix, iz))
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, samples), "")


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

## The raw anchor rate (before eligibility) over a real patch matches the requested spacing's
## own density, banded with headroom rather than pinned exactly — `SnowlineMaterial`'s own
## precedent for asserting a measured property instead of an exact figure that would break on
## every unrelated upstream change.
func test_anchor_density_matches_the_requested_spacing() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var spacing := 8
	var origin := Vector2i(-94232, -94232)
	var side := 400
	var anchor_count := 0
	for ix in side:
		for iz in side:
			if decoration.is_anchor_at(origin + Vector2i(ix, iz), spacing, WorldHash.SALT_TREES):
				anchor_count += 1
	var expected := float(side * side) / float(spacing * spacing)
	var fraction := float(anchor_count) / expected
	assert_in_range(fraction, 0.5, 1.5,
			"anchor count %d is not within 50%% of the expected %s for spacing %d"
			% [anchor_count, expected, spacing])


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_pass_underneath() -> void:
	var decoration := _decoration_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_not_null(decoration.shoreline())
