extends Node
## Compact structured logging service (backlog brick 006). Autoload name: `Log`.
##
## Format (one line, greppable):
##     E/net    t=00:12.480  invalid attack command  actor=17 reason=out_of_range
##     ^ ^      ^            ^                       ^
##     | channel|            message                 key=value context
##     level    uptime
##
## Rules (see docs/logging-and-errors.md):
## - `error()` and `warn()` also go through push_error()/push_warning() so the
##   debugger, CI and editor surface them. `info()`/`debug()`/`trace()` do not.
## - Never build an expensive message unguarded; use `is_enabled()` first.
## - Never log per-voxel or per-entity-per-frame at INFO or above.

enum Level {
	SILENT = 0,
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	DEBUG = 4,
	TRACE = 5,
}

## Known channels. Free strings are accepted, but a channel used in more than one
## file belongs here so log filtering stays discoverable.
const CH_BOOT := "boot"
const CH_CORE := "core"
const CH_WORLD := "world"
const CH_GEN := "gen"
const CH_VOXEL := "voxel"
const CH_STREAM := "stream"
const CH_PERSIST := "persist"
const CH_ENTITY := "entity"
const CH_COMBAT := "combat"
const CH_AI := "ai"
const CH_NET := "net"
const CH_SERVER := "server"
const CH_CLIENT := "client"
const CH_UI := "ui"
const CH_TEST := "test"

const _LEVEL_TAG: Dictionary = {
	Level.ERROR: "E",
	Level.WARN: "W",
	Level.INFO: "I",
	Level.DEBUG: "D",
	Level.TRACE: "T",
}

const _LEVEL_NAMES: Dictionary = {
	"silent": Level.SILENT,
	"error": Level.ERROR,
	"warn": Level.WARN,
	"info": Level.INFO,
	"debug": Level.DEBUG,
	"trace": Level.TRACE,
}

## Default level applied to any channel without an explicit override.
var _default_level: Level = Level.INFO

## channel -> Level. Overrides `_default_level`.
var _channel_levels: Dictionary = {}

## When true, records emitted lines instead of only printing them (tests).
var _capturing: bool = false
var _captured: Array[Dictionary] = []

var _started_msec: int = 0


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	if OS.is_debug_build():
		_default_level = Level.DEBUG
	_apply_cli_overrides(OS.get_cmdline_user_args() + OS.get_cmdline_args())


# ---------------------------------------------------------------------------
# Emission
# ---------------------------------------------------------------------------

func error(channel: String, message: String, context: Dictionary = {}) -> void:
	if _emit(Level.ERROR, channel, message, context):
		push_error(_format(Level.ERROR, channel, message, context))


func warn(channel: String, message: String, context: Dictionary = {}) -> void:
	if _emit(Level.WARN, channel, message, context):
		push_warning(_format(Level.WARN, channel, message, context))


func info(channel: String, message: String, context: Dictionary = {}) -> void:
	_emit(Level.INFO, channel, message, context)


func debug(channel: String, message: String, context: Dictionary = {}) -> void:
	_emit(Level.DEBUG, channel, message, context)


func trace(channel: String, message: String, context: Dictionary = {}) -> void:
	_emit(Level.TRACE, channel, message, context)


## Logs an error and returns `condition`. Use for recoverable validation on the
## authoritative path:
##     if not Log.check(cmd.is_valid(), Log.CH_NET, "bad command", {"peer": id}):
##         return
func check(condition: bool, channel: String, message: String, context: Dictionary = {}) -> bool:
	if not condition:
		error(channel, message, context)
	return condition


## A violated invariant is a programming error, not a runtime condition. Logs an
## error always, and breaks into the debugger in debug builds.
func invariant(condition: bool, channel: String, message: String, context: Dictionary = {}) -> void:
	if condition:
		return
	error(channel, "INVARIANT: " + message, context)
	assert(condition, message)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

func set_default_level(level: Level) -> void:
	_default_level = level


func set_channel_level(channel: String, level: Level) -> void:
	_channel_levels[channel] = level


func clear_channel_levels() -> void:
	_channel_levels.clear()


func get_level(channel: String) -> Level:
	return _channel_levels.get(channel, _default_level)


func is_enabled(channel: String, level: Level) -> bool:
	return level <= get_level(channel)


## Parses `--log-level=debug` and `--log=net:trace,world:warn` from the command line.
func _apply_cli_overrides(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--log-level="):
			var name := arg.get_slice("=", 1).to_lower()
			if _LEVEL_NAMES.has(name):
				_default_level = _LEVEL_NAMES[name]
			else:
				push_warning("Log: unknown --log-level '%s'" % name)
		elif arg.begins_with("--log="):
			for pair in arg.get_slice("=", 1).split(",", false):
				var channel := pair.get_slice(":", 0)
				var name := pair.get_slice(":", 1).to_lower()
				if _LEVEL_NAMES.has(name):
					_channel_levels[channel] = _LEVEL_NAMES[name]
				else:
					push_warning("Log: unknown level '%s' for channel '%s'" % [name, channel])


# ---------------------------------------------------------------------------
# Test capture
# ---------------------------------------------------------------------------

func start_capture() -> void:
	_capturing = true
	_captured.clear()


## Returns the captured records and stops capturing.
func take_capture() -> Array[Dictionary]:
	var out := _captured.duplicate()
	_captured.clear()
	_capturing = false
	return out


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Returns true when the record passed the level filter.
func _emit(level: Level, channel: String, message: String, context: Dictionary) -> bool:
	if not is_enabled(channel, level):
		return false
	if _capturing:
		_captured.append({
			"level": level,
			"channel": channel,
			"message": message,
			"context": context.duplicate(),
		})
	print(_format(level, channel, message, context))
	return true


func _format(level: Level, channel: String, message: String, context: Dictionary) -> String:
	var line := "%s/%-7s t=%s  %s" % [
		_LEVEL_TAG.get(level, "?"), channel, _uptime_string(), message]
	if not context.is_empty():
		line += "  " + _format_context(context)
	return line


func _format_context(context: Dictionary) -> String:
	var parts: PackedStringArray = []
	var keys: Array = context.keys()
	keys.sort()  # stable ordering keeps log diffs and test assertions deterministic
	for key in keys:
		parts.append("%s=%s" % [key, _format_value(context[key])])
	return " ".join(parts)


func _format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return "%.4f" % value
		TYPE_VECTOR3:
			var v: Vector3 = value
			return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(value)
			return "\"%s\"" % s if s.contains(" ") else s
		_:
			return str(value)


func _uptime_string() -> String:
	var msec := Time.get_ticks_msec() - _started_msec
	# Truncating integer division is the intent here.
	@warning_ignore_start("integer_division")
	var minutes := msec / 60000
	var seconds := (msec / 1000) % 60
	@warning_ignore_restore("integer_division")
	return "%02d:%02d.%03d" % [minutes, seconds, msec % 1000]
