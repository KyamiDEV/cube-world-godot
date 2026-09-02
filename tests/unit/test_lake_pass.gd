extends TestCase
## `world/generation/lake_pass.gd` — a lake basin's local lowering of the river-clipped
## ground (brick 082).
##
## `test_river_pass.gd` already covers the pass underneath; nothing here re-asserts the
## channel/terrace machinery. What is specific to `LakePass` is the opposite-tail threshold
## on the same channel distance (far from the contour instead of close to it — a blob instead
## of a band) and the clip it drives, the same split `test_cave_mask.gd`/`test_cave_carving.gd`
## and `test_river_pass.gd` itself already established across two bricks each.

## The digest of `channel_distance_at()` over `GenerationFixtures.columns()` for the `typed`
## world. **Identical to `RiverPass`'s own `PINNED_DISTANCE_SIGNATURE`** — not a copy/paste
## mistake: `LakePass.channel_distance_at()` delegates straight through to the `RiverPass` it
## holds, reading the exact same layer, so the two passes answer identically at every column
## neither one carves. `test_uses_the_same_layer_river_pass_does` asserts the delegation
## directly rather than leaving the matching digest as the only evidence.
const PINNED_DISTANCE_SIGNATURE := "71d53280c3e89764"

## The digest of `at()` over the same columns. Identical to `RiverPass`'s own
## `PINNED_AT_SIGNATURE`, for the same small-sample-vs-sparse-field reason `test_river_pass.gd`
## already recorded for its own match against `TerracePass`: none of `GenerationFixtures.
## columns()`'s 15 samples lands within `LAKE_MIN_DISTANCE` of the channel layer's own zero
## contour (measured 2.34% of the world, `docs/world-generation.md` §21.3), so `LakePass`
## answers exactly what `RiverPass` already does at every one of them.
## `KNOWN_LAKE_COLUMN` below is what actually exercises the clip.
const PINNED_AT_SIGNATURE := "2af464f70e43590a"

## Distance sweep, same shape and spacing as `test_river_pass.gd`'s, so this file's own
## distribution measurement is comparable column for column.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232

## In a lake basin and under the lowland ceiling: `is_lake_at()` true, found by a design-time
## sweep of the distribution above (`docs/world-generation.md` §21.3). Terraced height 0 — the
## sea-level datum itself, an honest coincidence of this particular column, not a claim that
## every lake sits there.
const KNOWN_LAKE_COLUMN := Vector2i(-94139, -24558)

## In a lake basin but above the lowland ceiling: `is_basin_at()` true, `is_lake_at()` false —
## the case that proves the ceiling gate is load-bearing rather than a pass-through, found by
## the same sweep.
const KNOWN_LAKE_ABOVE_CEILING_COLUMN := Vector2i(-94139, -98232)


func _pass_for(name: String) -> LakePass:
	return LakePass.for_world(GenerationFixtures.hash_for(name))


func _distance_sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var lake := LakePass.for_world(hash)
		return func(column: Vector2i) -> float: return lake.channel_distance_at(column)


## Every column of the distribution sweep, as a plain list.
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
	assert_null(LakePass.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_pass_for(name), "world '%s' has a lake pass" % name)


# ---------------------------------------------------------------------------
# The basin mask
# ---------------------------------------------------------------------------

func test_channel_distance_is_deterministic() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory: Callable = _distance_sampler_factory()
	assert_eq(GenerationFixtures.determinism_reason(factory.bind(hash),
			GenerationFixtures.columns()), "")


func test_channel_distance_is_seed_sensitive() -> void:
	assert_eq(GenerationFixtures.seed_sensitivity_reason(_distance_sampler_factory(),
			GenerationFixtures.columns()), "")


func test_channel_distance_is_in_range() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return lake.channel_distance_at(column)
	assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.columns(), 0.0, 1.0),
			"")


func test_uses_the_same_layer_river_pass_does() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var river := RiverPass.for_world(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	for column in GenerationFixtures.columns():
		assert_almost_eq(lake.channel_distance_at(column), river.channel_distance_at(column),
				1e-12, "column %s" % column)


func test_distance_signature_is_pinned() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return lake.channel_distance_at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_DISTANCE_SIGNATURE)


func test_a_river_column_is_never_a_lake_basin_column() -> void:
	# LAKE_MIN_DISTANCE and RiverPass.CHANNEL_HALF_WIDTH are disjoint by construction
	# (self_check() asserts the relationship); this is that property exercised at a real
	# in-channel column rather than only asserted about the constants.
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var river := RiverPass.for_world(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	var columns := _sweep_columns()
	var checked_a_channel_column := false
	for column in columns:
		if river.is_channel_at(column):
			checked_a_channel_column = true
			assert_false(lake.is_basin_at(column),
					"channel column %s also reads as a lake basin" % column)
	assert_true(checked_a_channel_column, "sweep found no channel column to check against")


# ---------------------------------------------------------------------------
# The clip
# ---------------------------------------------------------------------------

func test_at_signature_is_pinned() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return lake.at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_AT_SIGNATURE)


func test_a_basin_column_under_the_ceiling_carves_one_riser() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_true(lake.is_basin_at(KNOWN_LAKE_COLUMN),
			"fixture column is no longer in a basin; pick a new one")
	assert_true(lake.is_lake_at(KNOWN_LAKE_COLUMN))
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	assert_almost_eq(lake.at(KNOWN_LAKE_COLUMN),
			lake.river().at(KNOWN_LAKE_COLUMN) - height, 1e-12)
	assert_eq(lake.surface_y(KNOWN_LAKE_COLUMN),
			lake.river().surface_y(KNOWN_LAKE_COLUMN) - LakePass.CARVE_DEPTH_VOXELS)


func test_a_basin_column_above_the_ceiling_stays_uncarved() -> void:
	# The property the ceiling exists for: LAKE_MIN_DISTANCE alone would call this column a
	# lake, but its terraced ground sits above LAKE_CEILING_VOXELS, so it must not carve.
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_true(lake.is_basin_at(KNOWN_LAKE_ABOVE_CEILING_COLUMN),
			"fixture column is no longer in a basin; pick a new one")
	assert_true(lake.river().terrace().at(KNOWN_LAKE_ABOVE_CEILING_COLUMN)
			> LakePass.LAKE_CEILING_VOXELS,
			"fixture column is no longer above the ceiling; pick a new one")
	assert_false(lake.is_lake_at(KNOWN_LAKE_ABOVE_CEILING_COLUMN))
	assert_almost_eq(lake.at(KNOWN_LAKE_ABOVE_CEILING_COLUMN),
			lake.river().at(KNOWN_LAKE_ABOVE_CEILING_COLUMN), 1e-12)


func test_a_dry_column_is_unaffected() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_false(lake.is_lake_at(column), "column %s reads as a lake" % column)
		assert_almost_eq(lake.at(column), lake.river().at(column), 1e-12, "column %s" % column)


func test_agrees_with_the_clip_at_every_sample_column() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var river := lake.river()
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_LAKE_COLUMN)
	columns.append(KNOWN_LAKE_ABOVE_CEILING_COLUMN)
	for column in columns:
		var expected_lake := (lake.channel_distance_at(column) > LakePass.LAKE_MIN_DISTANCE
				and river.terrace().at(column) <= LakePass.LAKE_CEILING_VOXELS)
		assert_eq(lake.is_lake_at(column), expected_lake, "column %s" % column)
		var expected_surface := river.surface_y(column)
		if expected_lake:
			expected_surface -= LakePass.CARVE_DEPTH_VOXELS
		assert_eq(lake.surface_y(column), expected_surface, "column %s" % column)


func test_surface_y_stays_terrace_aligned() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_LAKE_COLUMN)
	columns.append(KNOWN_LAKE_ABOVE_CEILING_COLUMN)
	for column in columns:
		assert_eq(lake.surface_y(column) % TerracePass.TERRACE_HEIGHT_VOXELS, 0,
				"column %s is not on a terrace plane" % column)


func test_never_raises_the_ground() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_LAKE_COLUMN)
	columns.append(KNOWN_LAKE_ABOVE_CEILING_COLUMN)
	for column in columns:
		assert_true(lake.surface_y(column) <= lake.river().surface_y(column),
				"column %s was raised" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(lake.at_voxel(voxel),
				lake.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


func test_at_metres_is_the_voxel_height_converted() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_almost_eq(lake.at_metres(column),
				WorldScale.voxels_to_metres(lake.at(column)), 1e-9)


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_the_basin_covers_a_small_minority_of_the_world() -> void:
	# The claim of the brick, the same shape as CaveMask's own §16.4 measurement and
	# RiverPass's own §20.4 one: lakes are meant to be rare, findable features. Measured at
	# LAKE_MIN_DISTANCE over the 2304-column sweep: basin 2.34%, lake (basin and under the
	# ceiling) 1.82%. Banded with headroom, RiverPass's own precedent for asserting a measured
	# property rather than pinning the exact figure.
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	var columns := _sweep_columns()
	var basin := 0
	var is_lake := 0
	for column in columns:
		if lake.is_basin_at(column):
			basin += 1
		if lake.is_lake_at(column):
			is_lake += 1
	var basin_fraction := float(basin) / float(columns.size())
	var lake_fraction := float(is_lake) / float(columns.size())
	assert_in_range(basin_fraction, 0.005, 0.08,
			"basin fraction %s is not a small minority" % basin_fraction)
	assert_in_range(lake_fraction, 0.003, 0.06,
			"lake fraction %s is not a small minority" % lake_fraction)
	assert_true(lake_fraction <= basin_fraction,
			"the ceiling gate can only ever remove lake columns, never add them")


func test_max_riser_voxels_is_one_more_than_the_river_pass_beneath_it() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_almost_eq(lake.max_riser_voxels(),
			lake.river().max_riser_voxels() + float(TerracePass.TERRACE_HEIGHT_VOXELS),
			1e-12)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_pass_underneath() -> void:
	var lake := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(lake.river())


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

func test_self_check_passes() -> void:
	assert_eq(LakePass.self_check(), "")
