extends TestCase
## Covers tests/fixtures/generation_fixtures.gd (brick 059).
##
## Every Phase D brick from 060 on tests its own pass through this fixture module, so a
## fixture that has quietly stopped working takes thirty bricks' worth of determinism
## tests with it while they all still report green. Two things are asserted here:
##
## 1. **The inputs are what they claim to be** — the pinned seeds still hash to their
##    pinned values, and the sample coordinates still cover the cases they were chosen
##    for (negative axes, cell boundaries, the far corners of `WorldBounds`).
## 2. **The checks catch what they exist to catch** — each one is run against a
##    deliberately broken pass as well as a correct one, because a check that never fails
##    is indistinguishable from a check that cannot fail.

const SALT := WorldHash.SALT_ELEVATION

## The digest of `GenerationHash.value01_column()` over `GenerationFixtures.columns()` for
## the `typed` world, pinned. This is the whole 015 + 056 + 058 stack in one string: if it
## moves, either the string hash, the positional hash, the space tags or the sample list
## moved with it, and after brick 060 that is a generation version bump
## (`docs/world-generation.md` §2.1), not a number to update.
const PINNED_COLUMN_SIGNATURE := "e33366942fe2f8f6"


# ---------------------------------------------------------------------------
# The inputs
# ---------------------------------------------------------------------------

func test_the_fixture_set_is_coherent() -> void:
	# One call, because every drift the fixtures can suffer is a reason string there.
	assert_eq(GenerationFixtures.self_check(), "")


func test_named_worlds_still_hash_to_their_pinned_values() -> void:
	var names := GenerationFixtures.world_names()
	assert_true(names.size() >= 4, "the fixture set covers several worlds")
	for name in names:
		var entry: Dictionary = GenerationFixtures.WORLDS[name]
		var built := GenerationFixtures.world(name)
		if not assert_not_null(built, "world '%s' builds" % name):
			continue
		assert_eq(built.value, int(entry["value"]),
				"world '%s' still has its pinned seed" % name)
		assert_eq(built.validate(), "", "world '%s' is a coherent configuration" % name)
		var text: String = entry["text"]
		if not text.is_empty():
			assert_eq(WorldHash.seed_from_text(text), int(entry["value"]),
					"'%s' still hashes to the pinned seed" % text)


func test_the_named_worlds_are_different_worlds() -> void:
	# Two fixture worlds that turned out to be the same world would make
	# seed_sensitivity_reason() vacuous rather than failing it.
	var built := GenerationFixtures.worlds()
	for i in built.size():
		for j in range(i + 1, built.size()):
			assert_false(built[i].matches(built[j]),
					"fixture worlds %d and %d differ" % [i, j])


func test_every_world_binds_a_generation_hash() -> void:
	for name in GenerationFixtures.world_names():
		var bound := GenerationFixtures.hash_for(name)
		if not assert_not_null(bound, "world '%s' binds" % name):
			continue
		assert_eq(bound.seed_value(), int(GenerationFixtures.WORLDS[name]["value"]))


func test_an_unknown_world_name_is_not_silently_a_world() -> void:
	# Returning some default world for a typo would run a whole suite against the wrong
	# seed and report it as a pass.
	assert_null(GenerationFixtures.world("no_such_world"))
	assert_null(GenerationFixtures.hash_for("no_such_world"))


func test_voxel_samples_are_inside_the_world() -> void:
	var samples := GenerationFixtures.voxels()
	assert_true(samples.size() >= 12, "enough voxel samples (%d)" % samples.size())
	for voxel in samples:
		assert_true(WorldBounds.contains(voxel), "%s is inside the world" % voxel)


func test_samples_cover_the_coordinates_that_break_generation() -> void:
	var samples := GenerationFixtures.voxels()
	assert_has(samples, Vector3i(0, 0, 0), "the origin")
	assert_has(samples, Vector3i(-1, 0, -1), "the cell truncating division mis-assigns")
	assert_has(samples, Vector3i(-7, 5, -9), "the coordinate brick 058's defect mirrored")
	assert_has(samples, Vector3i(7, 5, 9), "and its mirror")
	assert_has(samples, Vector3i(1023, 0, 1023), "the last column of region (0, 0)")
	assert_has(samples, Vector3i(WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS - 1, 0,
			WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS - 1), "the far corner")
	# Two columns holding the same pair of numbers in the opposite order: a pass that
	# folds x and z together answers identically for both, and a diagonal-only sample
	# set never notices.
	assert_has(GenerationFixtures.columns(), Vector2i(9, -9))
	assert_has(GenerationFixtures.columns(), Vector2i(-9, 9))


func test_region_samples_reach_both_corners_of_the_region_grid() -> void:
	var samples := GenerationFixtures.regions()
	var half := GenerationGrid.HALF_REGIONS_PER_AXIS
	assert_has(samples, Vector2i(half - 1, half - 1), "the last region")
	assert_has(samples, Vector2i(-half, -half), "the first region")
	for region in samples:
		assert_true(GenerationGrid.is_region_in_world(region),
				"%s is a region this world has" % region)


func test_derived_sample_sets_hold_no_duplicates() -> void:
	for samples in [GenerationFixtures.columns(), GenerationFixtures.chunks(),
			GenerationFixtures.chunk_columns()]:
		var seen: Dictionary = {}
		for sample in samples:
			assert_false(seen.has(sample), "%s is listed once" % sample)
			seen[sample] = true


func test_sample_lists_are_handed_out_fresh() -> void:
	# The runner instantiates a test class once per file, so a shared constant array a
	# test sorted or appended to would change what every later test samples.
	var first := GenerationFixtures.voxels()
	var original_size := first.size()
	first.append(Vector3i(1234, 0, 1234))
	assert_size(GenerationFixtures.voxels(), original_size)


# ---------------------------------------------------------------------------
# The checks
# ---------------------------------------------------------------------------

func test_determinism_check_accepts_a_positional_pass() -> void:
	var bound := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := Callable(self, "_positional_pass").bind(bound)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()),
			"", "hashing a column is repeatable and order-free")


func test_repeatability_check_catches_a_pass_that_carries_state() -> void:
	var counting := _counting_pass()
	var reason := GenerationFixtures.repeatability_reason(counting,
			GenerationFixtures.columns())
	assert_ne(reason, "", "a pass whose answer moves per call is reported")
	assert_has(reason, "twice")


func test_order_independence_check_catches_a_cell_numbering_pass() -> void:
	# The subtle one, and the reason this check takes a factory rather than a sampler: a
	# pass that assigns each new cell the next free number answers a repeated call
	# consistently, so repeatability alone reports it as fine.
	var samples := GenerationFixtures.columns()
	var numbering := _cell_numbering_pass()
	assert_eq(GenerationFixtures.repeatability_reason(numbering, samples), "",
			"the broken pass does pass the weaker check")
	assert_ne(GenerationFixtures.order_independence_reason(
			Callable(self, "_cell_numbering_pass"), samples), "",
			"but its answers depend on the order it met the cells in")


func test_seed_sensitivity_check_catches_a_pass_that_ignores_the_seed() -> void:
	var samples := GenerationFixtures.columns()
	assert_eq(GenerationFixtures.seed_sensitivity_reason(
			Callable(self, "_positional_pass"), samples), "",
			"a seeded pass gives every fixture world its own answers")
	var reason := GenerationFixtures.seed_sensitivity_reason(
			Callable(self, "_seedless_pass"), samples)
	assert_ne(reason, "", "a pass that never mixes the seed generates one world for all")
	assert_has(reason, "agree at every")


func test_range_check_accepts_unit_values_and_reports_what_leaves_the_range() -> void:
	var bound := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var samples := GenerationFixtures.columns()
	assert_eq(GenerationFixtures.range_reason(_positional_pass(bound), samples, 0.0, 1.0),
			"", "value01 stays in [0, 1)")
	assert_ne(GenerationFixtures.range_reason(_positional_pass(bound), samples, 0.0, 0.25),
			"", "a narrower range is reported")
	assert_ne(GenerationFixtures.range_reason(_nan_pass(), samples, 0.0, 1.0), "",
			"NaN compares false against both ends, so it is reported by name")
	assert_ne(GenerationFixtures.range_reason(_seedless_pass(null), samples, 0.0, 1.0), "",
			"an int where a float was expected is reported")


func test_variation_check_catches_a_pass_that_answers_the_same_thing_everywhere() -> void:
	var samples := GenerationFixtures.columns()
	var bound := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(GenerationFixtures.variation_reason(_positional_pass(bound), samples), "")
	assert_ne(GenerationFixtures.variation_reason(_constant_pass(), samples), "",
			"a stub that returns one value is deterministic, in range, and wrong")


# ---------------------------------------------------------------------------
# Golden signatures
# ---------------------------------------------------------------------------

func test_signature_is_stable_and_shaped_like_a_digest() -> void:
	var bound := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var samples := GenerationFixtures.columns()
	var first := GenerationFixtures.signature(_positional_pass(bound), samples)
	assert_eq(first.length(), 16, "16 hex digits")
	assert_eq(first, GenerationFixtures.signature(_positional_pass(bound), samples),
			"the same pass over the same samples digests identically")


func test_signature_moves_when_a_single_sampled_value_moves() -> void:
	var samples := GenerationFixtures.columns()
	var bound := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var baseline := GenerationFixtures.signature(_positional_pass(bound), samples)
	assert_ne(GenerationFixtures.signature(
			_nudged_pass(bound, samples[0]), samples), baseline,
			"one changed cell changes the digest")
	assert_ne(GenerationFixtures.signature(_positional_pass(bound),
			_reversed(samples)), baseline, "the digest is order-sensitive")


func test_signature_distinguishes_a_float_from_an_int() -> void:
	# A field that started returning integers is a real change, and `1 == 1.0` in
	# GDScript would hide it.
	var one_sample: Array = [Vector2i(0, 0)]
	assert_ne(GenerationFixtures.signature(_constant_pass(), one_sample),
			GenerationFixtures.signature(_seedless_pass(null), one_sample))


func test_the_positional_stack_still_produces_its_pinned_signature() -> void:
	var bound := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(GenerationFixtures.signature(_positional_pass(bound),
			GenerationFixtures.columns()), PINNED_COLUMN_SIGNATURE,
			"the seed hash, the positional hash and the sample list are all unchanged")


# ---------------------------------------------------------------------------
# Passes under test — one correct, four broken in a specific way
# ---------------------------------------------------------------------------

## The shape a real per-column field has: a pure function of the world and the coordinate.
func _positional_pass(bound: GenerationHash) -> Callable:
	return func(column: Vector2i) -> float: return bound.value01_column(column, SALT)


## The same, with one coordinate's answer moved — a one-cell change to the algorithm.
func _nudged_pass(bound: GenerationHash, nudged: Vector2i) -> Callable:
	return func(column: Vector2i) -> float:
		var value := bound.value01_column(column, SALT)
		return 1.0 - value if column == nudged else value


## Answers from the coordinate alone. Deterministic, order-free, in range — and the same
## world for every seed, which is exactly what a single-world test cannot see.
func _seedless_pass(_bound: GenerationHash) -> Callable:
	return func(column: Vector2i) -> int: return column.x * 31 + column.y


## A stub that was never filled in.
func _constant_pass() -> Callable:
	return func(_column: Vector2i) -> float: return 0.0


## A field whose arithmetic went undefined somewhere upstream.
func _nan_pass() -> Callable:
	return func(_column: Vector2i) -> float: return NAN


## Answers a different number every call. The plainest determinism failure there is; the
## captured array is what carries the state, since a lambda captures locals by value.
func _counting_pass() -> Callable:
	var calls: Array[int] = [0]
	return func(_column: Vector2i) -> int:
		calls[0] += 1
		return calls[0]


## Assigns each cell the next free number as it first meets it. Repeatable per cell and
## entirely dependent on the order the cells were visited in.
func _cell_numbering_pass() -> Callable:
	var seen: Dictionary = {}
	return func(column: Vector2i) -> int:
		if not seen.has(column):
			seen[column] = seen.size()
		return seen[column]


func _reversed(samples: Array) -> Array:
	var out: Array = samples.duplicate()
	out.reverse()
	return out
