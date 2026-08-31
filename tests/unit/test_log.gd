extends TestCase
## Covers the logging service from brick 006 (autoload/log.gd).

var _log: Node
var _saved_default: int
var _saved_channels: Dictionary


func before_each() -> void:
	_log = get_tree().root.get_node("Log")
	_saved_default = _log.get_level("__unset__")
	_saved_channels = _log._channel_levels.duplicate()


func after_each() -> void:
	# The autoload is shared process-wide; leaking a level override would make the
	# next test order-dependent.
	_log.set_default_level(_saved_default)
	_log.clear_channel_levels()
	for channel in _saved_channels:
		_log.set_channel_level(channel, _saved_channels[channel])
	_log.take_capture()


func test_level_ordering_is_ascending_severity() -> void:
	assert_true(_log.Level.ERROR < _log.Level.WARN, "ERROR is more severe than WARN")
	assert_true(_log.Level.WARN < _log.Level.INFO)
	assert_true(_log.Level.INFO < _log.Level.DEBUG)
	assert_true(_log.Level.DEBUG < _log.Level.TRACE)
	assert_eq(int(_log.Level.SILENT), 0, "SILENT is zero so it disables everything")


func test_default_level_filters_lower_levels() -> void:
	_log.set_default_level(_log.Level.WARN)
	assert_true(_log.is_enabled("anything", _log.Level.ERROR), "ERROR passes at WARN")
	assert_true(_log.is_enabled("anything", _log.Level.WARN), "WARN passes at WARN")
	assert_false(_log.is_enabled("anything", _log.Level.INFO), "INFO is filtered at WARN")
	assert_false(_log.is_enabled("anything", _log.Level.TRACE), "TRACE is filtered at WARN")


func test_channel_override_beats_default() -> void:
	_log.set_default_level(_log.Level.ERROR)
	_log.set_channel_level("gen", _log.Level.TRACE)
	assert_true(_log.is_enabled("gen", _log.Level.TRACE), "overridden channel is verbose")
	assert_false(_log.is_enabled("net", _log.Level.INFO), "other channels keep the default")

	_log.clear_channel_levels()
	assert_false(_log.is_enabled("gen", _log.Level.TRACE), "clearing restores the default")


func test_silent_level_suppresses_everything() -> void:
	_log.set_default_level(_log.Level.SILENT)
	assert_false(_log.is_enabled("net", _log.Level.ERROR), "even ERROR is suppressed")


func test_capture_records_filtered_records_only() -> void:
	_log.set_default_level(_log.Level.INFO)
	_log.start_capture()
	_log.info("test", "kept")
	_log.debug("test", "dropped by the level filter")
	var records: Array = _log.take_capture()

	assert_size(records, 1, "only the passing record is captured")
	assert_eq(records[0]["message"], "kept")
	assert_eq(records[0]["channel"], "test")
	assert_eq(int(records[0]["level"]), int(_log.Level.INFO))


func test_capture_stores_context_by_value() -> void:
	_log.set_default_level(_log.Level.INFO)
	_log.start_capture()
	var context := {"actor": 7}
	_log.info("test", "event", context)
	context["actor"] = 99  # mutating after the call must not rewrite history
	var records: Array = _log.take_capture()

	assert_size(records, 1)
	assert_eq(int(records[0]["context"]["actor"]), 7, "context was copied, not aliased")


func test_take_capture_stops_capturing() -> void:
	_log.set_default_level(_log.Level.INFO)
	_log.start_capture()
	_log.info("test", "first")
	assert_size(_log.take_capture(), 1)
	_log.info("test", "second")
	assert_size(_log.take_capture(), 0, "nothing is recorded after take_capture()")


func test_context_formatting_is_key_sorted_and_stable() -> void:
	# Identical events must format identically regardless of insertion order,
	# otherwise log diffs between two runs are meaningless.
	var a: String = _log._format_context({"zulu": 1, "alpha": 2})
	var b: String = _log._format_context({"alpha": 2, "zulu": 1})
	assert_eq(a, b, "key order does not affect output")
	assert_eq(a, "alpha=2 zulu=1", "keys are sorted")


func test_context_formatting_normalises_values() -> void:
	assert_eq(_log._format_value(1.5), "1.5000", "floats use fixed precision")
	assert_eq(_log._format_value(Vector3(1, 2, 3)), "(1.00,2.00,3.00)", "vectors are compact")
	assert_eq(_log._format_value("plain"), "plain", "simple strings are bare")
	assert_eq(_log._format_value("two words"), "\"two words\"", "spaced strings are quoted")


func test_check_returns_condition_and_does_not_halt() -> void:
	_log.set_default_level(_log.Level.SILENT)  # keep push_error out of the test output
	assert_true(_log.check(true, "test", "should not log"), "check passes its condition through")
	assert_false(_log.check(false, "test", "expected failure"), "check reports false")
