extends RefCounted
## The actual measurement logic for `benchmark_world_generation.gd` (brick 091b).
##
## Split out of the `--script` entry file for the reason
## `mesh_block_size_benchmark_runner.gd` documents at length: a file passed directly to
## `--script` compiles before project autoloads exist, and every class this file names
## (`WorldGenerator`, `BlockSet`, `BiomeCatalog`, `WorldSeed`) reaches `Log` internally.
##
## Synchronous from start to finish. `fill_buffer()` is a pure function of the world and a
## `VoxelBuffer`; nothing here needs a scene tree, a frame or a worker thread, which is exactly
## what makes the number attributable to generation rather than to streaming.

## Edge length of the buffers timed, in voxels — Voxel Tools' data-block size and the unit the
## engine actually asks `_generate_block()` for (`GenerationGrid.CHUNK_SIZE_VOXELS`).
const _CHUNK_SIZE := 16

## Half a chunk, written out rather than divided: `project.godot [debug]` treats integer
## division as an error.
const _HALF_CHUNK := 8

## How far above / below the sampled column's own ground the `sky` and `deep` bands sit.
const _SKY_OFFSET_VOXELS := 256
const _DEEP_OFFSET_VOXELS := 128


## Returns the process exit code (0 = measured, 1 = the world could not be built).
func run(seed_text: String, chunks: int, altitude: String) -> int:
	var world_seed := WorldSeed.from_text(seed_text)
	var generator := WorldGenerator.for_seed(world_seed, BiomeCatalog.load_default(),
			BlockSet.load_default())
	if generator == null:
		printerr("WorldGenerator.for_seed() refused the seed or the shipped catalogs")
		return 1

	var ground_y := generator.column_at(Vector2i(0, 0)).ground_y
	print("=== world generation benchmark ===")
	print("seed=", world_seed.display_text())
	print("generation_version=", generator.generation_version())
	print("chunks=", chunks, " chunk_size=", _CHUNK_SIZE, " ground_y=", ground_y)

	var bands := {
		"sky": ground_y + _SKY_OFFSET_VOXELS,
		"ground": ground_y - _HALF_CHUNK,
		"deep": ground_y - _DEEP_OFFSET_VOXELS,
	}
	for band in bands:
		if altitude != "all" and altitude != band:
			continue
		_measure(generator, band, int(bands[band]), chunks)
	return 0


## Times `chunks` consecutive chunk fills in a horizontal row at `base_y`, and prints the total,
## the per-chunk mean and the per-voxel mean. A row rather than a cube so every chunk in a band
## stays in that band.
func _measure(generator: WorldGenerator, band: String, base_y: int, chunks: int) -> void:
	var buffer := VoxelBuffer.new()
	buffer.create(_CHUNK_SIZE, _CHUNK_SIZE, _CHUNK_SIZE)
	var solid := 0

	var started := Time.get_ticks_usec()
	for index in chunks:
		generator.fill_buffer(buffer, Vector3i(index * _CHUNK_SIZE, base_y, 0))
	var elapsed := Time.get_ticks_usec() - started

	# Counted after the timed loop so the histogram never lands inside the measurement — it is
	# reported because "how solid was the band" is what tells a reader whether the number
	# describes the branch they think it does.
	for z in _CHUNK_SIZE:
		for y in _CHUNK_SIZE:
			for x in _CHUNK_SIZE:
				if buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE) != 0:
					solid += 1

	var voxels := chunks * _CHUNK_SIZE * _CHUNK_SIZE * _CHUNK_SIZE
	print("%-7s base_y=%-6d total=%8.1f ms  per_chunk=%7.1f ms  per_voxel=%6.1f us  last_chunk_solid=%d/%d" % [
			band, base_y, elapsed / 1000.0, elapsed / 1000.0 / float(chunks),
			float(elapsed) / float(voxels), solid, _CHUNK_SIZE * _CHUNK_SIZE * _CHUNK_SIZE])
