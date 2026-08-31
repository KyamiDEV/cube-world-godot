extends SceneTree
## Headless test runner (backlog brick 008).
##
## Usage:
##   godot --headless --script res://tests/run_tests.gd -- [options]
##
## Options (after `--`):
##   --test-filter=<substring>   run only test methods whose name contains it
##   --test-file=<substring>     run only test files whose path contains it
##   --test-dir=<res://path>     root to scan (default res://tests)
##   --verbose                   list passing tests too
##
## Exit code 0 = every test passed and at least one test ran.

const DEFAULT_ROOT := "res://tests"

var _root: String = DEFAULT_ROOT
var _method_filter: String = ""
var _file_filter: String = ""
var _verbose: bool = false

var _files_run: int = 0
var _tests_run: int = 0
var _tests_failed: int = 0
var _assertions: int = 0
var _failure_lines: PackedStringArray = []


func _initialize() -> void:
	_parse_args(OS.get_cmdline_user_args())
	# Started, not awaited: the runner must keep returning to the main loop so
	# tests that await process frames can complete.
	_run_all()


func _process(_delta: float) -> bool:
	return false  # the run coroutine calls quit() when it finishes


func _run_all() -> void:
	var files := _collect_test_files(_root)
	files.sort()

	for path in files:
		if not _file_filter.is_empty() and not path.contains(_file_filter):
			continue
		await _run_file(path)

	_report()


func _run_file(path: String) -> void:
	var script := load(path) as Script
	# load() hands back a resource even for a file that failed to compile, so
	# can_instantiate() is what actually separates "loaded" from "usable". Without
	# this the runner would skip a broken test file and still report success.
	if script == null or not script.can_instantiate():
		_fail_file(path, "does not compile")
		return
	var instance: Variant = script.new()
	if not (instance is TestCase):
		_fail_file(path, "does not extend TestCase")
		return

	var case := instance as TestCase
	var methods: PackedStringArray = []
	for entry in script.get_script_method_list():
		var name: String = entry["name"]
		if name.begins_with("test_") and not methods.has(name):
			if _method_filter.is_empty() or name.contains(_method_filter):
				methods.append(name)
	if methods.is_empty():
		return

	_files_run += 1
	print(path)
	case.before_all()
	for method in methods:
		await _run_method(case, method)
	case.after_all()


func _run_method(case: TestCase, method: String) -> void:
	case._runner_begin_test()
	case.before_each()
	# A test method may or may not be a coroutine; awaiting a plain return value is
	# harmless and keeps both shapes on one path.
	@warning_ignore("redundant_await")
	await case.call(method)
	case.after_each()
	case._runner_end_test()

	var failures := case._runner_failures()
	var assertion_count := case._runner_assertion_count()
	# A method that asserted nothing did not pass — it aborted. A GDScript runtime
	# error unwinds the method without stopping the runner, so "zero assertions" is
	# the only signal that the body never finished. Reporting it as a pass is how a
	# broken dependency turns a whole suite green.
	if assertion_count == 0 and failures.is_empty():
		failures = PackedStringArray([
			"no assertions were recorded — the method aborted, or it asserts nothing"])

	_tests_run += 1
	_assertions += assertion_count
	if failures.is_empty():
		if _verbose:
			print("  ok   %s (%d)" % [method, assertion_count])
	else:
		_tests_failed += 1
		print("  FAIL %s" % method)
		for failure in failures:
			print("        " + failure)
			_failure_lines.append("%s::%s — %s" % [
					case.get_script().resource_path.get_file(), method, failure])


func _fail_file(path: String, reason: String) -> void:
	_tests_failed += 1
	print("%s\n  FAIL <file> %s" % [path, reason])
	_failure_lines.append("%s — %s" % [path, reason])


func _report() -> void:
	print("")
	print("files=%d tests=%d assertions=%d failed=%d" % [
			_files_run, _tests_run, _assertions, _tests_failed])
	if _tests_run == 0:
		printerr("no tests ran (filters: file='%s' method='%s')" % [
				_file_filter, _method_filter])
		print("RESULT=FAIL")
		quit(1)
		return
	if _tests_failed > 0:
		for line in _failure_lines:
			printerr("FAIL: " + line)
		print("RESULT=FAIL")
		quit(1)
		return
	print("RESULT=OK")
	quit(0)


func _parse_args(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--test-filter="):
			_method_filter = arg.get_slice("=", 1)
		elif arg.begins_with("--test-file="):
			_file_filter = arg.get_slice("=", 1)
		elif arg.begins_with("--test-dir="):
			_root = arg.get_slice("=", 1)
		elif arg == "--verbose":
			_verbose = true


func _collect_test_files(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("test root not found: ", dir_path)
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				found.append_array(_collect_test_files(full))
			elif entry.begins_with("test_") and entry.ends_with(".gd"):
				found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
