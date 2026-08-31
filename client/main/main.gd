extends Node
## Boot entry point (backlog brick 004).
##
## Deliberately thin: it verifies the runtime baseline and reports it, then hands
## off. Subsystems are wired in later bricks and must NOT accumulate here
## (CLAUDE.md §2).

@onready var _status: Label = %StatusLabel


func _ready() -> void:
	var report := _collect_boot_report()
	for line in report:
		Log.info(Log.CH_BOOT, line)
	_status.text = "\n".join(report)


## Returns the runtime facts a human or a log needs to confirm the right binary
## and module are running. Pure: no side effects, so tests can assert on it.
func _collect_boot_report() -> PackedStringArray:
	var info := Engine.get_version_info()
	var lines: PackedStringArray = []
	lines.append("CubeWorld-Godot — boot OK")
	lines.append("engine %s [%s]" % [info["string"], str(info["hash"]).substr(0, 9)])
	lines.append("precision %s" % ("double" if _is_double_precision() else "single"))

	if Engine.has_singleton("VoxelEngine"):
		# VoxelEngine is an engine singleton exposed as a bare Object; its accessors
		# cannot be statically typed from GDScript.
		@warning_ignore_start("unsafe_method_access")
		var ve := Engine.get_singleton("VoxelEngine")
		lines.append("voxel tools %d.%d.%d (%s)" % [
			ve.get_version_major(), ve.get_version_minor(), ve.get_version_patch(),
			ve.get_version_edition()])
		@warning_ignore_restore("unsafe_method_access")
	else:
		lines.append("voxel tools MISSING")

	lines.append("renderer %s" % ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "unknown"))
	lines.append("physics 3d %s" % ProjectSettings.get_setting(
			"physics/3d/physics_engine", "unknown"))
	lines.append("headless %s" % str(DisplayServer.get_name() == "headless"))
	return lines


func _is_double_precision() -> bool:
	return "Double Precision" in PackedStringArray(
			ProjectSettings.get_setting("application/config/features", PackedStringArray()))
