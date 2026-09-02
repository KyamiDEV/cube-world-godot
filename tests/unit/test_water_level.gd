extends TestCase
## `world/generation/water_level.gd` — the water plane (brick 080).
##
## `test_terrace_pass.gd` already covers everything underneath; this file is about what 080
## adds on top of it — the plane itself, the strict boundary at it, and that the plane and
## `TerracePass.surface_y()` agree everywhere a consumer might ask.

## The digest of `depth_at()` over `GenerationFixtures.columns()` for the `typed` world.
const PINNED_SIGNATURE := "2c52ab62cf0542d2"


func _water_for(name: String) -> WaterLevel:
	return WaterLevel.for_world(GenerationFixtures.hash_for(name))


func _depth_sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var water := WaterLevel.for_world(hash)
		return func(column: Vector2i) -> int: return water.depth_at(column)


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(WaterLevel.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_water_for(name), "world '%s' has a water level" % name)


# ---------------------------------------------------------------------------
# The plane
# ---------------------------------------------------------------------------

func test_sea_level_is_the_datum() -> void:
	# The one number this brick picks. See the class comment for why: it is already
	# `TerracePass`'s own datum and the closest of the terrace-aligned candidates measured
	# to an even land/water split.
	assert_eq(WaterLevel.SEA_LEVEL_VOXELS, 0)


func test_self_check_passes() -> void:
	assert_eq(WaterLevel.self_check(), "")


func test_sea_level_is_an_exact_terrace_plane() -> void:
	assert_eq(WaterLevel.SEA_LEVEL_VOXELS % TerracePass.TERRACE_HEIGHT_VOXELS, 0)


# ---------------------------------------------------------------------------
# The boundary
# ---------------------------------------------------------------------------

func test_the_boundary_is_strict() -> void:
	var height := TerracePass.TERRACE_HEIGHT_VOXELS
	assert_false(WaterLevel.is_underwater_for(WaterLevel.SEA_LEVEL_VOXELS),
			"exactly at the plane reads dry")
	assert_false(WaterLevel.is_underwater_for(WaterLevel.SEA_LEVEL_VOXELS + height),
			"above the plane reads dry")
	assert_true(WaterLevel.is_underwater_for(WaterLevel.SEA_LEVEL_VOXELS - 1),
			"one voxel below the plane reads underwater")
	assert_true(WaterLevel.is_underwater_for(WaterLevel.SEA_LEVEL_VOXELS - height),
			"a whole terrace below reads underwater")


func test_depth_is_zero_on_dry_land_and_positive_underwater() -> void:
	assert_eq(WaterLevel.depth_for(WaterLevel.SEA_LEVEL_VOXELS), 0)
	assert_eq(WaterLevel.depth_for(WaterLevel.SEA_LEVEL_VOXELS + 8), 0)
	assert_eq(WaterLevel.depth_for(WaterLevel.SEA_LEVEL_VOXELS - 1), 1)
	assert_eq(WaterLevel.depth_for(WaterLevel.SEA_LEVEL_VOXELS - 24), 24)


func test_depth_and_underwater_agree() -> void:
	# `depth_for()` is positive exactly where `is_underwater_for()` is true — the same
	# column, two views of one boundary. Swept over a real span of terrace planes rather
	# than a handful of hand-picked values.
	var height := TerracePass.TERRACE_HEIGHT_VOXELS
	for step in range(-64, 65):
		var surface_y := WaterLevel.SEA_LEVEL_VOXELS + step * height
		assert_eq(WaterLevel.depth_for(surface_y) > 0, WaterLevel.is_underwater_for(surface_y),
				"surface_y %d" % surface_y)


# ---------------------------------------------------------------------------
# Agreement with `TerracePass`
# ---------------------------------------------------------------------------

func test_agrees_with_terrace_pass_at_every_sample_column() -> void:
	var water := _water_for(GenerationFixtures.WORLD_TYPED)
	var ground := water.terrace()
	for column in GenerationFixtures.columns():
		var surface_y := ground.surface_y(column)
		assert_eq(water.is_underwater_at(column), WaterLevel.is_underwater_for(surface_y),
				"column %s" % column)
		assert_eq(water.depth_at(column), WaterLevel.depth_for(surface_y), "column %s" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var water := _water_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		assert_eq(water.is_underwater_at_voxel(voxel), water.is_underwater_at(column),
				"voxel %s reads its column" % voxel)
		assert_eq(water.depth_at_voxel(voxel), water.depth_at(column),
				"voxel %s reads its column" % voxel)


func test_sea_level_metres_matches_world_scale() -> void:
	assert_almost_eq(WaterLevel.sea_level_metres(),
			WorldScale.voxels_to_metres(float(WaterLevel.SEA_LEVEL_VOXELS)), 1e-9)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory: Callable = _depth_sampler_factory()
	assert_eq(GenerationFixtures.determinism_reason(factory.bind(hash),
			GenerationFixtures.columns()), "")


func test_is_seed_sensitive() -> void:
	# `GenerationFixtures.columns()` is unsuitable here on its own — `test_underground_
	# material.gd` found the same shape of problem: its 15 samples cluster near the origin
	# and the `WorldBounds` corners, and two seeds' terraced ground both happening to read
	# dry (depth 0) there is not evidence of anything. The 2304-column distribution sweep
	# `test_terrace_pass.gd` and this file's own §"what the plane is for" section use gives
	# `TerracePass` — already proven seed-sensitive on its own terms — enough room to differ.
	assert_eq(GenerationFixtures.seed_sensitivity_reason(_depth_sampler_factory(),
			_sweep_columns()), "")


func test_signature_is_pinned() -> void:
	var water := _water_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> int: return water.depth_at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


# ---------------------------------------------------------------------------
# What the plane is for — measured against `TerracePass`'s own distribution sweep
# ---------------------------------------------------------------------------
#
# `test_terrace_pass.gd`'s own sweep, reused rather than re-derived: 48x48 columns spaced
# 4093 voxels apart from origin -98232, the same spacing `docs/world-generation.md` §6.6,
# §7.5 and §8's own measurements use, so this number is comparable to theirs.

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


func test_the_plane_splits_the_sweep_close_to_evenly() -> void:
	# The property `SEA_LEVEL_VOXELS = 0` was picked for: measured 49.8% underwater / 50.2%
	# land over this exact sweep (class comment), the closest of the three terrace-aligned
	# candidates tried to a 50/50 split. Asserted with headroom rather than pinned exactly,
	# so this test documents the property rather than freezing the measurement to the last
	# tenth of a percent.
	var water := _water_for(GenerationFixtures.WORLD_TYPED)
	var underwater := 0
	var total := 0
	for column in _sweep_columns():
		if water.is_underwater_at(column):
			underwater += 1
		total += 1
	var fraction := float(underwater) / float(total)
	assert_true(fraction > 0.4 and fraction < 0.6,
			"the plane leaves both land and water a real share of the world (%.3f)" % fraction)


func test_the_sweep_has_both_dry_and_underwater_columns() -> void:
	var water := _water_for(GenerationFixtures.WORLD_TYPED)
	var saw_dry := false
	var saw_underwater := false
	for column in _sweep_columns():
		if water.is_underwater_at(column):
			saw_underwater = true
		else:
			saw_dry = true
	assert_true(saw_dry, "the sweep reaches dry land")
	assert_true(saw_underwater, "the sweep reaches underwater ground")


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_pass_underneath() -> void:
	var water := _water_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(water.terrace())
