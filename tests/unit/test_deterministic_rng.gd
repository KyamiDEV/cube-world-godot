extends TestCase
## Covers core/random/deterministic_rng.gd (brick 015).

const SAMPLES := 4000


func test_matches_the_splitmix64_reference_vector() -> void:
	# Pins the algorithm itself. If this fails, every world generated so far would
	# regenerate differently — the change is a generation-version bump, not a fix.
	var rng := DeterministicRng.from_seed(0)
	assert_eq(rng.next_u64(), -2152535657050944081, "splitmix64(0)[0] = 0xE220A8397B1DCDAF")
	assert_eq(rng.next_u64(), 7960286522194355700, "splitmix64(0)[1] = 0x6E789E6AA1B965F4")
	assert_eq(rng.next_u64(), 487617019471545679, "splitmix64(0)[2] = 0x06C45D188009454F")


func test_same_seed_produces_the_same_sequence() -> void:
	var a := DeterministicRng.from_seed(12345)
	var b := DeterministicRng.from_seed(12345)
	for _i in 100:
		assert_eq(a.next_u64(), b.next_u64())


func test_different_seeds_diverge_immediately() -> void:
	var a := DeterministicRng.from_seed(1)
	var b := DeterministicRng.from_seed(2)
	assert_ne(a.next_u64(), b.next_u64(), "adjacent seeds do not produce adjacent output")


func test_floats_stay_in_the_unit_interval() -> void:
	var rng := DeterministicRng.from_seed(99)
	var minimum := 1.0
	var maximum := 0.0
	for _i in SAMPLES:
		var value := rng.next_float()
		assert_true(value >= 0.0 and value < 1.0, "next_float() is in [0, 1)")
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	assert_true(minimum < 0.05, "the low end of the range is reached")
	assert_true(maximum > 0.95, "the high end of the range is reached")


func test_float_mean_is_roughly_a_half() -> void:
	var rng := DeterministicRng.from_seed(7)
	var total := 0.0
	for _i in SAMPLES:
		total += rng.next_float()
	assert_in_range(total / float(SAMPLES), 0.47, 0.53)


func test_next_range_respects_its_bounds() -> void:
	var rng := DeterministicRng.from_seed(3)
	for _i in 500:
		var value := rng.next_range(-10.0, 10.0)
		assert_true(value >= -10.0 and value < 10.0)


func test_next_int_covers_its_range_inclusively() -> void:
	var rng := DeterministicRng.from_seed(42)
	var seen := {}
	for _i in 500:
		var value := rng.next_int(1, 6)
		assert_in_range(value, 1, 6)
		seen[value] = true
	assert_size(seen.keys(), 6, "every face of a d6 appears, including both ends")


func test_next_int_is_not_biased_towards_low_values() -> void:
	# Modulo over a span that does not divide the range evenly would tilt the
	# distribution; rejection sampling must not. 3 is deliberately such a span.
	var rng := DeterministicRng.from_seed(2024)
	var counts := [0, 0, 0]
	for _i in 6000:
		counts[rng.next_int(0, 2)] += 1
	for count in counts:
		assert_in_range(count, 1800, 2200, "each of three outcomes is near a third")


func test_next_int_handles_degenerate_ranges() -> void:
	var rng := DeterministicRng.from_seed(1)
	assert_eq(rng.next_int(5, 5), 5, "a single-value range needs no roll")
	assert_eq(rng.next_int(9, 2), 9, "an inverted range returns the minimum")


func test_next_bool_short_circuits_without_consuming_the_stream() -> void:
	# A disabled roll must not advance the stream: if it did, toggling one feature off
	# would change every later result in the world.
	var rng := DeterministicRng.from_seed(5)
	var expected := rng.next_u64()

	var probe := DeterministicRng.from_seed(5)
	assert_false(probe.next_bool(0.0), "probability 0 is never true")
	assert_true(probe.next_bool(1.0), "probability 1 is always true")
	assert_eq(probe.next_u64(), expected, "neither call touched the stream")


func test_next_bool_is_roughly_fair() -> void:
	var rng := DeterministicRng.from_seed(8)
	var heads := 0
	for _i in SAMPLES:
		if rng.next_bool():
			heads += 1
	assert_in_range(float(heads) / float(SAMPLES), 0.46, 0.54)


func test_pick_returns_a_member_and_handles_empty() -> void:
	var rng := DeterministicRng.from_seed(11)
	var items := ["a", "b", "c"]
	for _i in 50:
		assert_has(items, rng.pick(items))
	assert_null(rng.pick([]), "an empty array yields null, not a crash")


func test_pick_weighted_follows_the_weights() -> void:
	var rng := DeterministicRng.from_seed(13)
	var weights := PackedFloat64Array([0.0, 9.0, 1.0])
	var counts := [0, 0, 0]
	for _i in 2000:
		counts[rng.pick_weighted(weights)] += 1
	assert_eq(counts[0], 0, "a zero weight is never chosen")
	assert_true(counts[1] > counts[2] * 4, "a 9:1 weighting shows up as roughly 9:1")


func test_pick_weighted_reports_no_eligible_entry() -> void:
	var rng := DeterministicRng.from_seed(1)
	assert_eq(rng.pick_weighted(PackedFloat64Array([0.0, 0.0])), -1,
			"all-zero weights return -1 rather than a silent first entry")
	assert_eq(rng.pick_weighted(PackedFloat64Array([])), -1)


func test_shuffled_permutes_without_touching_the_input() -> void:
	var source := [1, 2, 3, 4, 5, 6, 7, 8]
	var rng := DeterministicRng.from_seed(77)
	var result := rng.shuffled(source)

	assert_eq(source, [1, 2, 3, 4, 5, 6, 7, 8], "the input array is left alone")
	assert_size(result, 8)
	var sorted_result := result.duplicate()
	sorted_result.sort()
	assert_eq(sorted_result, source, "a shuffle is a permutation, nothing is lost")


func test_shuffled_is_reproducible() -> void:
	var source := [1, 2, 3, 4, 5, 6, 7, 8]
	assert_eq(DeterministicRng.from_seed(77).shuffled(source),
			DeterministicRng.from_seed(77).shuffled(source))


func test_derive_produces_independent_streams() -> void:
	var parent := DeterministicRng.from_seed(1000)
	var child_a := parent.derive(1)
	var child_b := parent.derive(2)
	assert_ne(child_a.next_u64(), child_b.next_u64(), "different salts, different streams")

	# The parent's own sequence is still reproducible: the same derive calls in the same
	# order always yield the same children.
	var again := DeterministicRng.from_seed(1000)
	assert_eq(again.derive(1).next_u64(), DeterministicRng.from_seed(1000).derive(1).next_u64())


func test_derived_stream_is_isolated_from_sibling_consumption() -> void:
	# The point of forking: how many values one subsystem draws must not shift another.
	var parent := DeterministicRng.from_seed(500)
	var a := parent.derive(1)
	var b := parent.derive(2)
	var b_first := b.next_u64()

	var parent2 := DeterministicRng.from_seed(500)
	var a2 := parent2.derive(1)
	var b2 := parent2.derive(2)
	for _i in 50:
		a2.next_u64()  # sibling draws heavily
	assert_eq(b2.next_u64(), b_first, "sibling activity did not move this stream")
	assert_ne(a.next_u64(), 0)  # keep `a` used so the intent of the fork is clear


func test_named_streams_differ_by_key() -> void:
	var a := DeterministicRng.from_seed_and_key(1, "loot")
	var b := DeterministicRng.from_seed_and_key(1, "spawns")
	assert_ne(a.next_u64(), b.next_u64())
	assert_eq(DeterministicRng.from_seed_and_key(1, "loot").next_u64(),
			DeterministicRng.from_seed_and_key(1, "loot").next_u64(),
			"the same key always gives the same stream")


func test_state_round_trips_for_saving() -> void:
	var rng := DeterministicRng.from_seed(31337)
	for _i in 10:
		rng.next_u64()
	var saved := rng.get_state()
	var expected := rng.next_u64()

	var restored := DeterministicRng.new()
	restored.set_state(saved)
	assert_eq(restored.next_u64(), expected, "a saved stream resumes exactly")


func test_string_hash_is_stable_and_well_distributed() -> void:
	# These values are a contract: they key saved data, so they must never change.
	assert_eq(DeterministicRng.hash_string(""), DeterministicRng.hash_string(""))
	assert_ne(DeterministicRng.hash_string("item.sword.iron"),
			DeterministicRng.hash_string("item.sword.steel"))
	assert_ne(DeterministicRng.hash_string("ab"), DeterministicRng.hash_string("ba"),
			"order matters")

	var seen := {}
	for i in 1000:
		seen[DeterministicRng.hash_string("creature.goblin.%d" % i)] = true
	assert_size(seen.keys(), 1000, "1000 similar keys produce 1000 distinct hashes")
