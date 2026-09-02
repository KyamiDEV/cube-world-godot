extends SceneTree
## One-off content generator for the six baseline biome records (backlog brick 067).
##
## Usage:
##   godot --headless --script res://tools/generators/generate_biome_catalog.gd
##
## Writes one `BiomeDefinition` resource per `BiomeClassifier.IDS` entry to `data/biomes/`.
## Re-run to regenerate them from scratch after editing the table in the runner; it always
## overwrites, never merges. Deterministic: the same six files every time.
##
## Entry file only. It must not statically reference `BiomeClassifier`, `BiomeRegistry`,
## `BiomeCatalog` or `BiomeDefinition` — a `--script` entry compiles before project
## autoloads are registered, and every one of those either touches `Log` or pulls in
## something that does (`nextsteps.md`, brick 052). `generate_block_set.gd` gets away
## without the split only because `BlockDefinition` happens to touch nothing.
## `biome_catalog_generator.gd` does the work.


func _initialize() -> void:
	var runner_script := load("res://tools/generators/biome_catalog_generator.gd") as GDScript
	var runner: Object = runner_script.new()
	quit(runner.run())
