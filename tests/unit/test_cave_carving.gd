extends TestCase
## `world/generation/cave_carving.gd` — where a cave is actually allowed to hollow the
## ground (brick 078).
##
## `test_cave_mask.gd` and `test_terrace_pass.gd` already cover the two passes this file
## composes; nothing here re-asserts the noise mechanism or the terrace quantisation. What is
## specific to `CaveCarving` is the clip itself: a voxel `CaveMask` calls hollow must read
## solid here once it sits at or above its own column's terraced surface, and a voxel
## underground must agree with `CaveMask` exactly.

## The digest of `is_hollow_at()` over `GenerationFixtures.voxels()` for the `typed` world.
## All 16 fixture voxels land solid — the same "too small a sample to land on the ~4% cave
## fraction" finding `test_cave_mask.gd` already recorded, carried forward rather than
## re-argued; the hand-picked voxels below are what actually exercise `true`.
const PINNED_SIGNATURE := "20ff1ccf274a9c05"

## Underground (surface_y = 64 on the `typed` world) and `CaveMask`-hollow —
## `test_cave_mask.gd::KNOWN_CAVE_VOXEL`, reused rather than re-found by a second sweep.
const KNOWN_HOLLOW_VOXEL := Vector3i(-323, 34, -221)

## Underground but `CaveMask`-solid — the origin, `test_cave_mask.gd::KNOWN_SOLID_VOXEL`.
const KNOWN_SOLID_VOXEL := Vector3i(0, 0, 0)

## `CaveMask`-hollow but sitting 280 voxels above its own column's terraced surface (found by
## a design-time sweep up column `(1, 2)`) — the voxel that actually exercises the clip: if
## this file forgot to check the surface, it would report `true` here.
const KNOWN_ABOVE_GROUND_CAVE_VOXEL := Vector3i(1, 344, 2)


func _carving_for(name: String) -> CaveCarving:
	return CaveCarving.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var carving := CaveCarving.for_world(hash)
		return func(voxel: Vector3i) -> bool: return carving.is_hollow_at(voxel)


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(CaveCarving.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_carving_for(name), "world '%s' has cave carving" % name)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------
#
# No `test_is_seed_sensitive()` here, and that omission is deliberate rather than an
# oversight: `is_hollow_at()` is a boolean over a field that reads hollow on roughly 4% of
# underground space (`CaveMask`, §16.4), so `GenerationFixtures.voxels()` — 16 samples — reads
# `false` for every one of them on more than one fixture seed, the same way it would for
# `CaveMask.is_cave_at()` directly (`test_cave_mask.gd` tests seed sensitivity on the
# continuous `density_at()` for exactly this reason, never on the boolean). This file adds no
# seed-dependent state of its own — `CaveMask` and `TerracePass` each already prove their own
# seed sensitivity in their own test files — so there is nothing here for a repeat of that
# check to find that a hand-picked voxel below doesn't already show more directly.

func test_is_deterministic() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory: Callable = _sampler_factory()
	assert_eq(GenerationFixtures.determinism_reason(factory.bind(hash),
			GenerationFixtures.voxels()), "")


func test_signature_is_pinned() -> void:
	var carving := _carving_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(voxel: Vector3i) -> bool: return carving.is_hollow_at(voxel)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.voxels()),
			PINNED_SIGNATURE)


# ---------------------------------------------------------------------------
# The clip — the property no shared fixture check can see
# ---------------------------------------------------------------------------

func test_a_real_underground_cave_reads_as_hollow() -> void:
	var carving := _carving_for(GenerationFixtures.WORLD_TYPED)
	assert_true(carving.is_hollow_at(KNOWN_HOLLOW_VOXEL))


func test_a_real_underground_solid_voxel_reads_as_not_hollow() -> void:
	var carving := _carving_for(GenerationFixtures.WORLD_TYPED)
	assert_false(carving.is_hollow_at(KNOWN_SOLID_VOXEL))


func test_a_cave_above_the_surface_is_clipped_to_not_hollow() -> void:
	# The property the whole brick exists for: CaveMask alone would call this voxel hollow,
	# but it sits above its own column's terraced surface, so CaveCarving must not.
	var carving := _carving_for(GenerationFixtures.WORLD_TYPED)
	var caves := carving.caves()
	assert_true(caves.is_cave_at(KNOWN_ABOVE_GROUND_CAVE_VOXEL),
			"fixture voxel is no longer CaveMask-hollow; pick a new one")
	assert_false(carving.is_hollow_at(KNOWN_ABOVE_GROUND_CAVE_VOXEL))


func test_agrees_with_the_mask_and_the_surface_at_every_sample_voxel() -> void:
	var carving := _carving_for(GenerationFixtures.WORLD_TYPED)
	var caves := carving.caves()
	var terrace := carving.terrace()
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		var expected := voxel.y < terrace.surface_y(column) and caves.is_cave_at(voxel)
		assert_eq(carving.is_hollow_at(voxel), expected, "voxel %s" % voxel)


func test_the_surface_voxel_itself_is_never_hollow() -> void:
	# The boundary CaveCarving shares with SubsurfaceMaterial (076, §15): the surface voxel
	# is solid ground by definition, whatever CaveMask's noise says about it.
	var carving := _carving_for(GenerationFixtures.WORLD_TYPED)
	var terrace := carving.terrace()
	for column in GenerationFixtures.columns():
		var surface_y := terrace.surface_y(column)
		var voxel := Vector3i(column.x, surface_y, column.y)
		assert_false(carving.is_hollow_at(voxel), "column %s surface voxel" % column)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var carving := _carving_for(GenerationFixtures.WORLD_TYPED)
	assert_not_null(carving.caves())
	assert_not_null(carving.terrace())
