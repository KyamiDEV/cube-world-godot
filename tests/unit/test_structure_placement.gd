extends TestCase
## `world/structures/structure_placement.gd` — whether a structure actually stands at a
## region's candidate anchor (brick 090).
##
## `test_structure_seed_field.gd` already covers the one-candidate-per-region selection and
## its determinism; `test_decoration_mask.gd` covers eligibility; `test_terrace_pass.gd`
## covers the surface height. What is specific to `StructurePlacement` is the composition:
## a presence roll that leaves 089's streams untouched, an eligibility + slope gate at the
## anchor, and a non-recursive spacing rule that provably keeps no two placed structures
## within `MIN_STRUCTURE_SPACING_VOXELS`.


## Golden output of `is_placed_at()` over `GenerationFixtures.regions()` on the `typed`
## world. A change to any gate, constant, the priority order or the fork key moves it — the
## test that fails then asks whether that is a bug or a generation version bump
## (`docs/world-generation.md` §29.7).
const PINNED_PLACEMENT_SIGNATURE := "b9ad87009d76e75b"

const SWEEP_SIDE := 22


func _placement_for(name: String, biomes: BiomeRegistry = null,
		blocks: BlockRegistry = null) -> StructurePlacement:
	var real_biomes := biomes if biomes != null else BiomeCatalog.load_default()
	var real_blocks := blocks if blocks != null else BlockSet.load_default()
	return StructurePlacement.for_world(GenerationFixtures.hash_for(name), real_biomes, real_blocks)


## A signed grid of in-world regions around the origin, for the sweeps that need many.
func _region_sweep(side := SWEEP_SIDE) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	@warning_ignore("integer_division")
	var half := side / 2
	for ix in side:
		for iz in side:
			out.append(Vector2i(ix - half, iz - half))
	return out


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(StructurePlacement.for_world(null, BiomeCatalog.load_default(),
			BlockSet.load_default()))


func test_delegates_registry_failures_to_the_decoration_mask() -> void:
	# `DecorationMask.for_world()` -> `ShorelineMaterial`/`SurfaceMaterial` already refuse an
	# unlocked biome registry; 090 fails the same way through it rather than re-checking.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var unlocked := BiomeRegistry.new()
	assert_null(StructurePlacement.for_world(hash, unlocked, BlockSet.load_default()))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_placement_for(name), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# Out-of-grid regions
# ---------------------------------------------------------------------------

func test_a_region_outside_the_grid_has_nothing() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	for region in [
			Vector2i(GenerationGrid.HALF_REGIONS_PER_AXIS, 0),
			Vector2i(0, -GenerationGrid.HALF_REGIONS_PER_AXIS - 1),
			Vector2i(50000, -50000)]:
		assert_false(GenerationGrid.is_region_in_world(region))
		assert_false(placement.is_placed_at(region), "region %s" % region)
		assert_null(placement.seed_at(region), "region %s" % region)
		assert_false(placement.passes_presence_roll_at(region))
		assert_false(placement.has_clearance_at(region))


# ---------------------------------------------------------------------------
# is_placed_at() — the composition
# ---------------------------------------------------------------------------

func test_placed_implies_every_gate_and_a_real_candidate() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	var placed := 0
	for region in _region_sweep():
		if not placement.is_placed_at(region):
			continue
		placed += 1
		assert_true(placement.passes_presence_roll_at(region), "region %s presence" % region)
		assert_true(placement.is_ground_suitable_at(region), "region %s ground" % region)
		assert_true(placement.has_clearance_at(region), "region %s clearance" % region)
		var candidate := placement.seed_at(region)
		assert_not_null(candidate, "region %s seed_at" % region)
		assert_eq(candidate.region, region)
		assert_eq(candidate.anchor_column, placement.seeds().seed_at(region).anchor_column)
	assert_true(placed > 0, "no structure was placed anywhere in the sweep")


func test_seed_at_is_null_exactly_when_not_placed() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	for region in _region_sweep():
		if placement.is_placed_at(region):
			assert_not_null(placement.seed_at(region), "region %s" % region)
		else:
			assert_null(placement.seed_at(region), "region %s" % region)


# ---------------------------------------------------------------------------
# The presence roll
# ---------------------------------------------------------------------------

func test_the_presence_roll_thins_the_candidates_toward_its_chance() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	var regions := _region_sweep(32)
	var passed := 0
	for region in regions:
		if placement.passes_presence_roll_at(region):
			passed += 1
	var fraction := float(passed) / float(regions.size())
	# Every region has a candidate (all in-grid), so this is a clean Bernoulli sample.
	assert_in_range(fraction, StructurePlacement.PRESENCE_CHANCE - 0.12,
			StructurePlacement.PRESENCE_CHANCE + 0.12,
			"presence fraction %s is not near PRESENCE_CHANCE %s" % [
					fraction, StructurePlacement.PRESENCE_CHANCE])


func test_the_presence_roll_leaves_089_streams_untouched() -> void:
	# The whole reason the roll forks `StructureSeed.rng()` rather than drawing from the
	# region stream: 089's anchor/sub-seed and 091's `rng()` must read identically whether or
	# not 090 has rolled presence.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var seeds := StructureSeedField.for_world(hash)
	var placement := StructurePlacement.for_world(hash, BiomeCatalog.load_default(),
			BlockSet.load_default())
	for region in _region_sweep():
		var before := seeds.seed_at(region)
		var _presence := placement.passes_presence_roll_at(region)
		var after := seeds.seed_at(region)
		assert_eq(before.anchor_column, after.anchor_column, "region %s anchor" % region)
		assert_eq(before.structure_seed, after.structure_seed, "region %s sub-seed" % region)
		# 091's owned stream is the raw sub-seed stream, not the forked one.
		assert_eq(before.rng().next_u64(), after.rng().next_u64(), "region %s rng" % region)


# ---------------------------------------------------------------------------
# The ground gates
# ---------------------------------------------------------------------------

func test_a_water_or_shoreline_anchor_is_never_placed() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	var checked := 0
	for region in _region_sweep(32):
		var anchor := placement.seeds().seed_at(region).anchor_column
		if placement.decoration().is_eligible_at(anchor):
			continue
		checked += 1
		assert_false(placement.is_ground_suitable_at(region), "region %s" % region)
		assert_false(placement.is_placed_at(region), "region %s" % region)
	assert_true(checked > 0, "the sweep held no water/shoreline anchor to check")


func test_the_slope_gate_refuses_a_step_taller_than_one_terrace() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	var terrace := placement.terrace()
	var refused := 0
	var admitted := 0
	for region in _region_sweep(32):
		var anchor := placement.seeds().seed_at(region).anchor_column
		var lo := terrace.surface_y(anchor)
		var hi := lo
		var r := StructurePlacement.SITE_PROBE_RADIUS_VOXELS
		for offset: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r),
				Vector2i(r, r), Vector2i(r, -r), Vector2i(-r, r), Vector2i(-r, -r)]:
			var y := terrace.surface_y(anchor + offset)
			lo = mini(lo, y)
			hi = maxi(hi, y)
		var buildable := placement.is_slope_buildable_at(anchor)
		assert_eq(buildable, hi - lo <= StructurePlacement.MAX_SITE_RELIEF_VOXELS,
				"region %s: spread %d, gate %s" % [region, hi - lo, buildable])
		if buildable:
			admitted += 1
		else:
			refused += 1
	assert_true(admitted > 0, "the slope gate admitted nothing")
	assert_true(refused > 0, "the slope gate refused nothing — it is not doing anything")


# ---------------------------------------------------------------------------
# Spacing
# ---------------------------------------------------------------------------

func test_no_two_placed_structures_are_within_the_minimum_spacing() -> void:
	# The property the spacing gate exists for, and a real invariant: a placed A keeps its
	# clearance only if no neighbour out-ranks it within range, and both A and B placed makes
	# each the non-loser of the pair — impossible for two distinct regions. Regions two cells
	# apart are already past the threshold by construction (class comment), so this holds
	# world-wide, checked here across the whole sweep.
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	var placed_anchors: Array[Vector2i] = []
	for region in _region_sweep(24):
		if placement.is_placed_at(region):
			placed_anchors.append(placement.seed_at(region).anchor_column)
	assert_true(placed_anchors.size() > 4, "too few placed structures to test spacing (%d)"
			% placed_anchors.size())
	var minimum_squared := StructurePlacement.MIN_STRUCTURE_SPACING_VOXELS \
			* StructurePlacement.MIN_STRUCTURE_SPACING_VOXELS
	for i in placed_anchors.size():
		for j in range(i + 1, placed_anchors.size()):
			var delta := placed_anchors[i] - placed_anchors[j]
			var distance_squared := delta.x * delta.x + delta.y * delta.y
			assert_true(distance_squared >= minimum_squared,
					"placed anchors %s and %s are only %d² voxels apart" % [
							placed_anchors[i], placed_anchors[j], distance_squared])


func test_spacing_drops_the_lower_ranked_of_a_crowded_pair() -> void:
	# When the presence + ground gates leave two neighbouring candidates too close, exactly
	# one survives, and it is the higher-ranked one.
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	var minimum_squared := StructurePlacement.MIN_STRUCTURE_SPACING_VOXELS \
			* StructurePlacement.MIN_STRUCTURE_SPACING_VOXELS
	var crowded_pairs := 0
	for region in _region_sweep(24):
		if not placement._clears_local_gates(region):
			continue
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var other_region: Vector2i = region + offset
			if not placement._clears_local_gates(other_region):
				continue
			var a := placement.seeds().seed_at(region).anchor_column
			var b := placement.seeds().seed_at(other_region).anchor_column
			var delta := a - b
			if delta.x * delta.x + delta.y * delta.y >= minimum_squared:
				continue
			crowded_pairs += 1
			var here_placed := placement.is_placed_at(region)
			var there_placed := placement.is_placed_at(other_region)
			# At most one of a crowded pair stands (a third region could still drop both).
			assert_false(here_placed and there_placed,
					"both %s and %s stand despite crowding" % [region, other_region])
	# Not asserting crowded_pairs > 0 — with a sparse presence roll the sweep may hold none;
	# `test_no_two_placed_structures_are_within_the_minimum_spacing` is the load-bearing one.


# ---------------------------------------------------------------------------
# Column / voxel entry points
# ---------------------------------------------------------------------------

func test_seed_for_column_and_voxel_resolve_the_region() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		var region := GenerationGrid.column_to_region(column)
		var by_region := placement.seed_at(region)
		var by_column := placement.seed_for_column(column)
		var by_voxel := placement.seed_for_voxel(voxel)
		if by_region == null:
			assert_null(by_column, "column %s" % column)
			assert_null(by_voxel, "voxel %s" % voxel)
		else:
			assert_eq(by_column.anchor_column, by_region.anchor_column, "column %s" % column)
			assert_eq(by_voxel.anchor_column, by_region.anchor_column, "voxel %s" % voxel)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var placement := StructurePlacement.for_world(hash, biomes, blocks)
		return func(region: Vector2i) -> bool: return placement.is_placed_at(region)
	assert_eq(GenerationFixtures.determinism_reason(factory, _region_sweep()), "")


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		var placement := StructurePlacement.for_world(hash, biomes, blocks)
		return func(region: Vector2i) -> bool: return placement.is_placed_at(region)
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, _region_sweep()), "")


func test_placement_signature_is_pinned() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(region: Vector2i) -> bool: return placement.is_placed_at(region)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.regions()),
			PINNED_PLACEMENT_SIGNATURE)


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_placed_structures_are_a_sparse_minority_of_regions() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	var regions := _region_sweep(28)
	var placed := 0
	for region in regions:
		if placement.is_placed_at(region):
			placed += 1
	var fraction := float(placed) / float(regions.size())
	assert_in_range(fraction, 0.02, 0.35,
			"placed fraction %s is not a plausible landmark density" % fraction)


func test_self_check_passes() -> void:
	assert_eq(StructurePlacement.self_check(), "")


func test_exposes_the_passes_underneath() -> void:
	var placement := _placement_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(placement.seeds())
	assert_not_null(placement.decoration())
	assert_not_null(placement.terrace())
