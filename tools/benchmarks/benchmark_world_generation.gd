extends SceneTree
## World generation benchmark harness (backlog brick 091b).
##
## Usage:
##   godot --headless --script res://tools/benchmarks/benchmark_world_generation.gd -- [--seed=cubeworld] [--chunks=27] [--altitude=ground]
##
## Measures `WorldGenerator.fill_buffer()` directly — no terrain node, no viewer, no meshing,
## no streaming. That isolation is the point: `benchmark_mesh_block_size.gd` (052/053) measures
## the meshing and streaming pipeline against a trivial flat generator, and this measures the
## generator against no pipeline at all, so the two numbers stay attributable.
## `docs/performance-budget.md` §4 records what it produced and how to re-run it.
##
## Three altitude bands are timed separately because they exercise different branches and cost
## very different amounts:
##
## ```text
## sky          entirely above the ground -- the per-column top_y() early-out, no voxel work
## ground       straddling the surface    -- the cover chain (SnowlineMaterial, 4 neighbours)
## deep         entirely underground      -- the cave field, sampled once per voxel
## ```
##
## This file itself must not statically reference `WorldGenerator`/`BlockSet`/`BiomeCatalog` —
## see `mesh_block_size_benchmark_runner.gd`'s header for why (a `--script` entry file compiles
## before project autoloads are registered).


func _initialize() -> void:
	var seed_text := "cubeworld"
	var chunks := 27
	var altitude := "all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_text = arg.get_slice("=", 1)
		elif arg.begins_with("--chunks="):
			chunks = int(arg.get_slice("=", 1))
		elif arg.begins_with("--altitude="):
			altitude = arg.get_slice("=", 1)
	var runner_script := load(
			"res://tools/benchmarks/world_generation_benchmark_runner.gd") as GDScript
	var runner: Object = runner_script.new()
	quit(runner.run(seed_text, chunks, altitude))


func _process(_delta: float) -> bool:
	return true  # _initialize() already quit; generation is synchronous, nothing to await
