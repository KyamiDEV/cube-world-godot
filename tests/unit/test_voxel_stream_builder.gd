extends TestCase
## Covers world/persistence/voxel_stream_builder.gd (brick 048).

var _temp_paths: PackedStringArray = []


func after_each() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for path in _temp_paths:
			dir.remove(path.trim_prefix("user://"))
	_temp_paths.clear()


func _db_path(name: String) -> String:
	var path := "user://%s.sqlite" % name
	_temp_paths.append(path)
	return path


# ---------------------------------------------------------------------------

func test_rejects_an_empty_database_path() -> void:
	assert_null(VoxelStreamBuilder.build(""))


func test_builds_a_configured_stream() -> void:
	var path := _db_path("test_voxel_stream_builder_basic")
	var stream := VoxelStreamBuilder.build(path)

	assert_not_null(stream)
	assert_true(stream is VoxelStreamSQLite)
	assert_eq(stream.database_path, path)
	assert_false(stream.save_generator_output,
			"048: only deltas are saved — the generator can already reproduce the rest")
	assert_eq(stream.preferred_coordinate_format,
			VoxelStreamSQLite.COORDINATE_FORMAT_STRING_CSD,
			"048: unbounded range — world bounds are not decided yet (brick 050)")
	assert_true(stream.is_key_cache_enabled(),
			"048: sparse edited-block saves are exactly what the key cache speeds up")


func test_each_call_builds_an_independent_stream() -> void:
	var path_a := _db_path("test_voxel_stream_builder_a")
	var path_b := _db_path("test_voxel_stream_builder_b")

	var stream_a := VoxelStreamBuilder.build(path_a)
	var stream_b := VoxelStreamBuilder.build(path_b)

	assert_not_null(stream_a)
	assert_not_null(stream_b)
	assert_eq(stream_a.database_path, path_a)
	assert_eq(stream_b.database_path, path_b)
