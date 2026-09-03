extends TestCase
## `world/structures/structure_generator.gd` — what a placed structure is, and the ground it
## levels (brick 091).
##
## `test_structure_placement.gd` already covers which regions hold a structure at all, and
## `test_structure_site.gd` covers the record's own geometry. What is specific to the
## generator is the composition: a site resolved from the candidate's own stream, a squared
## ground falloff that levels the pad without ever moving ground more than 090's slope gate
## admitted, and a floor/wall/interior geometry whose interior is air rather than absence.


## Golden output of `site_at()` over `GenerationFixtures.regions()` on the `typed` world,
## digested through `StructureSite._to_string()` so the region, anchor, floor plane, footprint
## and wall height are all covered. A change to the draw order, the extent bounds or anything
## 089/090 feed it moves this — the test that fails then asks whether that is a bug or a
## generation version bump (`docs/world-generation.md` §30.7).
const PINNED_SITE_SIGNATURE := "7cc6db9ce157ac05"

const SWEEP_SIDE := 16


func _generator_for(name: String, blocks: BlockRegistry = null) -> StructureGenerator:
	var real_blocks := blocks if blocks != null else BlockSet.load_default()
	return StructureGenerator.for_world(GenerationFixtures.hash_for(name),
			BiomeCatalog.load_default(), real_blocks)


func _region_sweep(side := SWEEP_SIDE) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	@warning_ignore("integer_division")
	var half := side / 2
	for ix in side:
		for iz in side:
			out.append(Vector2i(ix - half, iz - half))
	return out


## The first placed site in the sweep — every geometry test needs a real one, and which one it
## is does not matter as long as it is reproducible.
func _any_site(generator: StructureGenerator) -> StructureSite:
	for region in _region_sweep():
		var site := generator.site_at(region)
		if site != null:
			return site
	return null


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(StructureGenerator.for_world(null, BiomeCatalog.load_default(),
			BlockSet.load_default()))


func test_requires_a_locked_block_registry() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(StructureGenerator.for_world(hash, BiomeCatalog.load_default(),
			BlockRegistry.new()))


func test_requires_the_structure_block() -> void:
	var empty := BlockRegistry.new()
	empty.lock()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(StructureGenerator.for_world(hash, BiomeCatalog.load_default(), empty))


func test_structure_block_reason_names_the_problem() -> void:
	assert_eq(StructureGenerator.structure_block_reason_for(BlockSet.load_default()), "")
	assert_ne(StructureGenerator.structure_block_reason_for(null), "")
	assert_ne(StructureGenerator.structure_block_reason_for(BlockRegistry.new()), "")


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_generator_for(name), "world '%s' builds" % name)


func test_shares_the_placement_passes_own_terrace() -> void:
	# Not a second instance: the levelling and 090's slope gate must agree about where the
	# ground is, and two `TerracePass` objects are two ways to disagree.
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	assert_true(generator.terrace() == generator.placement().terrace())
	assert_not_null(generator.blocks())


# ---------------------------------------------------------------------------
# Sites
# ---------------------------------------------------------------------------

func test_a_site_exists_exactly_where_a_structure_is_placed() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var placement := generator.placement()
	var placed := 0
	for region in _region_sweep():
		var site := generator.site_at(region)
		if not placement.is_placed_at(region):
			assert_null(site, "region %s" % region)
			continue
		placed += 1
		assert_not_null(site, "region %s" % region)
		assert_eq(site.region, region)
		assert_eq(site.anchor_column, placement.seed_at(region).anchor_column)
		assert_eq(site.structure_seed, placement.seed_at(region).structure_seed)
		assert_eq(site.validate(), "", "region %s validates" % region)
	assert_true(placed > 0, "no structure was placed anywhere in the sweep")


func test_a_region_outside_the_grid_has_no_site() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	for region in [Vector2i(GenerationGrid.HALF_REGIONS_PER_AXIS, 0), Vector2i(0, -70000)]:
		assert_null(generator.site_at(region), "region %s" % region)


func test_the_site_draws_stay_inside_their_stated_bounds() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var seen_extents: Dictionary = {}
	var seen_heights: Dictionary = {}
	for region in _region_sweep(24):
		var site := generator.site_at(region)
		if site == null:
			continue
		assert_in_range(float(site.half_extent_voxels),
				float(StructureGenerator.MIN_HALF_EXTENT_VOXELS),
				float(StructureGenerator.MAX_HALF_EXTENT_VOXELS), "region %s extent" % region)
		assert_in_range(float(site.wall_height_voxels),
				float(StructureGenerator.MIN_WALL_HEIGHT_VOXELS),
				float(StructureGenerator.MAX_WALL_HEIGHT_VOXELS), "region %s height" % region)
		seen_extents[site.half_extent_voxels] = true
		seen_heights[site.wall_height_voxels] = true
	# A draw that always answered the same number would be a constant, not a draw.
	assert_true(seen_extents.size() > 1, "every structure has the same footprint")
	assert_true(seen_heights.size() > 1, "every structure has the same wall height")


func test_the_floor_is_the_terrace_plane_at_the_anchor() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var terrace := generator.terrace()
	var checked := 0
	for region in _region_sweep():
		var site := generator.site_at(region)
		if site == null:
			continue
		checked += 1
		assert_eq(site.base_y, terrace.surface_y(site.anchor_column), "region %s" % region)
		assert_eq(site.base_y % TerracePass.TERRACE_HEIGHT_VOXELS, 0, "region %s" % region)
	assert_true(checked > 0, "no site to check")


func test_resolving_a_site_leaves_089_and_090_streams_untouched() -> void:
	# The site draws fork `StructureSeed.rng()` with a key of their own, for 090's reason: a
	# consumer that resolves a site must not shift the presence roll or the sub-seed.
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var placement := generator.placement()
	for region in _region_sweep():
		var candidate := placement.seeds().seed_at(region)
		var before_presence := placement.passes_presence_roll_at(region)
		var before_seed := candidate.structure_seed
		var _site := generator.site_at(region)
		assert_eq(placement.seeds().seed_at(region).structure_seed, before_seed,
				"region %s sub-seed" % region)
		assert_eq(placement.passes_presence_roll_at(region), before_presence,
				"region %s presence" % region)


# ---------------------------------------------------------------------------
# Site lookup by column
# ---------------------------------------------------------------------------

func test_site_for_column_finds_the_site_over_its_own_pad_and_nothing_else() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var site := _any_site(generator)
	assert_not_null(site, "the sweep placed no structure")
	var pad := site.half_extent_voxels + StructureGenerator.GROUND_PAD_VOXELS
	var anchor := site.anchor_column
	for distance in [0, 1, site.half_extent_voxels, pad]:
		for offset: Vector2i in [Vector2i(distance, 0), Vector2i(0, -distance),
				Vector2i(distance, distance)]:
			var found := generator.site_for_column(anchor + offset)
			assert_not_null(found, "distance %d, offset %s" % [distance, offset])
			assert_eq(found.anchor_column, anchor, "distance %d, offset %s" % [distance, offset])
	for offset: Vector2i in [Vector2i(pad + 1, 0), Vector2i(0, pad + 1), Vector2i(pad + 1, pad + 1)]:
		assert_null(generator.site_for_column(anchor + offset), "offset %s" % offset)


func test_site_for_column_crosses_a_region_boundary() -> void:
	# An anchor can sit anywhere inside its region, so a pad routinely spills into the
	# neighbour — the reason the lookup scans a 3x3 block of regions rather than one.
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var site := _any_site(generator)
	assert_not_null(site)
	var pad := site.half_extent_voxels + StructureGenerator.GROUND_PAD_VOXELS
	for offset: Vector2i in [Vector2i(pad, 0), Vector2i(-pad, 0), Vector2i(0, pad),
			Vector2i(0, -pad)]:
		var column := site.anchor_column + offset
		var found := generator.site_for_column(column)
		assert_not_null(found, "column %s (region %s vs %s)" % [
				column, GenerationGrid.column_to_region(column), site.region])
		assert_eq(found.anchor_column, site.anchor_column)


func test_site_for_voxel_drops_y() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var site := _any_site(generator)
	assert_not_null(site)
	for y in [-500, 0, site.base_y, 900]:
		var found := generator.site_for_voxel(
				Vector3i(site.anchor_column.x, y, site.anchor_column.y))
		assert_not_null(found, "y %d" % y)
		assert_eq(found.anchor_column, site.anchor_column)


# ---------------------------------------------------------------------------
# The ground falloff
# ---------------------------------------------------------------------------

func test_the_falloff_curve_is_zero_on_the_pad_and_one_outside_it() -> void:
	var site := StructureSite.new(Vector2i(0, 0), Vector2i(10, 10), 0, 5, 6, 7)
	var pad := 5 + StructureGenerator.GROUND_PAD_VOXELS
	for distance in range(0, 6):
		assert_eq(StructureGenerator.falloff_for(site, distance), 0.0, "distance %d" % distance)
	assert_eq(StructureGenerator.falloff_for(site, pad), 1.0)
	assert_eq(StructureGenerator.falloff_for(site, pad + 40), 1.0)
	# Squared, not linear: half way across the apron keeps a quarter of the natural ground.
	@warning_ignore("integer_division")
	var midpoint := 5 + StructureGenerator.GROUND_PAD_VOXELS / 2
	assert_almost_eq(StructureGenerator.falloff_for(site, midpoint), 0.25)


func test_the_falloff_curve_is_monotone_and_bounded() -> void:
	var site := StructureSite.new(Vector2i(0, 0), Vector2i(0, 0), 0, 8, 6, 7)
	var previous := -1.0
	for distance in range(0, 40):
		var value := StructureGenerator.falloff_for(site, distance)
		assert_in_range(value, 0.0, 1.0, "distance %d" % distance)
		assert_true(value >= previous, "falloff fell at distance %d" % distance)
		previous = value


func test_ground_falloff_is_one_where_no_structure_stands() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var checked := 0
	for column in GenerationFixtures.columns():
		if generator.site_for_column(column) != null:
			continue
		checked += 1
		assert_eq(generator.ground_falloff_at(column), 1.0, "column %s" % column)
		assert_eq(generator.ground_offset_at(column), 0, "column %s" % column)
	assert_true(checked > 0, "every fixture column sat under a structure")


# ---------------------------------------------------------------------------
# The levelled ground
# ---------------------------------------------------------------------------

func test_the_footprint_is_levelled_flat_to_the_floor_plane() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var site := _any_site(generator)
	assert_not_null(site)
	var half := site.half_extent_voxels
	for dx in range(-half, half + 1):
		for dz in range(-half, half + 1):
			var column := site.anchor_column + Vector2i(dx, dz)
			assert_eq(generator.surface_y_at(column), site.base_y,
					"offset (%d, %d)" % [dx, dz])


func test_the_ground_is_untouched_outside_the_pad() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var terrace := generator.terrace()
	var checked := 0
	for column in GenerationFixtures.columns():
		if generator.site_for_column(column) != null:
			continue
		checked += 1
		assert_eq(generator.surface_y_at(column), terrace.surface_y(column), "column %s" % column)
	assert_true(checked > 0)


func test_levelling_never_moves_ground_more_than_one_terrace() -> void:
	# The property `self_check()`'s pad bound exists for: 090 refused every anchor whose
	# terraced surface spans more than `MAX_SITE_RELIEF_VOXELS` across a 16-voxel pad, and this
	# pass never reaches beyond that pad — so the plateau is a levelling, not an excavation.
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var site := _any_site(generator)
	assert_not_null(site)
	var pad := site.half_extent_voxels + StructureGenerator.GROUND_PAD_VOXELS
	for dx in range(-pad, pad + 1):
		for dz in range(-pad, pad + 1):
			var column := site.anchor_column + Vector2i(dx, dz)
			var offset := generator.ground_offset_at(column)
			assert_true(absi(offset) <= StructurePlacement.MAX_SITE_RELIEF_VOXELS,
					"offset (%d, %d) moved ground by %d voxels" % [dx, dz, offset])


func test_the_levelled_ground_stays_on_terrace_planes() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var site := _any_site(generator)
	assert_not_null(site)
	var pad := site.half_extent_voxels + StructureGenerator.GROUND_PAD_VOXELS
	for dx in range(-pad - 2, pad + 3):
		var column := site.anchor_column + Vector2i(dx, 0)
		assert_eq(generator.surface_y_at(column) % TerracePass.TERRACE_HEIGHT_VOXELS, 0,
				"offset %d left the terrace grid" % dx)


# ---------------------------------------------------------------------------
# The structure itself
# ---------------------------------------------------------------------------

func test_the_parts_form_a_floor_slab_a_wall_ring_and_a_hollow_interior() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var site := _any_site(generator)
	assert_not_null(site)
	var half := site.half_extent_voxels
	var floors := 0
	var walls := 0
	var interiors := 0
	for dx in range(-half - 2, half + 3):
		for dz in range(-half - 2, half + 3):
			var column := site.anchor_column + Vector2i(dx, dz)
			var inside := maxi(absi(dx), absi(dz)) <= half
			var on_ring := maxi(absi(dx), absi(dz)) == half
			for y in range(site.base_y - 2, site.top_y() + 3):
				var voxel := Vector3i(column.x, y, column.y)
				var part := generator.part_at(voxel)
				var expected := StructureGenerator.Part.NONE
				if inside:
					if y == site.base_y:
						expected = StructureGenerator.Part.FLOOR
					elif y > site.base_y and y <= site.top_y():
						expected = StructureGenerator.Part.WALL if on_ring \
								else StructureGenerator.Part.INTERIOR
				assert_eq(part, expected, "voxel %s" % voxel)
				match part:
					StructureGenerator.Part.FLOOR: floors += 1
					StructureGenerator.Part.WALL: walls += 1
					StructureGenerator.Part.INTERIOR: interiors += 1
	var side := site.footprint_side_voxels()
	assert_eq(floors, side * side)
	assert_eq(walls, (side * side - (side - 2) * (side - 2)) * site.wall_height_voxels)
	assert_eq(interiors, (side - 2) * (side - 2) * site.wall_height_voxels)


func test_blocks_are_placed_for_floor_and_wall_only() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var site := _any_site(generator)
	assert_not_null(site)
	var half := site.half_extent_voxels
	for dx in range(-half, half + 1):
		for y in range(site.base_y, site.top_y() + 1):
			var voxel := Vector3i(site.anchor_column.x + dx, y, site.anchor_column.y)
			var part := generator.part_at(voxel)
			var solid := part == StructureGenerator.Part.FLOOR \
					or part == StructureGenerator.Part.WALL
			assert_eq(generator.is_structure_voxel_at(voxel), solid, "voxel %s" % voxel)
			assert_eq(generator.block_id_at(voxel),
					StructureGenerator.STRUCTURE_BLOCK_ID if solid else "", "voxel %s" % voxel)
			assert_eq(generator.clears_terrain_at(voxel),
					part == StructureGenerator.Part.INTERIOR, "voxel %s" % voxel)


func test_the_structure_block_is_a_block_the_registry_has() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	assert_true(generator.blocks().has_block(StructureGenerator.STRUCTURE_BLOCK_ID))


func test_nothing_is_placed_where_no_structure_stands() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var checked := 0
	for voxel in GenerationFixtures.voxels():
		if generator.site_for_voxel(voxel) != null:
			continue
		checked += 1
		assert_eq(generator.part_at(voxel), StructureGenerator.Part.NONE, "voxel %s" % voxel)
		assert_eq(generator.block_id_at(voxel), "", "voxel %s" % voxel)
		assert_false(generator.clears_terrain_at(voxel), "voxel %s" % voxel)
	assert_true(checked > 0)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var generator := StructureGenerator.for_world(hash, biomes, blocks)
		return func(region: Vector2i) -> String: return str(generator.site_at(region))
	assert_eq(GenerationFixtures.determinism_reason(factory, _region_sweep(12)), "")


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		var generator := StructureGenerator.for_world(hash, biomes, blocks)
		return func(region: Vector2i) -> String: return str(generator.site_at(region))
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, _region_sweep(12)), "")


func test_site_signature_is_pinned() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(region: Vector2i) -> String: return str(generator.site_at(region))
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.regions()),
			PINNED_SITE_SIGNATURE)


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

func test_self_check_passes() -> void:
	assert_eq(StructureGenerator.self_check(), "")


func test_exposes_the_passes_underneath() -> void:
	var generator := _generator_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(generator.placement())
	assert_not_null(generator.terrace())
	assert_not_null(generator.blocks())
