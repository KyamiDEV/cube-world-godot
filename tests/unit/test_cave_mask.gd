extends TestCase
## `world/generation/cave_mask.gd` — where the underground is hollow (brick 077).
##
## `test_value_noise.gd` already covers the 3D noise mechanism this file builds on
## (determinism, range, coherence, the lattice). What is specific to `CaveMask` is the
## threshold, the scale relationship to `ElevationField`, and — the one property no shared
## fixture check can see — that the mask actually calls *some* real voxel a cave and *some*
## a solid, not the trivial all-true or all-false mask that would also pass every
## determinism check.

## The digest of `density_at()` over `GenerationFixtures.voxels()` for the `typed` world.
const PINNED_SIGNATURE := "8dce87e95aeb1d89"

## A voxel this exact configuration calls a cave on the `typed` world, found by a sweep
## during design and pinned here rather than re-derived — comfortably inside
## `DENSITY_THRESHOLD` rather than balanced on the boundary.
const KNOWN_CAVE_VOXEL := Vector3i(-323, 34, -221)

## A voxel this configuration calls solid on the `typed` world — the origin, which every
## other Phase D fixture also uses as its first sample.
const KNOWN_SOLID_VOXEL := Vector3i(0, 0, 0)


func _mask_for(name: String) -> CaveMask:
	return CaveMask.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var mask := CaveMask.for_world(hash)
		return func(voxel: Vector3i) -> float: return mask.density_at(voxel)


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(CaveMask.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_mask_for(name), "world '%s' has a cave mask" % name)


func test_self_check_passes() -> void:
	assert_eq(CaveMask.self_check(), "")


# ---------------------------------------------------------------------------
# Scale — the relationship to ElevationField's relief (class comment item 3)
# ---------------------------------------------------------------------------

func test_the_pinned_parameters_are_the_documented_ones() -> void:
	var mask := _mask_for(GenerationFixtures.WORLD_TYPED)
	var noise := mask.density_noise()
	assert_eq(noise.cell_size(), CaveMask.CELL_SIZE_VOXELS)
	assert_eq(noise.octaves(), CaveMask.OCTAVES)
	assert_eq(noise.gain(), CaveMask.GAIN)
	# Its own salt: a cave field sharing a salt with any other pass would correlate with it
	# (docs/rng.md §4) — every pass here reads independently.
	assert_eq(noise.salt(), WorldHash.SALT_CAVES)


func test_cell_size_is_an_eighth_of_reliefs_own() -> void:
	assert_eq(CaveMask.CELL_SIZE_VOXELS * 8, ElevationField.RELIEF_CELL_SIZE_VOXELS)


func test_finest_cell_is_half_reliefs_finest() -> void:
	var mask := _mask_for(GenerationFixtures.WORLD_TYPED)
	var relief_finest := ElevationField.RELIEF_CELL_SIZE_VOXELS >> (
			ElevationField.RELIEF_OCTAVES - 1)
	assert_eq(mask.finest_cell_size_voxels() * 2, relief_finest)
	assert_eq(mask.finest_cell_size_voxels(), 16)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory: Callable = _sampler_factory()
	assert_eq(GenerationFixtures.determinism_reason(factory.bind(hash),
			GenerationFixtures.voxels()), "")


func test_is_seed_sensitive() -> void:
	assert_eq(GenerationFixtures.seed_sensitivity_reason(_sampler_factory(),
			GenerationFixtures.voxels()), "")


func test_stays_in_its_stated_range() -> void:
	for name in GenerationFixtures.world_names():
		var mask := _mask_for(name)
		var sampler := func(voxel: Vector3i) -> float: return mask.density_at(voxel)
		assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.voxels(),
				0.0, 1.0), "", "world '%s' stays in [0, 1]" % name)


func test_varies_across_the_sample_voxels() -> void:
	var mask := _mask_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(voxel: Vector3i) -> float: return mask.density_at(voxel)
	assert_eq(GenerationFixtures.variation_reason(sampler, GenerationFixtures.voxels(), 8), "")


func test_signature_is_pinned() -> void:
	var mask := _mask_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(voxel: Vector3i) -> float: return mask.density_at(voxel)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.voxels()),
			PINNED_SIGNATURE)


# ---------------------------------------------------------------------------
# The threshold — the property no shared fixture check can see
# ---------------------------------------------------------------------------

func test_is_cave_at_agrees_with_the_threshold() -> void:
	var mask := _mask_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		var expected := mask.density_at(voxel) < CaveMask.DENSITY_THRESHOLD
		assert_eq(mask.is_cave_at(voxel), expected, "voxel %s" % voxel)


func test_a_real_voxel_reads_as_a_cave() -> void:
	# The mask must not be the trivial all-solid mask, which would also pass every
	# determinism/range/variation check above.
	var mask := _mask_for(GenerationFixtures.WORLD_TYPED)
	assert_true(mask.is_cave_at(KNOWN_CAVE_VOXEL))
	assert_true(mask.density_at(KNOWN_CAVE_VOXEL) < CaveMask.DENSITY_THRESHOLD)


func test_a_real_voxel_reads_as_solid() -> void:
	# ... and not the trivial all-cave mask either.
	var mask := _mask_for(GenerationFixtures.WORLD_TYPED)
	assert_false(mask.is_cave_at(KNOWN_SOLID_VOXEL))


func test_the_measured_fraction_is_a_minority() -> void:
	# The property item 2 of the class comment claims: roughly 4% of raw 3D space, not a
	# quarter of it, despite DENSITY_THRESHOLD being a literal quarter of [0, 1]. Swept at a
	# spacing just under the coarsest cell, matching the sweep design 065 established for a
	# field whose independent cells are wider than the standard 4093-voxel sweep spacing.
	var mask := _mask_for(GenerationFixtures.WORLD_TYPED)
	var spacing := 61
	var half := 8
	var total := 0
	var caves := 0
	for ix in range(-half, half):
		for iy in range(-half, half):
			for iz in range(-half, half):
				var voxel := Vector3i(ix * spacing, iy * spacing, iz * spacing)
				total += 1
				if mask.is_cave_at(voxel):
					caves += 1
	var fraction := float(caves) / float(total)
	assert_true(fraction > 0.005 and fraction < 0.15,
			"cave fraction %s is outside a plausible minority band" % fraction)
