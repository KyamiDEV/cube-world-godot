extends TestCase
## Guards the RNG rule from docs/rng.md (brick 015): simulation code never calls the
## engine's global randomness.
##
## `randi()`, `randf()`, `randomize()`, `RandomNumberGenerator`, `Array.pick_random()`
## and `Array.shuffle()` are seeded from process state and are engine implementation
## details. One of them anywhere in generation or authoritative gameplay makes a world
## unreproducible — and the symptom appears much later, as terrain that differs between
## a client and the server.

## Layers where every random draw must come from DeterministicRng or WorldHash.
const SIMULATION_LAYERS: PackedStringArray = [
	"core", "world", "gameplay", "ai", "network", "server", "autoload",
]

## Call fragments that indicate engine-global randomness.
const FORBIDDEN_CALLS: PackedStringArray = [
	"randomize(",
	"randi(",
	"randi_range(",
	"randf(",
	"randf_range(",
	"randfn(",
	"rand_from_seed(",
	"RandomNumberGenerator",
	".pick_random(",
	".shuffle(",
]


func test_simulation_layers_use_no_engine_global_randomness() -> void:
	var violations: PackedStringArray = []
	for layer in SIMULATION_LAYERS:
		for path in _collect_scripts("res://" + layer):
			var source := FileAccess.get_file_as_string(path)
			for fragment in FORBIDDEN_CALLS:
				if _contains_outside_comments(source, fragment):
					violations.append("%s uses %s" % [path, fragment])
	assert_size(violations, 0,
			"engine randomness in simulation code: " + " | ".join(violations))


func test_the_guard_itself_detects_a_violation() -> void:
	# A scanner that can never fire is worse than no scanner, because it reads as
	# coverage. This pins the detection, not the code base.
	var sample := "func roll() -> int:\n\treturn randi_range(1, 6)\n"
	assert_true(_contains_outside_comments(sample, "randi_range("),
			"a real call is detected")
	assert_false(_contains_outside_comments("# never call randi_range( here\n",
			"randi_range("), "a mention in a comment is not a call")
	assert_false(_contains_outside_comments("## `randf()` is forbidden\n", "randf("),
			"a mention in a doc comment is not a call")


func test_forbidden_list_covers_the_obvious_entry_points() -> void:
	for fragment in ["randi(", "randf(", "randomize(", "RandomNumberGenerator"]:
		assert_has(FORBIDDEN_CALLS, fragment)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## True when the fragment appears on a line that is not a comment. Documentation and
## rationale routinely name these functions in order to forbid them.
func _contains_outside_comments(source: String, fragment: String) -> bool:
	for line in source.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		# Drop a trailing comment before looking; a code line may explain itself.
		var comment_at := stripped.find("#")
		var code := stripped.substr(0, comment_at) if comment_at >= 0 else stripped
		if code.contains(fragment):
			return true
	return false


func _collect_scripts(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				found.append_array(_collect_scripts(full))
			elif entry.ends_with(".gd"):
				found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
