extends TestCase
## Enforces the dependency direction defined in docs/architecture.md (brick 011).
##
## Scans every project .gd, .tscn and .tres file for `res://` references and fails when
## a file names a path in a layer its own layer is not allowed to depend on. Scenes and
## resources are included because a scene is how a script from another layer most often
## sneaks in.
##
## This is a floor, not a proof: references made through a global `class_name`, an
## autoload, or a scene file carry no path and are invisible here.

## Layer -> layers it may reference. A layer may always reference itself.
const ALLOWED: Dictionary = {
	"core": ["core"],
	"autoload": ["autoload", "core"],
	"world": ["world", "core"],
	"gameplay": ["gameplay", "core"],
	"ai": ["ai", "core", "gameplay", "world"],
	"network": ["network", "core", "gameplay", "world"],
	"client": ["client", "core", "gameplay", "world", "network"],
	"server": ["server", "core", "gameplay", "world", "ai", "network"],
}

## Layers whose own files are exempt: test and tooling code observes from outside.
const UNRESTRICTED_SOURCES: PackedStringArray = ["tests", "tools"]

## Top-level directories that are not ours to police.
const IGNORED_ROOTS: PackedStringArray = ["addons", "reference", "assets", "data"]

const SCANNED_EXTENSIONS: PackedStringArray = [".gd", ".tscn", ".tres"]

var _references: Dictionary = {}  ## source path -> PackedStringArray of res:// targets


func before_all() -> void:
	for path in _collect_files("res://"):
		_references[path] = _extract_references(path)


func test_scan_found_project_scripts() -> void:
	# A silent scan failure would make every other assertion here vacuous.
	assert_true(_references.size() >= 3,
			"scanner found project files (found %d)" % _references.size())

	# The violation check is vacuous if nothing references anything, so assert that
	# the scan actually resolved cross-file references somewhere.
	var with_references := 0
	for path in _references:
		if not (_references[path] as PackedStringArray).is_empty():
			with_references += 1
	assert_true(with_references >= 1,
			"at least one file references another by res:// path (found %d)" % with_references)


func test_no_layer_violations() -> void:
	for source in _references:
		var source_layer := _layer_of(source)
		if source_layer.is_empty() or UNRESTRICTED_SOURCES.has(source_layer):
			continue
		if not ALLOWED.has(source_layer):
			fail("%s sits in unknown layer '%s'" % [source, source_layer])
			continue
		var allowed: Array = ALLOWED[source_layer]
		for target in _references[source]:
			var target_layer := _layer_of(target)
			if target_layer.is_empty() or IGNORED_ROOTS.has(target_layer):
				continue
			assert_true(allowed.has(target_layer),
					"%s (%s) may not reference %s (%s)" % [
							source, source_layer, target, target_layer])


func test_allowed_table_is_acyclic_in_the_directions_that_matter() -> void:
	# These are the edges that would let authority or presentation leak sideways.
	# Asserting them separately means a careless edit to ALLOWED fails loudly.
	assert_false((ALLOWED["core"] as Array).has("gameplay"), "core must not know gameplay")
	assert_false((ALLOWED["core"] as Array).has("world"), "core must not know world")
	assert_false((ALLOWED["world"] as Array).has("gameplay"), "world must not know gameplay")
	assert_false((ALLOWED["gameplay"] as Array).has("world"), "gameplay must not know world")
	assert_false((ALLOWED["gameplay"] as Array).has("network"),
			"gameplay must stay unit-testable without the network layer")
	for layer in ALLOWED:
		if layer != "client":
			assert_false((ALLOWED[layer] as Array).has("client"),
					"%s must not depend on the client" % layer)
		if layer != "server":
			assert_false((ALLOWED[layer] as Array).has("server"),
					"%s must not depend on the server" % layer)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## First path segment after res://, e.g. "res://core/math/x.gd" -> "core".
func _layer_of(res_path: String) -> String:
	var trimmed := res_path.trim_prefix("res://")
	var slash := trimmed.find("/")
	return trimmed.substr(0, slash) if slash > 0 else ""


func _extract_references(path: String) -> PackedStringArray:
	var source := FileAccess.get_file_as_string(path)
	var regex := RegEx.new()
	regex.compile('res://[A-Za-z0-9_./-]+')
	var found: PackedStringArray = []
	for match in regex.search_all(source):
		var target := match.get_string()
		if target != path and not found.has(target):
			found.append(target)
	return found


func _is_scanned(file_name: String) -> bool:
	for extension in SCANNED_EXTENSIONS:
		if file_name.ends_with(extension):
			return true
	return false


func _collect_files(dir_path: String) -> PackedStringArray:
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
					found.append_array(_collect_files(full))
			elif _is_scanned(entry):
				found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
