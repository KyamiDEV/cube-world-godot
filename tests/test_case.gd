class_name TestCase
extends RefCounted
## Base class for every test (backlog brick 008).
##
## A test file is `tests/**/test_*.gd`, extends `TestCase`, and exposes methods
## named `test_*`. The runner (`tests/run_tests.gd`) instantiates the class once,
## then calls `before_all`, each `test_*` wrapped in `before_each`/`after_each`,
## and `after_all`.
##
## Assertions record failures instead of halting, so one test reports every
## problem it finds. A test method may `await`; the runner awaits its result.

## Failure messages recorded during the currently running test method.
var _failures: PackedStringArray = []
var _assertion_count: int = 0

## Nodes registered with `track_node()`, freed after the test method returns.
var _tracked_nodes: Array[Node] = []


# ---------------------------------------------------------------------------
# Lifecycle hooks — override as needed
# ---------------------------------------------------------------------------

func before_all() -> void:
	pass


func after_all() -> void:
	pass


func before_each() -> void:
	pass


func after_each() -> void:
	pass


# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

func assert_true(condition: bool, message: String = "") -> bool:
	return _record(condition, message, "expected true, got false")


func assert_false(condition: bool, message: String = "") -> bool:
	return _record(not condition, message, "expected false, got true")


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	return _record(_values_equal(actual, expected), message,
			"expected %s, got %s" % [_repr(expected), _repr(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> bool:
	return _record(not _values_equal(actual, unexpected), message,
			"expected a value other than %s" % _repr(unexpected))


## Float comparison with an explicit tolerance. Never compare floats with assert_eq.
func assert_almost_eq(actual: float, expected: float, tolerance: float = 1e-6,
		message: String = "") -> bool:
	return _record(absf(actual - expected) <= tolerance, message,
			"expected %s ± %s, got %s" % [expected, tolerance, actual])


func assert_null(value: Variant, message: String = "") -> bool:
	return _record(value == null, message, "expected null, got %s" % _repr(value))


func assert_not_null(value: Variant, message: String = "") -> bool:
	return _record(value != null, message, "expected non-null")


func assert_in_range(value: float, minimum: float, maximum: float,
		message: String = "") -> bool:
	return _record(value >= minimum and value <= maximum, message,
			"expected %s in [%s, %s]" % [value, minimum, maximum])


## Works for Array, Dictionary (keys), String and PackedStringArray.
func assert_has(container: Variant, element: Variant, message: String = "") -> bool:
	var found := false
	match typeof(container):
		TYPE_DICTIONARY:
			found = (container as Dictionary).has(element)
		TYPE_STRING, TYPE_STRING_NAME:
			found = String(container).contains(String(element))
		_:
			found = element in container
	return _record(found, message, "expected %s to contain %s" % [
			_repr(container), _repr(element)])


func assert_size(container: Variant, expected: int, message: String = "") -> bool:
	var actual: int = container.size()
	return _record(actual == expected, message,
			"expected size %d, got %d" % [expected, actual])


## Unconditional failure, for unreachable branches.
func fail(message: String) -> void:
	_record(false, message, "explicit failure")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Registers a node for automatic `queue_free()` after the test method.
func track_node(node: Node) -> Node:
	_tracked_nodes.append(node)
	return node


func get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## `await wait_frames(2)` — yields real process frames so nodes can tick.
func wait_frames(count: int = 1) -> void:
	var tree := get_tree()
	for _i in count:
		await tree.process_frame


# ---------------------------------------------------------------------------
# Runner interface
# ---------------------------------------------------------------------------

func _runner_begin_test() -> void:
	_failures.clear()
	_assertion_count = 0
	_tracked_nodes.clear()


func _runner_end_test() -> void:
	for node in _tracked_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_tracked_nodes.clear()


func _runner_failures() -> PackedStringArray:
	return _failures


func _runner_assertion_count() -> int:
	return _assertion_count


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _record(passed: bool, message: String, detail: String) -> bool:
	_assertion_count += 1
	if not passed:
		_failures.append(detail if message.is_empty() else "%s — %s" % [message, detail])
	return passed


## Typed equality: 1 and 1.0 are equal by `==` in GDScript, which hides real bugs
## in code that must distinguish an integer voxel coordinate from a float metre
## position, so the types must match too.
func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b


func _repr(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			return "\"%s\"" % value
		TYPE_NIL:
			return "null"
		_:
			return str(value)
