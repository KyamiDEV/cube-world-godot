extends TestCase
## Covers world/generation/world_seed.gd (brick 056).

const _TYPED_TEXT := "cube world alpha"
const _NUMERIC_TEXT := "12345"

var _log: Node


func before_each() -> void:
	_log = get_tree().root.get_node("Log")


func after_each() -> void:
	# The autoload is shared process-wide; a leaked capture makes the next test
	# order-dependent (same pattern test_log.gd and test_voxel_terrain_metrics.gd use).
	_log.take_capture()


func test_numeric_text_is_taken_at_face_value() -> void:
	# The property that makes a seed in a bug report reproducible.
	var config := WorldSeed.from_text(_NUMERIC_TEXT)

	assert_eq(config.value, 12345)
	assert_eq(config.text, _NUMERIC_TEXT)


func test_non_numeric_text_hashes_through_the_projects_own_hash() -> void:
	var config := WorldSeed.from_text(_TYPED_TEXT)

	assert_eq(config.value, WorldHash.seed_from_text(_TYPED_TEXT))
	assert_ne(config.value, 0)


func test_text_is_stored_trimmed() -> void:
	var config := WorldSeed.from_text("  " + _TYPED_TEXT + "  ")

	assert_eq(config.text, _TYPED_TEXT)
	assert_eq(config.value, WorldHash.seed_from_text(_TYPED_TEXT))
	assert_eq(config.validate(), "")


func test_empty_text_is_seed_zero_not_an_error() -> void:
	# "Pick one for me" is arbitrary(); an empty string is a real, reproducible world.
	var config := WorldSeed.from_text("")

	assert_eq(config.value, 0)
	assert_eq(config.text, "")
	assert_eq(config.validate(), "")


func test_new_configurations_pin_the_builds_generation_version() -> void:
	assert_eq(WorldSeed.from_text(_TYPED_TEXT).generation_version,
			SaveVersion.GENERATION_VERSION)
	assert_eq(WorldSeed.from_value(7).generation_version, SaveVersion.GENERATION_VERSION)
	assert_eq(WorldSeed.arbitrary().generation_version, SaveVersion.GENERATION_VERSION)


func test_arbitrary_seeds_differ_between_calls() -> void:
	# It picks which world to create; two new worlds in a row must not be the same one.
	var first := WorldSeed.arbitrary()
	var second := WorldSeed.arbitrary()

	assert_ne(first.value, second.value)
	assert_eq(first.validate(), "")


func test_an_arbitrary_seed_can_be_typed_back_in() -> void:
	var config := WorldSeed.arbitrary()

	var retyped := WorldSeed.from_text(config.display_text())

	assert_eq(retyped.value, config.value)


func test_display_text_prefers_what_was_typed() -> void:
	assert_eq(WorldSeed.from_text(_TYPED_TEXT).display_text(), _TYPED_TEXT)
	assert_eq(WorldSeed.from_value(-42).display_text(), "-42")


func test_validate_rejects_text_that_no_longer_hashes_to_the_value() -> void:
	# The drift this rule exists to catch: the displayed seed would create a different
	# world than the one it is displayed for.
	var config := WorldSeed.new(WorldHash.seed_from_text(_TYPED_TEXT) + 1, _TYPED_TEXT)

	assert_true(config.validate().contains("does not hash"), config.validate())


func test_validate_rejects_an_untrimmed_or_overlong_text() -> void:
	var untrimmed := WorldSeed.new(WorldHash.seed_from_text(_TYPED_TEXT), " " + _TYPED_TEXT)
	var overlong_text := "x".repeat(WorldSeed.MAX_TEXT_LENGTH + 1)
	var overlong := WorldSeed.new(WorldHash.seed_from_text(overlong_text), overlong_text)

	assert_true(untrimmed.validate().contains("trimmed"), untrimmed.validate())
	assert_true(overlong.validate().contains("longer than"), overlong.validate())


func test_validate_rejects_a_non_positive_generation_version() -> void:
	var config := WorldSeed.new(1, "", 0)

	assert_eq(config.validate(), "generation_version must be positive")


func test_seeds_match_on_value_and_generation_version_only() -> void:
	var typed := WorldSeed.from_text(_NUMERIC_TEXT)
	var from_link := WorldSeed.from_value(12345)

	# Same world reached two different ways: provenance differs, identity does not.
	assert_true(typed.matches(from_link))
	assert_eq(typed.mismatch_reason(from_link), "")


func test_mismatch_reason_names_what_differs() -> void:
	var config := WorldSeed.new(12345, "", 1)

	assert_true(config.mismatch_reason(WorldSeed.new(999, "", 1)).contains("seed differs"))
	assert_true(config.mismatch_reason(WorldSeed.new(12345, "", 2))
			.contains("generation version differs"))
	assert_false(config.mismatch_reason(null).is_empty())
	assert_false(config.matches(WorldSeed.new(12345, "", 2)))


func test_rng_for_gives_each_key_its_own_stream() -> void:
	var config := WorldSeed.from_value(12345)

	var loot := config.rng_for("loot")
	var spawns := config.rng_for("spawns")

	assert_ne(loot.next_u64(), spawns.next_u64())
	# Same world, same key, same sequence — a reloaded world resumes the same rolls.
	assert_eq(config.rng_for("loot").next_u64(), WorldSeed.from_value(12345)
			.rng_for("loot").next_u64())


func test_header_round_trip_preserves_the_whole_identity() -> void:
	var config := WorldSeed.new(WorldHash.seed_from_text(_TYPED_TEXT), _TYPED_TEXT, 1)

	var restored := WorldSeed.from_header(config.to_header())

	assert_not_null(restored)
	assert_eq(restored.value, config.value)
	assert_eq(restored.text, config.text)
	assert_eq(restored.generation_version, config.generation_version)
	assert_eq(restored.validate(), "")


func test_header_is_a_valid_save_header_and_carries_extras() -> void:
	var header := WorldSeed.from_text(_TYPED_TEXT).to_header({"world_name": "test"})

	assert_eq(SaveVersion.validate_header(header), "")
	assert_eq(int(header["world_format_version"]), SaveVersion.WORLD_FORMAT_VERSION)
	assert_eq(header["world_name"], "test")


func test_a_worlds_own_generation_version_survives_a_newer_build() -> void:
	# docs/persistence.md §3: a world keeps generating with the version it was created
	# with, so the header's value wins over the build's constant.
	var older := WorldSeed.new(12345, "", SaveVersion.GENERATION_VERSION + 1)

	var header := older.to_header()
	var restored := WorldSeed.from_header(header)

	assert_eq(int(header["generation_version"]), SaveVersion.GENERATION_VERSION + 1)
	assert_eq(restored.generation_version, SaveVersion.GENERATION_VERSION + 1)


func test_from_header_rejects_a_malformed_header() -> void:
	_log.start_capture()
	var restored := WorldSeed.from_header({"seed": 1})
	var records: Array = _log.take_capture()

	assert_null(restored)
	assert_size(records, 1)


func test_from_header_tolerates_a_header_without_seed_text() -> void:
	# Headers written before the field existed, and any header built by SaveVersion
	# directly, still load — the numeric seed is the identity.
	var restored := WorldSeed.from_header(SaveVersion.make_header(12345))

	assert_not_null(restored)
	assert_eq(restored.value, 12345)
	assert_eq(restored.text, "")
	assert_eq(restored.display_text(), "12345")


func test_to_context_names_the_world_for_a_log_line() -> void:
	var context := WorldSeed.from_text(_NUMERIC_TEXT).to_context()

	assert_eq(context["seed"], 12345)
	assert_eq(context["seed_text"], _NUMERIC_TEXT)
	assert_eq(context["gen_version"], SaveVersion.GENERATION_VERSION)
