extends TestCase
## `world/generation/river_pass.gd` — a river channel's local lowering of the terraced
## ground (brick 081).
##
## `test_terrace_pass.gd` already covers the pass underneath; nothing here re-asserts the
## terracing itself. What is specific to `RiverPass` is the channel layer (a distance from a
## noise contour, not a threshold on it) and the clip it drives (one riser removed, only
## where the channel crosses lowland ground) — the same split `test_cave_mask.gd` and
## `test_cave_carving.gd` cover across two bricks, here inside one.

## The digest of `channel_distance_at()` over `GenerationFixtures.columns()` for the `typed`
## world.
const PINNED_DISTANCE_SIGNATURE := "71d53280c3e89764"

## The digest of `at()` over the same columns. Identical to `TerracePass`'s own pinned
## signature (`test_terrace_pass.gd`'s `2af464f70e43590a`) — not a copy/paste mistake. Every
## one of `GenerationFixtures.columns()`'s 15 samples is a near-origin, cell-boundary or
## world-corner coordinate, and the channel covers roughly 1.6% of the world
## (`docs/world-generation.md` §20.4); none of the 15 happens to land on one, so `RiverPass`
## answers exactly what `TerracePass` already does at every one of them. The same "too small
## a sample to land on a sparse field" finding `test_cave_mask.gd` and `test_underground_
## material.gd` already recorded, not re-argued here — `KNOWN_RIVER_COLUMN` below is what
## actually exercises the clip.
const PINNED_AT_SIGNATURE := "2af464f70e43590a"

## Distance sweep, same shape and spacing as `test_terrace_pass.gd`'s, so this file's own
## distribution measurement is comparable column for column.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232

## In the channel and under the lowland ceiling: `is_river_at()` true, found by a design-time
## sweep of the distribution above (`docs/world-generation.md` §20.4). Terraced height 56, one
## riser above the datum — dry land, and a worked case for the honest limitation the class
## comment states: the carve does not reach `WaterLevel.SEA_LEVEL_VOXELS` here, because the
## surrounding lowland does not sit that low to begin with.
const KNOWN_RIVER_COLUMN := Vector2i(-73674, -36837)

## In the channel but above the lowland ceiling: `is_channel_at()` true, `is_river_at()` false
## — the case that proves the ceiling gate is load-bearing rather than a pass-through, found
## by the same sweep.
const KNOWN_CHANNEL_ABOVE_CEILING_COLUMN := Vector2i(-94139, 8186)


func _pass_for(name: String) -> RiverPass:
	return RiverPass.for_world(GenerationFixtures.hash_for(name))


func _distance_sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var river := RiverPass.for_world(hash)
		return func(column: Vector2i) -> float: return river.channel_distance_at(column)


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
	assert_null(RiverPass.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_pass_for(name), "world '%s' has a river pass" % name)


# ---------------------------------------------------------------------------
# The channel layer
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
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return river.channel_distance_at(column)
	assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.columns(), 0.0, 1.0),
			"")


func test_uses_its_own_salt() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(river.channel_noise().salt(), WorldHash.SALT_RIVERS)
	for other in [WorldHash.SALT_ELEVATION, WorldHash.SALT_TEMPERATURE,
			WorldHash.SALT_HUMIDITY, WorldHash.SALT_CAVES, WorldHash.SALT_CONTINENTALNESS,
			WorldHash.SALT_RUGGEDNESS, WorldHash.SALT_SURFACE_MATERIAL]:
		assert_ne(WorldHash.SALT_RIVERS, other)


func test_distance_signature_is_pinned() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return river.channel_distance_at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_DISTANCE_SIGNATURE)


# ---------------------------------------------------------------------------
# The clip
# ---------------------------------------------------------------------------

func test_at_signature_is_pinned() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return river.at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_AT_SIGNATURE)


func test_a_channel_column_under_the_ceiling_carves_one_riser() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_true(river.is_channel_at(KNOWN_RIVER_COLUMN),
			"fixture column is no longer in the channel; pick a new one")
	assert_true(river.is_river_at(KNOWN_RIVER_COLUMN))
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	assert_almost_eq(river.at(KNOWN_RIVER_COLUMN),
			river.terrace().at(KNOWN_RIVER_COLUMN) - height, 1e-12)
	assert_eq(river.surface_y(KNOWN_RIVER_COLUMN),
			river.terrace().surface_y(KNOWN_RIVER_COLUMN) - TerracePass.TERRACE_HEIGHT_VOXELS)


func test_a_channel_column_above_the_ceiling_stays_uncarved() -> void:
	# The property the ceiling exists for: CHANNEL_HALF_WIDTH alone would call this column a
	# river, but its terraced ground sits above RIVER_CEILING_VOXELS, so it must not carve.
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_true(river.is_channel_at(KNOWN_CHANNEL_ABOVE_CEILING_COLUMN),
			"fixture column is no longer in the channel; pick a new one")
	assert_true(river.terrace().at(KNOWN_CHANNEL_ABOVE_CEILING_COLUMN)
			> RiverPass.RIVER_CEILING_VOXELS,
			"fixture column is no longer above the ceiling; pick a new one")
	assert_false(river.is_river_at(KNOWN_CHANNEL_ABOVE_CEILING_COLUMN))
	assert_almost_eq(river.at(KNOWN_CHANNEL_ABOVE_CEILING_COLUMN),
			river.terrace().at(KNOWN_CHANNEL_ABOVE_CEILING_COLUMN), 1e-12)


func test_a_dry_column_is_unaffected() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_false(river.is_river_at(column), "column %s reads as a river" % column)
		assert_almost_eq(river.at(column), river.terrace().at(column), 1e-12,
				"column %s" % column)


func test_agrees_with_the_clip_at_every_sample_column() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	var terrace := river.terrace()
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_RIVER_COLUMN)
	columns.append(KNOWN_CHANNEL_ABOVE_CEILING_COLUMN)
	for column in columns:
		var expected_river := (river.channel_distance_at(column) < RiverPass.CHANNEL_HALF_WIDTH
				and terrace.at(column) <= RiverPass.RIVER_CEILING_VOXELS)
		assert_eq(river.is_river_at(column), expected_river, "column %s" % column)
		var expected_surface := terrace.surface_y(column)
		if expected_river:
			expected_surface -= RiverPass.CARVE_DEPTH_VOXELS
		assert_eq(river.surface_y(column), expected_surface, "column %s" % column)


func test_surface_y_stays_terrace_aligned() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_RIVER_COLUMN)
	columns.append(KNOWN_CHANNEL_ABOVE_CEILING_COLUMN)
	for column in columns:
		assert_eq(river.surface_y(column) % TerracePass.TERRACE_HEIGHT_VOXELS, 0,
				"column %s is not on a terrace plane" % column)


func test_never_raises_the_ground() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	var columns := GenerationFixtures.columns()
	columns.append(KNOWN_RIVER_COLUMN)
	columns.append(KNOWN_CHANNEL_ABOVE_CEILING_COLUMN)
	for column in columns:
		assert_true(river.surface_y(column) <= river.terrace().surface_y(column),
				"column %s was raised" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(river.at_voxel(voxel),
				river.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


func test_at_metres_is_the_voxel_height_converted() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_almost_eq(river.at_metres(column),
				WorldScale.voxels_to_metres(river.at(column)), 1e-9)


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_the_channel_covers_a_small_minority_of_the_world() -> void:
	# The claim of the brick, the same shape as `CaveMask`'s own §16.4 measurement: rivers are
	# meant to be rare, findable features, not a large fraction of the map. Measured at
	# CHANNEL_HALF_WIDTH over the 2304-column sweep: channel 2.69%, river (channel and under
	# the ceiling) 1.65%. Banded with headroom, `WaterLevel`'s own precedent for asserting a
	# measured property rather than pinning the exact figure.
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	var columns := _sweep_columns()
	var channel := 0
	var is_river := 0
	for column in columns:
		if river.is_channel_at(column):
			channel += 1
		if river.is_river_at(column):
			is_river += 1
	var channel_fraction := float(channel) / float(columns.size())
	var river_fraction := float(is_river) / float(columns.size())
	assert_in_range(channel_fraction, 0.005, 0.08,
			"channel fraction %s is not a small minority" % channel_fraction)
	assert_in_range(river_fraction, 0.003, 0.06,
			"river fraction %s is not a small minority" % river_fraction)
	assert_true(river_fraction <= channel_fraction,
			"the ceiling gate can only ever remove river columns, never add them")


func test_max_riser_voxels_is_one_more_than_the_terrace_beneath_it() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_almost_eq(river.max_riser_voxels(),
			river.terrace().max_riser_voxels() + float(TerracePass.TERRACE_HEIGHT_VOXELS),
			1e-12)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_pass_and_layer_underneath() -> void:
	var river := _pass_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(river.terrace())
	assert_not_null(river.channel_noise())


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

func test_self_check_passes() -> void:
	assert_eq(RiverPass.self_check(), "")
