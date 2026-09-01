extends TestCase
## Covers world/generation/generation_version.gd (brick 057).


func test_this_builds_declaration_is_self_consistent() -> void:
	# The guard that makes docs/world-generation.md §2.5's bump checklist mechanical: a
	# bumped SaveVersion.GENERATION_VERSION with no matching SUPPORTED/SUMMARIES entry
	# fails here, not at the first save nobody can open.
	assert_eq(GenerationVersion.self_check(), "")


func test_current_matches_the_number_save_version_owns() -> void:
	assert_eq(GenerationVersion.CURRENT, SaveVersion.GENERATION_VERSION)
	assert_true(GenerationVersion.is_supported(GenerationVersion.CURRENT))
	assert_eq(GenerationVersion.oldest_supported(),
			SaveVersion.MIN_SUPPORTED_GENERATION_VERSION)


func test_new_worlds_are_created_under_the_current_version() -> void:
	assert_eq(WorldSeed.from_value(12345).generation_version, GenerationVersion.CURRENT)
	assert_eq(WorldSeed.arbitrary().generation_version, GenerationVersion.CURRENT)


func test_status_of_names_every_position_relative_to_a_build() -> void:
	# A build writing 4 that dropped 2 along the way — the history this build does not
	# have yet, which is exactly why status_of() takes its inputs.
	var supported := PackedInt32Array([1, 3, 4])

	assert_eq(GenerationVersion.status_of(4, 4, supported),
			GenerationVersion.Status.CURRENT_VERSION)
	assert_eq(GenerationVersion.status_of(3, 4, supported), GenerationVersion.Status.LEGACY)
	assert_eq(GenerationVersion.status_of(1, 4, supported), GenerationVersion.Status.LEGACY)
	assert_eq(GenerationVersion.status_of(2, 4, supported), GenerationVersion.Status.RETIRED)
	assert_eq(GenerationVersion.status_of(5, 4, supported), GenerationVersion.Status.FUTURE)
	assert_eq(GenerationVersion.status_of(0, 4, supported), GenerationVersion.Status.INVALID)


func test_status_reads_this_builds_own_declaration() -> void:
	assert_eq(GenerationVersion.status(GenerationVersion.CURRENT),
			GenerationVersion.Status.CURRENT_VERSION)
	assert_eq(GenerationVersion.status(GenerationVersion.CURRENT + 1),
			GenerationVersion.Status.FUTURE)
	assert_eq(GenerationVersion.status(0), GenerationVersion.Status.INVALID)
	assert_eq(GenerationVersion.status_name(GenerationVersion.Status.RETIRED), "RETIRED")


func test_every_supported_version_is_described() -> void:
	# A refusal that names what the world was made with is a bug report; one that says
	# only "cannot load" is a deleted save.
	for version in GenerationVersion.supported():
		assert_false(GenerationVersion.summary(version).is_empty(),
				"version %d has no summary" % version)
	assert_eq(GenerationVersion.summary(GenerationVersion.CURRENT + 1), "")


func test_explain_names_the_version_and_what_this_build_does_with_it() -> void:
	var current := GenerationVersion.explain(GenerationVersion.CURRENT)
	var future := GenerationVersion.explain(GenerationVersion.CURRENT + 1)

	assert_true(current.contains(GenerationVersion.summary(GenerationVersion.CURRENT)),
			current)
	assert_true(current.contains("current"), current)
	assert_true(future.contains("newer build"), future)
	assert_true(GenerationVersion.explain(0).contains("not a valid"),
			GenerationVersion.explain(0))


func test_a_current_worlds_header_loads() -> void:
	var header := WorldSeed.from_value(12345).to_header()

	assert_eq(GenerationVersion.classify_header(header), SaveVersion.Compatibility.CURRENT)
	assert_true(GenerationVersion.can_load_header(header))
	assert_eq(GenerationVersion.explain_header(header), "save is current")


func test_a_world_from_an_unimplemented_algorithm_is_refused_with_a_reason() -> void:
	# docs/persistence.md §3: refused, never silently re-generated under a newer
	# algorithm — the deltas stored beside it were diffed against terrain this build
	# cannot reproduce.
	var header := WorldSeed.new(12345, "", GenerationVersion.CURRENT + 1).to_header()

	assert_eq(GenerationVersion.classify_header(header),
			SaveVersion.Compatibility.GENERATOR_UNAVAILABLE)
	assert_false(GenerationVersion.can_load_header(header))
	assert_true(GenerationVersion.explain_header(header).contains("no longer implements"),
			GenerationVersion.explain_header(header))


func test_a_malformed_header_is_malformed_not_unavailable() -> void:
	assert_eq(GenerationVersion.classify_header({"seed": 1}),
			SaveVersion.Compatibility.MALFORMED)


func test_classify_header_hands_save_version_the_explicit_supported_list() -> void:
	# The reason this wrapper exists: SaveVersion's own fallback is the
	# MIN_SUPPORTED..CURRENT *range*, which would accept a retired middle version.
	var header := WorldSeed.new(12345, "", GenerationVersion.CURRENT).to_header()

	assert_eq(GenerationVersion.classify_header(header),
			SaveVersion.classify(header, GenerationVersion.supported()))


func test_self_check_rejects_an_incoherent_declaration() -> void:
	var summaries := {1: "one", 2: "two"}

	# A bump that forgot to list the new version as supported.
	assert_true(GenerationVersion.self_check_of(2, PackedInt32Array([1]), 1, summaries)
			.contains("not the newest supported"))
	# A retirement that moved one file and not the other.
	assert_true(GenerationVersion.self_check_of(2, PackedInt32Array([2]), 1, summaries)
			.contains("does not match SaveVersion's"))
	# A new version with no description to show a player.
	assert_true(GenerationVersion.self_check_of(2, PackedInt32Array([1, 2]), 1, {1: "one"})
			.contains("no summary"))
	assert_false(GenerationVersion.self_check_of(2, PackedInt32Array([1, 2]), 1, summaries)
			.contains("no summary"))


func test_self_check_rejects_a_malformed_supported_list() -> void:
	var summaries := {1: "one", 2: "two"}

	assert_true(GenerationVersion.self_check_of(1, PackedInt32Array([]), 1, summaries)
			.contains("no generation version is supported"))
	assert_true(GenerationVersion.self_check_of(2, PackedInt32Array([2, 1]), 1, summaries)
			.contains("sorted and unique"))
	assert_true(GenerationVersion.self_check_of(2, PackedInt32Array([1, 1, 2]), 1, summaries)
			.contains("sorted and unique"))
	assert_true(GenerationVersion.self_check_of(0, PackedInt32Array([1]), 1, summaries)
			.contains("must be positive"))
	assert_true(GenerationVersion.self_check_of(2, PackedInt32Array([1, 2]), 1,
			{1: "one", 2: "two", 3: "three"}).contains("outside 1..2"))


func test_self_check_accepts_a_retired_middle_version() -> void:
	# A hole is legal — retiring a short-lived broken algorithm is a real decision. It is
	# also precisely why classify_header() never lets SaveVersion fall back to a range.
	assert_eq(GenerationVersion.self_check_of(4, PackedInt32Array([1, 3, 4]), 1,
			{1: "one", 2: "retired", 3: "three", 4: "four"}), "")
