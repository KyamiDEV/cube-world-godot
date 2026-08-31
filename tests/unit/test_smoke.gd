extends TestCase
## First smoke test (backlog brick 008): the harness runs, and the runtime the
## whole project depends on is the contracted one.

const REQUIRED_ENGINE := Vector3i(4, 7, 2)
const REQUIRED_ENGINE_HASH_PREFIX := "ed1daf0bf"
const REQUIRED_VOXEL := Vector2i(1, 7)


func test_harness_assertions_work() -> void:
	assert_true(true, "assert_true accepts true")
	assert_false(false, "assert_false accepts false")
	assert_eq(2 + 2, 4, "integers compare")
	assert_ne("a", "b", "strings differ")
	assert_almost_eq(0.1 + 0.2, 0.3, 1e-9, "floats compare with tolerance")
	assert_null(null)
	assert_not_null(self)
	assert_has([1, 2, 3], 2, "array contains")
	assert_has({"k": 1}, "k", "dictionary has key")
	assert_size([1, 2, 3], 3, "array size")
	assert_in_range(0.5, 0.0, 1.0)


func test_assert_eq_is_type_strict() -> void:
	# 1 == 1.0 in GDScript. The harness must not let a float sneak through where an
	# integer voxel coordinate is expected, so assert_eq compares types too.
	assert_false(_values_equal(1, 1.0), "int and float are not equal for assertions")
	assert_true(_values_equal(1, 1), "same type and value are equal")


func test_engine_build_is_contracted() -> void:
	var info := Engine.get_version_info()
	assert_eq(int(info["major"]), REQUIRED_ENGINE.x, "engine major")
	assert_eq(int(info["minor"]), REQUIRED_ENGINE.y, "engine minor")
	assert_eq(int(info["patch"]), REQUIRED_ENGINE.z, "engine patch")
	assert_true(str(info["hash"]).begins_with(REQUIRED_ENGINE_HASH_PREFIX),
			"engine commit hash starts with " + REQUIRED_ENGINE_HASH_PREFIX)


func test_voxel_tools_module_is_available() -> void:
	if not assert_true(Engine.has_singleton("VoxelEngine"), "VoxelEngine singleton"):
		return
	@warning_ignore_start("unsafe_method_access")
	var ve := Engine.get_singleton("VoxelEngine")
	assert_eq(int(ve.get_version_major()), REQUIRED_VOXEL.x, "voxel major")
	assert_eq(int(ve.get_version_minor()), REQUIRED_VOXEL.y, "voxel minor")
	assert_eq(str(ve.get_version_edition()), "Module", "voxel edition")
	@warning_ignore_restore("unsafe_method_access")


func test_required_voxel_classes_exist() -> void:
	for cls in ["VoxelTerrain", "VoxelMesherBlocky", "VoxelBlockyLibrary",
			"VoxelInstancer", "VoxelViewer", "VoxelStreamSQLite", "VoxelTool"]:
		assert_true(ClassDB.class_exists(cls), "class %s is registered" % cls)


func test_log_autoload_is_registered() -> void:
	var tree := get_tree()
	assert_not_null(tree, "runner exposes the SceneTree")
	assert_true(tree.root.has_node("Log"), "Log autoload is present")


func test_async_tests_can_await_frames() -> void:
	var before := Engine.get_process_frames()
	await wait_frames(2)
	assert_true(Engine.get_process_frames() > before,
			"awaiting process frames advances the main loop")
