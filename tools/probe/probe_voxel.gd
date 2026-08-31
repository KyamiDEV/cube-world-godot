extends SceneTree
## Verification probe for the Voxel Tools engine module (backlog brick 003).
##
## Usage:
##   godot --headless --script res://tools/probe/probe_voxel.gd
##
## Exit code 0 = every required class and the expected module version are present.
## Exit code 1 = mismatch; the output lists what is missing or wrong.

const REQUIRED_VERSION := Vector3i(1, 7, 0)

## Classes the architecture in CLAUDE.md §1 depends on directly.
const REQUIRED_CLASSES: PackedStringArray = [
	"VoxelTerrain",
	"VoxelMesherBlocky",
	"VoxelBlockyLibrary",
	"VoxelBlockyModel",
	"VoxelBlockyModelCube",
	"VoxelBlockyModelMesh",
	"VoxelInstancer",
	"VoxelInstanceLibrary",
	"VoxelViewer",
	"VoxelBoxMover",
	"VoxelStreamSQLite",
	"VoxelGeneratorScript",
	"VoxelTool",
	"VoxelToolTerrain",
	"VoxelBuffer",
	"VoxelRaycastResult",
]


func _initialize() -> void:
	var failures: PackedStringArray = []

	print("=== Voxel Tools probe ===")
	print("engine=", Engine.get_version_info()["string"], " hash=",
			str(Engine.get_version_info()["hash"]).substr(0, 9))

	if not Engine.has_singleton("VoxelEngine"):
		failures.append("VoxelEngine singleton missing: the Voxel Tools module is not compiled in.")
		_finish(failures)
		return

	var ve := Engine.get_singleton("VoxelEngine")
	var version := Vector3i(
		ve.get_version_major(), ve.get_version_minor(), ve.get_version_patch())
	print("voxel_version=%d.%d.%d" % [version.x, version.y, version.z])
	print("voxel_edition=", ve.get_version_edition())
	print("voxel_status=", ve.get_version_status())
	print("voxel_git_hash=", ve.get_version_git_hash())
	print("voxel_thread_count=", ve.get_thread_count())

	if version.x != REQUIRED_VERSION.x or version.y != REQUIRED_VERSION.y:
		failures.append("voxel version %d.%d.%d != required %d.%d.x" % [
			version.x, version.y, version.z, REQUIRED_VERSION.x, REQUIRED_VERSION.y])

	if ve.get_version_edition() != "Module":
		failures.append("voxel edition is '%s', expected 'Module' (GDExtension builds are not the target)."
				% ve.get_version_edition())

	var missing: PackedStringArray = []
	for cls in REQUIRED_CLASSES:
		if not ClassDB.class_exists(cls):
			missing.append(cls)
	if missing.is_empty():
		print("required_classes=%d/%d present" % [REQUIRED_CLASSES.size(), REQUIRED_CLASSES.size()])
	else:
		failures.append("missing classes: " + ", ".join(missing))

	var registered := 0
	for cls in ClassDB.get_class_list():
		if cls.begins_with("Voxel") or cls.begins_with("ZN_"):
			registered += 1
	print("registered_voxel_classes=", registered)

	_finish(failures)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("RESULT=OK")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("RESULT=FAIL")
		quit(1)
