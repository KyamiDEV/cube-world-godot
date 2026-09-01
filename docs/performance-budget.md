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
| 1 | World generation | not yet measured | 257, 262 | — |
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

## 4. How to reproduce §3

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

## 5. Revisit / re-measure triggers

- **After Phase D** (real generation): re-run §3 against a real generator — the
  flat-stone placeholder is not representative. This also feeds brick 257
  (profile terrain generation) and 258 (profile meshing and streaming).
- **When an edit-throughput benchmark lands:** fill §3.4 with measured numbers and
  re-check ADR 0002.
- **When `DEFAULT_VIEW_DISTANCE` changes** (currently 128): the whole §3 table scales
  with the view volume.
- **On any Voxel Tools or engine build change:** treat every §3 number as stale until
  re-run; `tools\scripts\check.ps1` already refuses to continue on an engine mismatch.

## 6. Maintenance rule

- A subsystem row moves from "not yet measured" to a filled section **only** from a
  committed benchmark harness under `tools/benchmarks/`, with the workload written down
  the way §3.1 is.
- Budgets in this file are re-baselined, not silently widened, when the workload or
  toolchain changes. A widened budget with no workload change is a masked regression.
- Absolute numbers belong here; the reasoning behind a *decision* (e.g. the size-16
  choice) belongs in an ADR, and transient run logs belong nowhere — not here, not
  `nextsteps.md`.
