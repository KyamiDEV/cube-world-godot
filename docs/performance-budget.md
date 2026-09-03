# Performance budget

> The measured baseline for each subsystem, the threshold that counts as a regression,
> and how to re-measure. `CLAUDE.md` §8 sets the optimisation order this document is
> organised by; it also lists the workloads that must be benchmarked at least once.
>
> Every number here is a **machine-local fact** from the dev machine
> (`docs/environment.md` §2), not a portable guarantee. A figure is only meaningful
> next to the workload that produced it and the engine build it ran on.

## 1. Scope and status

| # | Subsystem (`CLAUDE.md` §8 order) | Status | Owning bricks | Section |
|--:|---|---|---|---|
| 1 | World generation | **baseline recorded** | 091b; 257, 262 | §4 |
| 2 | Voxel meshing | **baseline recorded** | 052, 053, 054, 055 | §3 |
| 3 | Streaming | partial (cold settle only, §3) | 258 | §3 |
| 4 | Entity simulation | not yet measured | 259 | — |
| 5 | AI | not yet measured | 260 | — |
| 6 | Network replication | not yet measured | 261 | — |
| 7 | Rendering | not yet measured | 266 | — |
| 8 | UI | not yet measured | 266 | — |

"Not yet measured" rows are placeholders so the document grows in `CLAUDE.md` §8 order
rather than being reorganised later. Only add a row's numbers from a committed benchmark
harness, the same way §3 was filled.

## 2. Measurement environment

| Field | Value |
|---|---|
| Engine | `4.7.2.stable.double.custom_build.ed1daf0bf` (`docs/environment.md` §2) |
| Voxel Tools | `1.7.0`, engine module (`docs/voxel-tools.md` §1) |
| Host | Windows 11 Pro 10.0.26200 (x86_64) — the single dev machine |
| Precision | `double` editor build |

All §3 figures are the **median of three repeated runs** on this host, headless. A
different machine will produce different absolute numbers; the *ratios* and the
*regression thresholds* are what transfer.

## 3. Voxel meshing baseline (bricks 052–055)

### 3.1 Synthetic workload

`tools/benchmarks/benchmark_mesh_block_size.gd` (+ `mesh_block_size_benchmark_runner.gd`)
builds one `VoxelTerrainBuilder.build()` terrain and measures wall-clock from
scene-tree attach to streaming-settle:

- **Block set:** `BlockSet.load_default()` — `block.grass` / `block.dirt` / `block.stone`.
- **Generator:** the placeholder flat-stone `VoxelGeneratorFlat` (real generation is
  Phase D and will replace it — these numbers do **not** describe generated terrain).
- **Viewer:** one `VoxelViewer` at the origin, `view_distance = 128`
  (`VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE`).
- **Settle detection:** `VoxelTerrainMetrics.engine_snapshot()` polled once per frame
  until `memory_pools.block_count` stops rising **and** every `tasks` queue reads `0`
  for 30 consecutive frames (see `docs/voxel-tools.md` §17 for why `updated_blocks` is
  not usable for this).

This is a **cold-start streaming** measurement with **no edits in the loop**. It exercises
meshing (subsystem 2) and the first-fill part of streaming (subsystem 3) only.

### 3.2 Measured baseline

`mesh_block_size = 16` is the project default (ADR 0002 / brick 054). Size 32 is recorded
alongside because `build()` still accepts it per terrain.

| Metric | **size 16 (default)** | size 32 | Source |
|---|---|---|---|
| Settle — polled frames | 52 | 50–51 | §17 / §18 |
| Settle — wall-clock (3 runs) | 375.7–377.9 ms | 341.4–352.6 ms | §17 / §18 |
| `memory_pools.block_count` | 324 | 324 | §17 / §18 |
| `memory_pools.voxel_used` | 2 654 208 B (~2.65 MB) | 2 654 208 B (~2.65 MB) | §18 |
| `dropped_block_loads` | 0 | 0 | §17 / §18 |
| `dropped_block_meshs` | 0 | 0 | §17 / §18 |
| `tasks` queues at settle | all 0 | all 0 | §17 / §18 |

(`§NN` refers to `docs/voxel-tools.md`.)

Data-block memory is **byte-identical** across the two sizes: `block_count` and
`voxel_used` count fixed 16³ *data* blocks, which `mesh_block_size` does not touch — it
only changes mesh-chunk granularity (ADR 0002 Context).

### 3.3 Budget — what counts as a regression

Provisional (one machine, synthetic workload). Re-baseline, do not just widen, when the
workload or engine build changes.

| Signal | Budget | Rationale |
|---|---|---|
| Cold synthetic settle wall-clock (size 16) | ≤ **450 ms** (~+20% over ~377 ms baseline) | absorbs run-to-run and machine variance; a real change lands well outside it |
| Cold synthetic settle frames (size 16) | ≤ **64** | baseline 52; one extra stability window of headroom |
| `dropped_block_loads` / `dropped_block_meshs` | **0** — any non-zero is a regression | the harness's view sphere fits the budget; dropped work means the pipeline fell behind on a workload it previously kept up with |
| `tasks` queues at settle | **all 0** | a non-draining queue means "settled" is false and the wall-clock number is not comparable |
| `memory_pools.block_count` / `voxel_used` for this workload | within a few % of 324 / ~2.65 MB | the workload is fixed; a material change means the data-block footprint moved |

### 3.4 Known unmeasured cost — per-edit re-mesh

The §3.2 benchmark never edits a block, so it does not bound the cost ADR 0002's decision
actually rests on:

- A single block edit forces a full re-mesh of the mesh chunk containing it, plus any
  bordering chunk. At `mesh_block_size = 16` that is a **16³ = 4 096-cell** mesh job per
  affected chunk (at size 32 it would be 32³ = 32 768, the 8× ratio ADR 0002 cites).
- With `generate_collisions = true` each affected mesh chunk also rebuilds its collision
  shape.
- This is on the **player-visible latency path** (mining / building) in an edit-heavy
  game.

No edit-throughput benchmark exists yet. ADR 0002 "Revisit if" names this as a gap; a
dedicated harness (measuring re-mesh latency per edit and under sustained edit rate)
would be needed before `mesh_block_size = 32` could be reconsidered as the default, and
before this row can move from "estimated" to "measured".

## 4. World generation baseline (brick 091b)

`WorldGenerator` (`world/generation/world_generator.gd`) is the first thing in the project
that writes a voxel, so this is the first row §1 could fill for subsystem 1. It measures
`fill_buffer()` **alone** — no terrain node, no viewer, no mesher, no streaming — so the
number stays attributable to generation rather than to the pipeline §3 measures.

### 4.1 Synthetic workload

| Field | Value |
|---|---|
| Harness | `tools/benchmarks/benchmark_world_generation.gd` (+ `world_generation_benchmark_runner.gd`) |
| World | `WorldSeed.from_text("cubeworld")`, generation version 1 |
| Content | shipped `BlockSet.load_default()` (5 blocks) and `BiomeCatalog.load_default()` (6 biomes) |
| Unit | one 16³ `VoxelBuffer` — Voxel Tools' data-block size, what `_generate_block()` is actually asked for |
| Sample | 9 consecutive chunks in a horizontal row per band, so every chunk stays in its band |

Three altitude bands, because they run different branches and cost very different amounts:
`sky` (entirely above the ground — only the per-column `top_y()` early-out runs), `ground`
(straddling the surface — the cover chain runs for every column), `deep` (entirely
underground — the 3D cave field is sampled once per voxel).

### 4.2 Measured baseline

Median of three runs, headless, on the §2 host:

| Band | ms / 16³ chunk | µs / voxel | Solid voxels in the last chunk |
|---|---:|---:|---:|
| `sky` | 87.8 | 21.4 | 0 / 4096 |
| `ground` | 722.4 | 176.4 | 2304 / 4096 |
| `deep` | 367.6 | 89.5 | 4096 / 4096 |

Run-to-run spread was under 3% on every band.

### 4.3 Where the time goes

The `sky` band does no voxel work at all — it is 256 `column_at()` calls and nothing else, so
**resolving a column costs ~0.34 ms**: the `Continentalness -> ElevationField -> ErosionPass ->
TerracePass -> RiverPass -> LakePass` chain plus `StructureGenerator.site_for_column()`'s
nine-region scan.

The `ground` band adds ~2.5 ms per column on top of that, and it is one call:
`SnowlineMaterial.block_id_at()`, whose `ShorelineMaterial` layer asks four *neighbouring*
columns whether they are wet (§23 of `docs/world-generation.md`) and runs a full height chain
for each. That single call is **~88% of a surface chunk**, and it is the clearly-indicated
first target for brick 262. The obvious shape of the fix — a chunk-scoped memo of the height
chain, shared between a column and its neighbours, owned by the fill loop rather than by any
pass — is deliberately *not* implemented at 091b: a cache on a pass object would be a data race
on Voxel Tools' worker threads (`docs/world-generation.md` §30.5), and a real one needs a
profile and a brick of its own.

The `deep` band's ~90 µs/voxel is `CaveMask`'s 4-octave 3D value noise, sampled per voxel with
no early-out available. Second target, and a much harder one: it is genuinely per-voxel work.

Two structural fixes already landed at 091b and are **inside** the numbers above, not pending:
the resolved-input forms (`SubsurfaceMaterial.block_id_for_depth()`,
`CaveCarving.is_hollow_for()`) that stopped the material passes re-deriving the surface height
once per voxel, and the removal of `SnowlineMaterial.block_id_at()`'s triple shoreline
evaluation. Together they took a 27-chunk sweep from 33.6 s to 9.4 s (3.6×) before this table
was recorded.

### 4.4 Budget — what counts as a regression

| Metric | Baseline | Regression threshold |
|---|---:|---|
| `ground` band, ms / chunk | 722 | > 20% slower with no generation-version bump |
| `deep` band, ms / chunk | 368 | > 20% slower with no generation-version bump |
| `sky` band, ms / chunk | 88 | > 20% slower with no generation-version bump |

The "with no generation-version bump" qualifier is the point: a new Phase D pass that makes
the world genuinely richer is *expected* to cost more and re-baselines this table. A slowdown
with no new content is a regression.

### 4.5 What this does not measure

- **Streaming or meshing the generated world.** §3's harness still runs against the flat
  placeholder; re-running it against `WorldGenerator` is brick 257/258's work, and §6's own
  trigger list already carries it.
- **Threading.** Voxel Tools calls `_generate_block()` on a worker pool, so wall-clock time to
  fill a view sphere is not this number times the chunk count. Measuring that needs a live
  terrain, which is §3's shape, not this one's.
- **Anything at a playable view distance.** `tests/integration/test_world_generation.gd` and
  `tools/debug/world_preview.gd` both run at a deliberately small view distance for exactly the
  reason this table records.

## 5. How to reproduce §3 and §4

Run the contracted engine headless against the harness, passing the block size as a
user arg after `--` (`OS.get_cmdline_user_args()`):

```text
<godot> --headless --script res://tools/benchmarks/benchmark_mesh_block_size.gd -- --block-size=16
<godot> --headless --script res://tools/benchmarks/benchmark_mesh_block_size.gd -- --block-size=32
```

`<godot>` is the build resolved by `tools\scripts\_common.ps1`
(`$env:GODOT_BIN` → `tools/local/godot_path.txt` → `docs/environment.md` §2).
`--radius=<n>` overrides the viewer `view_distance` (default 128).

Run each block size three times; take the median. The harness prints the final
`terrain_snapshot()` / `engine_snapshot()` dictionaries and the wall-clock, and exits
non-zero on a build failure or a settle timeout. It is a measurement tool, not a
pass/fail check — `tools\scripts\test.ps1` does not run it.

§4's harness is the same shape, with its own arguments:

```text
<godot> --headless --script res://tools/benchmarks/benchmark_world_generation.gd -- --chunks=9
<godot> --headless --script res://tools/benchmarks/benchmark_world_generation.gd -- --seed=lakes --altitude=ground
```

`--seed=<text>` picks the world (default `cubeworld`), `--chunks=<n>` the sample size per band
(default 27), `--altitude=sky|ground|deep` restricts the run to one band. Run three times and
take the median, exactly as §3 does. It needs no scene tree and exits as soon as it has
printed.

## 6. Revisit / re-measure triggers

- **Re-run §3 against `WorldGenerator`** now that Phase D generation exists (091b): the
  flat-stone placeholder §3 measured is not representative of meshing or streaming a real
  world. This feeds brick 257 (profile terrain generation) and 258 (profile meshing and
  streaming); §4 covers generation in isolation but says nothing about the pipeline.
- **On any generation-version bump:** every §4 number is stale, and re-baselining it is part
  of the bump (§4.4).
- **When an edit-throughput benchmark lands:** fill §3.4 with measured numbers and
  re-check ADR 0002.
- **When `DEFAULT_VIEW_DISTANCE` changes** (currently 128): the whole §3 table scales
  with the view volume.
- **On any Voxel Tools or engine build change:** treat every §3 number as stale until
  re-run; `tools\scripts\check.ps1` already refuses to continue on an engine mismatch.

## 7. Maintenance rule

- A subsystem row moves from "not yet measured" to a filled section **only** from a
  committed benchmark harness under `tools/benchmarks/`, with the workload written down
  the way §3.1 is.
- Budgets in this file are re-baselined, not silently widened, when the workload or
  toolchain changes. A widened budget with no workload change is a masked regression.
- Absolute numbers belong here; the reasoning behind a *decision* (e.g. the size-16
  choice) belongs in an ADR, and transient run logs belong nowhere — not here, not
  `nextsteps.md`.
