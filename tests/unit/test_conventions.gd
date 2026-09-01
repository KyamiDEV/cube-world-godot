extends TestCase
## Enforces the mechanically checkable parts of docs/conventions.md (brick 012).
##
## Covers file naming, the class_name <-> file name correspondence, the reserved bare
## names, and the stable-ID format. Style rules that need judgement (suffix choice,
## comment quality) stay on review.

## Top-level directories this project does not own.
const IGNORED_ROOTS: PackedStringArray = ["addons", "reference"]

## Shared test inputs and helpers, not test files (`docs/conventions.md` §6, brick 059).
## The runner only ever collects `test_*.gd`, so a file here named `test_` would be
## collected as a test that asserts nothing, and one not named `test_` is exactly right.
const FIXTURE_DIR := "res://tests/fixtures/"

## Generic names too ambiguous to claim in the flat global class namespace.
const RESERVED_BARE_NAMES: PackedStringArray = [
	"World", "Entity", "Player", "Item", "Block", "Chunk", "Camera", "Server",
	"Client", "State", "System", "Registry", "Config", "Utils",
]

## First segment of a stable ID. Extending this list is a documentation change.
const ID_DOMAINS: PackedStringArray = [
	"block", "item", "creature", "npc", "skill", "effect", "quest", "dialogue",
	"faction", "biome", "structure", "dungeon", "loot", "recipe", "sound", "ui",
]

var _scripts: PackedStringArray = []


func before_all() -> void:
	_scripts = _collect("res://", [".gd", ".tscn", ".tres"])


# ---------------------------------------------------------------------------
# File naming
# ---------------------------------------------------------------------------

func test_scan_found_files() -> void:
	assert_true(_scripts.size() >= 3, "scanner found files (found %d)" % _scripts.size())


func test_file_names_are_snake_case() -> void:
	var regex := RegEx.new()
	regex.compile("^_?[a-z0-9_]+\\.[a-z]+$")
	for path in _scripts:
		var file_name := path.get_file()
		assert_true(regex.search(file_name) != null,
				"%s is snake_case (no capitals, spaces or hyphens)" % path)


func test_directory_names_are_snake_case() -> void:
	var regex := RegEx.new()
	regex.compile("^[a-z0-9_]+$")
	for dir_path in _collect_dirs("res://"):
		var dir_name := dir_path.get_file()
		assert_true(regex.search(dir_name) != null, "%s is snake_case" % dir_path)


func test_test_files_are_named_test_subject() -> void:
	for path in _scripts:
		if not path.begins_with("res://tests/") or not path.ends_with(".gd"):
			continue
		var file_name := path.get_file()
		# The harness itself is not a test file, and neither is a fixture.
		if file_name in ["test_case.gd", "run_tests.gd"] or path.begins_with(FIXTURE_DIR):
			continue
		assert_true(file_name.begins_with("test_"),
				"%s is either named test_<subject>.gd or is not in tests/" % path)


func test_fixture_files_hold_no_tests() -> void:
	# The exemption above is only safe while it stays true: a `test_*` method in a
	# fixture file is a test the runner never collects and nobody ever sees fail.
	var regex := RegEx.new()
	regex.compile("(?m)^func[ \\t]+test_")
	var checked := 0
	for path in _scripts:
		if not path.begins_with(FIXTURE_DIR) or not path.ends_with(".gd"):
			continue
		checked += 1
		assert_null(regex.search(FileAccess.get_file_as_string(path)),
				"%s is a fixture, so its assertions belong in a test file the runner runs"
						% path)
	assert_true(checked >= 1, "the fixture scan found files (found %d)" % checked)


# ---------------------------------------------------------------------------
# class_name policy
# ---------------------------------------------------------------------------

func test_class_names_match_their_file_name() -> void:
	for entry in _declared_class_names():
		var path: String = entry["path"]
		var declared: String = entry["class_name"]
		var expected := _to_snake_case(declared) + ".gd"
		assert_eq(path.get_file(), expected,
				"%s declares class_name %s, so the file is named %s" % [
						path, declared, expected])


func test_class_names_are_pascal_case() -> void:
	var regex := RegEx.new()
	regex.compile("^[A-Z][A-Za-z0-9]*$")
	for entry in _declared_class_names():
		assert_true(regex.search(entry["class_name"]) != null,
				"%s declares PascalCase class_name (got '%s')" % [
						entry["path"], entry["class_name"]])


func test_no_reserved_bare_class_names() -> void:
	for entry in _declared_class_names():
		assert_false(RESERVED_BARE_NAMES.has(entry["class_name"]),
				"%s claims the reserved bare name '%s'; qualify it" % [
						entry["path"], entry["class_name"]])


func test_class_names_are_unique() -> void:
	var seen: Dictionary = {}
	for entry in _declared_class_names():
		var declared: String = entry["class_name"]
		assert_false(seen.has(declared),
				"class_name '%s' is declared by both %s and %s" % [
						declared, seen.get(declared, ""), entry["path"]])
		seen[declared] = entry["path"]


# ---------------------------------------------------------------------------
# Stable IDs
# ---------------------------------------------------------------------------

func test_id_validator_accepts_well_formed_ids() -> void:
	for id in ["item.sword.iron", "creature.goblin", "skill.dash", "biome.grassland",
			"block.stone", "quest.village_bandits_01", "loot.chest.dungeon.rare"]:
		assert_true(_is_valid_id(id), "%s is a valid stable ID" % id)


func test_id_validator_rejects_malformed_ids() -> void:
	var bad := {
		"Item.Sword.Iron": "capitals",
		"item-sword-iron": "hyphens",
		"sword_iron": "no domain segment",
		"item.sword.iron.": "trailing dot",
		"item..iron": "empty segment",
		"item.sword iron": "space",
		"weapon.sword": "unknown domain",
		"item.2handed": "segment starting with a digit",
		"": "empty",
	}
	for id in bad:
		assert_false(_is_valid_id(id), "'%s' is rejected: %s" % [id, bad[id]])


func test_id_domains_are_lower_case_and_unique() -> void:
	var seen: Dictionary = {}
	for domain in ID_DOMAINS:
		assert_eq(domain, domain.to_lower(), "domain '%s' is lower case" % domain)
		assert_false(seen.has(domain), "domain '%s' is listed once" % domain)
		seen[domain] = true


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Shared shape of the ID rule until the registry (brick 016) owns it: domain from
## the known list, then one or more snake_case segments not starting with a digit.
func _is_valid_id(id: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")
	if regex.search(id) == null:
		return false
	return ID_DOMAINS.has(id.get_slice(".", 0))


func _declared_class_names() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var regex := RegEx.new()
	regex.compile("(?m)^class_name[ \\t]+([A-Za-z_][A-Za-z0-9_]*)")
	for path in _scripts:
		if not path.ends_with(".gd"):
			continue
		var found := regex.search(FileAccess.get_file_as_string(path))
		if found != null:
			entries.append({"path": path, "class_name": found.get_string(1)})
	return entries


func _to_snake_case(pascal: String) -> String:
	var out := ""
	for i in pascal.length():
		var c := pascal[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			out += "_"
		out += c.to_lower()
	return out


func _collect(dir_path: String, extensions: Array) -> PackedStringArray:
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
				if not IGNORED_ROOTS.has(entry):
					found.append_array(_collect(full, extensions))
			else:
				for extension in extensions:
					if entry.ends_with(extension):
						found.append(full)
						break
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func _collect_dirs(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and dir.current_is_dir() and not IGNORED_ROOTS.has(entry):
			var full := dir_path.path_join(entry)
			found.append(full)
			found.append_array(_collect_dirs(full))
		entry = dir.get_next()
	dir.list_dir_end()
	return found
