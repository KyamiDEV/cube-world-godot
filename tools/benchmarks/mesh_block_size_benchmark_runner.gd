extends RefCounted
## The actual measurement logic for `benchmark_mesh_block_size.gd` (brick 052).
##
## Split out of the `--script` entry file on purpose: `VoxelTerrainBuilder`, `BlockSet`,
## and `VoxelTerrainMetrics` all call the `Log` autoload internally, and a file passed
## directly to `--script` is compiled by the engine *before* project autoloads are
## registered as global identifiers — so a script statically typing one of those classes
## at the top level of the entry file fails with "Identifier not found: Log", cascading
## into every dependency that also references it. A script reached through a runtime
## `load()` call (as `tests/run_tests.gd` already does for every `test_*.gd` file) compiles
## fine, since autoloads are live by the time `_initialize()` starts running and calls
## `load()`. Confirmed empirically this brick; not documented anywhere upstream. Any future
## `tools/**/*.gd` entry script that wants to call Log-touching project code must keep this
## same split — a thin entry script with no static references to such classes, plus a
## `load()`ed worker that does the real work.
##
## Settle detection deliberately watches `engine_snapshot()`'s `memory_pools.block_count`
## and `tasks` (all queues at 0), not `terrain_snapshot()`'s `updated_blocks` — empirically
## (this brick) `updated_blocks` reads as "blocks updated on this specific tick", not a
## running total: it was observed at a constant 0 across an entire run that still grew
## `block_count` from 0 to hundreds and printed real terrain statistics at the end,
## meaning the actual update burst happened between two polls and was never sampled.
## `block_count` (monotonically non-decreasing while streaming is in flight) plus every
## `tasks` queue reading empty is a direct "no more in-flight background work" signal
## instead.

const _SETTLE_FRAMES := 30
const _MAX_WAIT_FRAMES := 3000


## Returns the process exit code (0 = settled, 1 = build failure or timeout).
func run(tree: SceneTree, mesh_block_size: int, radius: int) -> int:
	var registry := BlockSet.load_default()
	if not registry.has_block(VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID):
		printerr("benchmark requires the default block set to be loadable")
		return 1

	var terrain := VoxelTerrainBuilder.build(registry, null, mesh_block_size)
	if terrain == null:
		printerr("VoxelTerrainBuilder.build() rejected the given mesh_block_size or registry")
		return 1
	var viewer := VoxelViewerBuilder.build()
	viewer.view_distance = radius

	print("=== mesh block size benchmark ===")
	print("mesh_block_size=", mesh_block_size)
	print("view_radius=", radius)

	var start_usec := Time.get_ticks_usec()
	tree.root.add_child(terrain)
	tree.root.add_child(viewer)

	var last_block_count := -1
	var stable_frames := 0
	var frame := 0
	while frame < _MAX_WAIT_FRAMES:
		await tree.process_frame
		frame += 1
		var engine_stats := VoxelTerrainMetrics.engine_snapshot()
		var memory_pools: Dictionary = engine_stats.get(VoxelTerrainMetrics.KEY_MEMORY_POOLS, {})
		var block_count: int = memory_pools.get("block_count", -1)
		var tasks: Dictionary = engine_stats.get(VoxelTerrainMetrics.KEY_TASKS, {})
		var tasks_idle := true
		for key in tasks:
			if int(tasks[key]) != 0:
				tasks_idle = false
				break
		if frame % 100 == 0:
			print("progress frame=%d block_count=%d tasks_idle=%s elapsed_ms=%.0f" % [
					frame, block_count, tasks_idle, (Time.get_ticks_usec() - start_usec) / 1000.0])
		if block_count == last_block_count and tasks_idle:
			stable_frames += 1
			if stable_frames >= _SETTLE_FRAMES:
				break
		else:
			stable_frames = 0
			last_block_count = block_count

	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var settled := stable_frames >= _SETTLE_FRAMES

	print("settled=", settled)
	print("frames=", frame)
	print("elapsed_ms=%.2f" % (elapsed_usec / 1000.0))
	print("terrain_stats=", VoxelTerrainMetrics.terrain_snapshot(terrain))
	print("engine_stats=", VoxelTerrainMetrics.engine_snapshot())
	print("RESULT=OK" if settled else "RESULT=TIMEOUT")
	return 0 if settled else 1
