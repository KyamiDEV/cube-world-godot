extends SceneTree
## Mesh block size benchmark harness (backlog brick 052; also used unchanged by 053).
##
## Usage:
##   godot --headless --script res://tools/benchmarks/benchmark_mesh_block_size.gd -- [--block-size=16] [--radius=64]
##
## Builds the same `VoxelTerrainBuilder` terrain every Phase C brick already exercises
## (default block set, placeholder flat-stone `VoxelGeneratorFlat`) with one `VoxelViewer`
## at the origin, and isolates exactly one variable: `VoxelTerrainBuilder.build()`'s
## `mesh_block_size` argument (052; only 16 and 32 are valid). Everything else — block set,
## generator, view distance — is held at the project's existing baseline so 052 (size 16)
## and 053 (size 32) numbers are comparable.
##
## Reports wall-clock time from scene-tree-attach to "settled" (`VoxelTerrainMetrics`'s
## `updated_blocks` counter unchanged for `_SETTLE_FRAMES` consecutive frames — this project
## has no other "meshing finished" signal for a whole view sphere, only `is_area_meshed()`
## for one known box), plus the final terrain/engine statistics snapshots. This is a
## measurement tool, not a pass/fail check, though it does exit non-zero on a build failure
## or timeout. The numbers a run actually prints are recorded in `nextsteps.md`
## (bricks 052/053), not duplicated here.
##
## This file itself must not statically reference `VoxelTerrainBuilder`/`BlockSet`/
## `VoxelTerrainMetrics` — see `mesh_block_size_benchmark_runner.gd`'s header comment for
## why (a `--script` entry file compiles before project autoloads are registered).


func _initialize() -> void:
	var mesh_block_size := 16
	# Matches VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE (042) — this file cannot reference
	# that constant directly (see the header comment), so the value is duplicated here.
	var radius := 128
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--block-size="):
			mesh_block_size = int(arg.get_slice("=", 1))
		elif arg.begins_with("--radius="):
			radius = int(arg.get_slice("=", 1))
	# Started, not awaited: the runner awaits process frames, same reasoning
	# tests/run_tests.gd already documents for its own `_run_all()`.
	_run(mesh_block_size, radius)


func _process(_delta: float) -> bool:
	return false  # _run() calls quit() when the measurement finishes


func _run(mesh_block_size: int, radius: int) -> void:
	var runner_script := load("res://tools/benchmarks/mesh_block_size_benchmark_runner.gd") as GDScript
	var runner: Object = runner_script.new()
	var exit_code: int = await runner.run(self, mesh_block_size, radius)
	quit(exit_code)
