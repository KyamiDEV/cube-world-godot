extends TestCase
## `world/generation/ocean_pass.gd` — the ambient underwater coverage a river or a lake is
## not (brick 083).
##
## `test_river_pass.gd`, `test_lake_pass.gd` and `test_water_level.gd` already cover the three
## passes this file composes; nothing here re-asserts the channel mask, the basin threshold or
## the water plane on their own terms. What is specific to `OceanPass` is the combination
## itself: a column already claimed by a river or a lake must never also read as ocean, however
## deep its own ground sits, and an ordinary column's ocean status must agree with
## `WaterLevel`'s plane exactly where no river or lake claims it.

## The digest of `is_ocean_at()` over `GenerationFixtures.columns()` for the `typed` world.
## None of the 15 fixture columns reads ocean — a small-sample coincidence in the same shape
## `test_water_level.gd`'s own §19.6 already recorded for near-origin columns, not evidence the
## pass is seed-insensitive; the 2304-column sweep below is what actually measures that.
const PINNED_SIGNATURE := "8bfd8320d3e56566"

## Same sweep spacing every Phase D brick since 060 uses, so this file's own measurements are
## comparable column for column against §19.2/§20.4/§21.3.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232

## Real ocean: not a river, not a lake, and its ground sits below the plane. Found by a
## design-time sweep of the distribution below. Depth 96 voxels at this particular column, not
## a claim about ocean depth in general.
const KNOWN_OCEAN_COLUMN := Vector2i(-98232, -85953)
const KNOWN_OCEAN_COLUMN_DEPTH := 96

## Real dry land: not a river, not a lake, ground at or above the plane. Found by the same
## sweep.
const KNOWN_DRY_COLUMN := Vector2i(-98232, -98232)

## A real river column (`RiverPass.is_river_at()` true) whose *raw, uncarved* `TerracePass`
## surface already sits below `WaterLevel.SEA_LEVEL_VOXELS` — found by the same sweep. The
## property this column exists to exercise: the exclusion must win even where the column would
## otherwise read as ocean by its raw height alone.
const KNOWN_RIVER_ALSO_RAW_UNDERWATER_COLUMN := Vector2i(94139, 69581)

## `test_river_pass.gd::KNOWN_RIVER_COLUMN`, reused rather than re-swept: an ordinary in-channel
## river column, well clear of the water plane.
const KNOWN_RIVER_COLUMN := Vector2i(-73674, -36837)

## `test_lake_pass.gd::KNOWN_LAKE_COLUMN`, reused rather than re-swept: an ordinary lake basin
## column.
const KNOWN_LAKE_COLUMN := Vector2i(-94139, -24558)


func _ocean_for(name: String) -> OceanPass:
	return OceanPass.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var ocean := OceanPass.for_world(hash)
		return func(column: Vector2i) -> bool: return ocean.is_ocean_at(column)


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
	assert_null(OceanPass.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_ocean_for(name), "world '%s' has an ocean pass" % name)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory: Callable = _sampler_factory()
	assert_eq(GenerationFixtures.determinism_reason(factory.bind(hash),
			GenerationFixtures.columns()), "")


func test_signature_is_pinned() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> bool: return ocean.is_ocean_at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


## `GenerationFixtures.columns()` reads ocean nowhere on the `typed` world (see
## `PINNED_SIGNATURE`'s own comment), so seed sensitivity needs the wider sweep the same way
## `test_water_level.gd::test_is_seed_sensitive` already did for the identical reason.
func test_is_seed_sensitive() -> void:
	var factory := func(hash: GenerationHash) -> Callable:
		var ocean := OceanPass.for_world(hash)
		return func(column: Vector2i) -> bool: return ocean.is_ocean_at(column)
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, _sweep_columns()), "")


# ---------------------------------------------------------------------------
# The exclusion — the property no shared fixture check can see
# ---------------------------------------------------------------------------

func test_a_river_column_never_reads_as_ocean() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	assert_true(ocean.river().is_river_at(KNOWN_RIVER_COLUMN),
			"fixture column is no longer a river; pick a new one")
	assert_true(ocean.is_river_or_lake_at(KNOWN_RIVER_COLUMN))
	assert_false(ocean.is_ocean_at(KNOWN_RIVER_COLUMN))
	assert_eq(ocean.ocean_depth_at(KNOWN_RIVER_COLUMN), 0)


func test_a_lake_column_never_reads_as_ocean() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	assert_true(ocean.lake().is_lake_at(KNOWN_LAKE_COLUMN),
			"fixture column is no longer a lake; pick a new one")
	assert_true(ocean.is_river_or_lake_at(KNOWN_LAKE_COLUMN))
	assert_false(ocean.is_ocean_at(KNOWN_LAKE_COLUMN))
	assert_eq(ocean.ocean_depth_at(KNOWN_LAKE_COLUMN), 0)


func test_a_river_column_never_reads_as_ocean_even_when_already_underwater() -> void:
	# The property the class comment's "exclusion always runs first" section names directly:
	# this column's raw, uncarved TerracePass surface already sits below SEA_LEVEL_VOXELS, so
	# the water-plane comparison alone would call it ocean. The exclusion must still win.
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	var column := KNOWN_RIVER_ALSO_RAW_UNDERWATER_COLUMN
	assert_true(ocean.river().is_river_at(column),
			"fixture column is no longer a river; pick a new one")
	var raw_surface_y := ocean.river().terrace().surface_y(column)
	assert_true(ocean.water().is_underwater_for(raw_surface_y),
			"fixture column's raw terrace is no longer underwater; pick a new one")
	assert_false(ocean.is_ocean_at(column))
	assert_eq(ocean.ocean_depth_at(column), 0)


func test_an_ordinary_ocean_column_reads_ocean() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	assert_false(ocean.is_river_or_lake_at(KNOWN_OCEAN_COLUMN),
			"fixture column is no longer clear of river/lake; pick a new one")
	assert_true(ocean.is_ocean_at(KNOWN_OCEAN_COLUMN))
	assert_eq(ocean.ocean_depth_at(KNOWN_OCEAN_COLUMN), KNOWN_OCEAN_COLUMN_DEPTH)


func test_an_ordinary_dry_column_reads_no_ocean() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	assert_false(ocean.is_river_or_lake_at(KNOWN_DRY_COLUMN),
			"fixture column is no longer clear of river/lake; pick a new one")
	assert_false(ocean.is_ocean_at(KNOWN_DRY_COLUMN))
	assert_eq(ocean.ocean_depth_at(KNOWN_DRY_COLUMN), 0)


func test_agrees_with_the_water_plane_wherever_no_river_or_lake_claims_the_column() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_OCEAN_COLUMN)
	columns.append(KNOWN_DRY_COLUMN)
	columns.append(KNOWN_RIVER_COLUMN)
	columns.append(KNOWN_LAKE_COLUMN)
	columns.append(KNOWN_RIVER_ALSO_RAW_UNDERWATER_COLUMN)
	for column in columns:
		var expected := false
		if not ocean.is_river_or_lake_at(column):
			expected = ocean.water().is_underwater_for(ocean.lake().surface_y(column))
		assert_eq(ocean.is_ocean_at(column), expected, "column %s" % column)
		var expected_depth := 0
		if expected:
			expected_depth = ocean.water().depth_for(ocean.lake().surface_y(column))
		assert_eq(ocean.ocean_depth_at(column), expected_depth, "column %s" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		assert_eq(ocean.is_ocean_at_voxel(voxel), ocean.is_ocean_at(column),
				"voxel %s reads its column" % voxel)
		assert_eq(ocean.ocean_depth_at_voxel(voxel), ocean.ocean_depth_at(column),
				"voxel %s reads its column" % voxel)


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_ocean_is_a_large_contiguous_share_of_the_world_unlike_a_river_or_a_lake() -> void:
	# The claim of the brick: ocean is the opposite shape from a river (1.65%) or a lake
	# (1.82%, both §20.4/§21.3) — a majority-scale share of the world, not a rare, findable
	# feature. Measured at the shipped constants over the 2304-column sweep: ocean 47.9%,
	# river-or-lake 3.5%. Banded with headroom, `RiverPass`/`LakePass`'s own precedent for
	# asserting a measured property rather than pinning the exact figure.
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	var columns := _sweep_columns()
	var ocean_count := 0
	var river_or_lake_count := 0
	for column in columns:
		if ocean.is_ocean_at(column):
			ocean_count += 1
		if ocean.is_river_or_lake_at(column):
			river_or_lake_count += 1
	var ocean_fraction := float(ocean_count) / float(columns.size())
	var river_or_lake_fraction := float(river_or_lake_count) / float(columns.size())
	assert_in_range(ocean_fraction, 0.3, 0.7,
			"ocean fraction %s is not a large share of the world" % ocean_fraction)
	assert_true(river_or_lake_fraction < 0.1,
			"river-or-lake fraction %s is no longer a small minority" % river_or_lake_fraction)
	assert_true(ocean_fraction > river_or_lake_fraction * 5.0,
			"ocean no longer reads as a substantially larger share of the world than a river or lake")


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(ocean.lake())
	assert_not_null(ocean.river())
	assert_not_null(ocean.water())


func test_river_accessor_matches_the_one_reached_through_lake() -> void:
	var ocean := _ocean_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(ocean.river(), ocean.lake().river())
