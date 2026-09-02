extends TestCase
## `world/structures/structure_seed_field.gd` — one deterministic structure seed per region
## (brick 089).
##
## `test_generation_hash.gd` already covers `rng_region()` and the space tagging underneath;
## `test_generation_grid.gd` already covers the region grid and `is_region_in_world()`.
## What is specific to this brick is the composition: exactly one `StructureSeed` per
## in-world region, drawn in a fixed order, with a jittered anchor and an owned sub-seed
## that is independent of both the anchor draws and of the neighbouring regions.

## Golden outputs over `GenerationFixtures.regions()` on the `typed` world. A change to
## `WorldHash`, `rng_region()`, the draw order or the region pitch moves these — the test
## that fails then asks whether that is a bug or a generation version bump
## (`docs/world-generation.md` §28.5).
const PINNED_ANCHOR_SIGNATURE := "3d68a17ff4f752f0"
const PINNED_SEED_SIGNATURE := "16945661f5c05b64"


func _field_for(name: String) -> StructureSeedField:
	return StructureSeedField.for_world(GenerationFixtures.hash_for(name))


## A signed grid of in-world regions around the origin, for the sweeps that need many.
func _region_sweep(side := 16) -> Array[Vector2i]:
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
	assert_null(StructureSeedField.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_field_for(name), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# seed_at()
# ---------------------------------------------------------------------------

func test_every_in_world_region_yields_exactly_one_seed() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for region in GenerationFixtures.regions():
		var seed_record := field.seed_at(region)
		assert_not_null(seed_record, "region %s" % region)
		assert_eq(seed_record.region, region)
		assert_eq(seed_record.validate(), "", "region %s produced an incoherent seed" % region)


func test_a_region_outside_the_grid_has_no_seed() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for region in [
			Vector2i(GenerationGrid.HALF_REGIONS_PER_AXIS, 0),
			Vector2i(0, GenerationGrid.HALF_REGIONS_PER_AXIS),
			Vector2i(-GenerationGrid.HALF_REGIONS_PER_AXIS - 1, 0),
			Vector2i(9999, 9999)]:
		assert_false(GenerationGrid.is_region_in_world(region))
		assert_null(field.seed_at(region), "region %s" % region)
		assert_false(field.has_seed(region), "region %s" % region)


func test_the_anchor_lies_inside_its_own_region() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for region in _region_sweep():
		var anchor := field.seed_at(region).anchor_column
		assert_eq(GenerationGrid.column_to_region(anchor), region, "region %s" % region)


func test_the_anchor_is_jittered_not_pinned_to_the_region_corner() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var on_corner := 0
	var offsets := {}
	for region in _region_sweep():
		var seed_record := field.seed_at(region)
		var offset := seed_record.anchor_column - GenerationGrid.region_origin(region)
		offsets[offset] = true
		if offset == Vector2i.ZERO:
			on_corner += 1
	# The jitter must actually vary — not every region drawing the same offset — and only a
	# tiny fraction (if any) of a 256-region sweep should land exactly on the corner.
	assert_true(offsets.size() > 200, "only %d distinct anchor offsets across 256 regions" % offsets.size())
	assert_true(on_corner <= 2, "%d regions anchored exactly on their corner" % on_corner)


# ---------------------------------------------------------------------------
# column / voxel entry points
# ---------------------------------------------------------------------------

func test_seed_for_column_resolves_the_containing_region() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for column in [Vector2i(0, 0), Vector2i(-1, -1), Vector2i(1023, 1023),
			Vector2i(1024, -2048), Vector2i(-500000, 400000)]:
		var expected := field.seed_at(GenerationGrid.column_to_region(column))
		var actual := field.seed_for_column(column)
		if expected == null:
			assert_null(actual, "column %s" % column)
		else:
			assert_eq(actual.region, expected.region, "column %s" % column)
			assert_eq(actual.anchor_column, expected.anchor_column, "column %s" % column)
			assert_eq(actual.structure_seed, expected.structure_seed, "column %s" % column)


func test_seed_for_voxel_drops_the_height() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		var by_voxel := field.seed_for_voxel(voxel)
		var by_column := field.seed_for_column(column)
		if by_column == null:
			assert_null(by_voxel, "voxel %s" % voxel)
		else:
			assert_eq(by_voxel.anchor_column, by_column.anchor_column, "voxel %s" % voxel)
			assert_eq(by_voxel.structure_seed, by_column.structure_seed, "voxel %s" % voxel)


# ---------------------------------------------------------------------------
# Independence
# ---------------------------------------------------------------------------

func test_the_sub_seed_is_not_either_anchor_offset() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for region in _region_sweep():
		var seed_record := field.seed_at(region)
		var offset := seed_record.anchor_column - GenerationGrid.region_origin(region)
		assert_ne(seed_record.structure_seed, offset.x)
		assert_ne(seed_record.structure_seed, offset.y)


func test_adjacent_regions_get_uncorrelated_sub_seeds() -> void:
	# The reference divergence made concrete (`region-coordinate-hashing.md` §9): a linear
	# seed makes neighbouring regions produce neighbouring first draws. `rng_region()`
	# avalanches, so `(r)` and `(r + 1)` must not sit next to each other.
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var seeds := {}
	var near_misses := 0
	var sweep := _region_sweep()
	for region in sweep:
		var value := field.seed_at(region).structure_seed
		assert_false(seeds.has(value), "two regions share sub-seed %d" % value)
		seeds[value] = region
	for region in sweep:
		var here := field.seed_at(region).structure_seed
		var east := field.seed_at(region + Vector2i(1, 0)).structure_seed
		if absi(here - east) < 1 << 40:
			near_misses += 1
	assert_true(near_misses < sweep.size() * 0.125,
			"%d of %d east-neighbour sub-seed pairs are suspiciously close" % [near_misses, sweep.size()])


func test_two_worlds_pick_different_seeds_for_the_same_region() -> void:
	var typed := _field_for(GenerationFixtures.WORLD_TYPED)
	var numeric := _field_for(GenerationFixtures.WORLD_NUMERIC)
	var differ := 0
	for region in _region_sweep():
		if typed.seed_at(region).structure_seed != numeric.seed_at(region).structure_seed:
			differ += 1
	assert_eq(differ, 256, "every region must differ between two worlds")


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var field := StructureSeedField.for_world(hash)
		return func(region: Vector2i) -> Vector2i: return field.seed_at(region).anchor_column
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.regions()), "")


func test_is_seed_sensitive() -> void:
	var factory := func(hash: GenerationHash) -> Callable:
		var field := StructureSeedField.for_world(hash)
		return func(region: Vector2i) -> int: return field.seed_at(region).structure_seed
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, GenerationFixtures.regions()), "")


func test_anchor_signature_is_pinned() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(region: Vector2i) -> Vector2i: return field.seed_at(region).anchor_column
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.regions()),
			PINNED_ANCHOR_SIGNATURE)


func test_sub_seed_signature_is_pinned() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(region: Vector2i) -> int: return field.seed_at(region).structure_seed
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.regions()),
			PINNED_SEED_SIGNATURE)
