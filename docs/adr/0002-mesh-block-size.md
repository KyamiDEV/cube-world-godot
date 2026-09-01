# 0002 — Initial mesh block size

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-09-01 |
| Backlog bricks | 052–055 |
| Supersedes | — |

## Context

`VoxelTerrain.mesh_block_size` accepts only `16` or `32` (confirmed against upstream
`VoxelTerrain.xml`, `godot_voxel` tag `v1.7`: "Values other than 16 and 32 are not
supported"). It sets the edge length, in voxels, of one mesh chunk — the unit Voxel
Tools builds, uploads and re-builds as a single render/collision mesh. It does **not**
change data-block storage, which is fixed at 16³ regardless.

Bricks 039–051 ran under the engine's implicit default (`16`) without a recorded reason.
Bricks 052 and 053 measured both values against an identical synthetic workload
(`tools/benchmarks/benchmark_mesh_block_size.gd`: the default grass/dirt/stone block set,
the placeholder flat-stone `VoxelGeneratorFlat`, one `VoxelViewer` at
`view_distance = 128`, cold start to streaming-settle). This brick chooses the project
default from that data plus the parts of the trade-off the benchmark does not exercise.

### What the benchmark measured

| metric | size 16 (052) | size 32 (053) |
|---|---|---|
| settle frames | 52 | 50–51 |
| wall-clock (3 runs) | 375.7–377.9 ms | 341.4–352.6 ms |
| `memory_pools.block_count` | 324 | 324 |
| `memory_pools.voxel_used` | ~2.65 MB | ~2.65 MB |
| dropped loads / meshes | 0 / 0 | 0 / 0 |

Size 32 reached streaming-settle ~25–35 ms (~7–9%) faster and one to two frames sooner.
Data-block memory was byte-identical, as expected — `mesh_block_size` does not touch it.

### What the benchmark does not measure

1. **Per-edit re-mesh cost.** A single block edit forces a full re-mesh of the mesh
   chunk that contains it (and any neighbour chunk it borders). At size 16 that is one
   16³ = 4 096-cell mesh job; at size 32 it is one 32³ = 32 768-cell job — **8× the
   meshing work per edit**, on the latency path the player sees when mining or building.
   This project's reference game is edit-heavy (mining, terrain deformation, block
   placement); the 043–046 raycast/validate/apply pipeline exists specifically to make
   edits frequent and cheap.
2. **Partial-visibility waste.** A larger mesh chunk at the edge of the view volume or
   the camera frustum pulls in more geometry that is built but not seen, and makes
   distance/frustum culling coarser.
3. **Collision mesh granularity.** `generate_collisions = true` means every mesh chunk
   also carries a collision shape; a larger chunk is a larger shape to rebuild on edit.

The 7–9% the benchmark credits to size 32 is a **one-time** cold-start saving of ~30 ms.
The cost of size 32 is **per-edit and continuous** during normal play.

## Decision

**`VoxelTerrainBuilder.DEFAULT_MESH_BLOCK_SIZE` stays `16`.**

The constant value does not change (it has read `16` since brick 052), but as of this
brick `16` is a **deliberate, measured choice**, not an inherited engine default:

- The measured advantage of `32` is a single ~30 ms cold-start saving on a synthetic
  flat workload, with no edits in the loop.
- The unmeasured cost of `32` is 8× the meshing work on every block edit, on the
  player-visible latency path, in a game built around frequent edits.
- `16` is also Voxel Tools' own default and the value every brick from 039 onward was
  validated against, so keeping it introduces no revalidation risk.

`build()` keeps its optional `mesh_block_size` parameter and still accepts an explicit
`32` — a future static-terrain or heavy-view-distance context can opt in per terrain
without reopening this decision. Brick 055 writes the resulting numbers into the formal
voxel performance budget.

## Alternatives considered

| Alternative | Why not |
|---|---|
| `mesh_block_size = 32` as the project default | Benchmarked ~7–9% faster to cold-settle, but only on flat, un-edited terrain. Trades a one-time ~30 ms startup saving for 8× per-edit re-mesh cost in an edit-heavy game — the wrong side of the trade for this project. Remains available per-terrain via the `build()` parameter. |
| Defer the choice until real generation (Phase D) and real edits exist to benchmark | The default has to be *some* value now; every 039+ brick already depends on one. `16` is the low-risk choice and the decision names exactly the measurement that would reopen it. Re-benchmarking under real generation is expected, not blocked. |
| Make `mesh_block_size` a per-biome or per-region setting | `VoxelTerrain` has one `mesh_block_size` for the whole volume; the engine offers no per-region override. Not an available option in this stack. |

## Consequences

**Good**

- The player-visible edit latency path stays on the smaller, cheaper re-mesh unit.
- No revalidation of bricks 039–053, which all assume `16`.
- The faster-cold-start option is not lost — it is one `build()` argument away for a
  context that is measured to benefit.

**Costs and risks accepted**

- Cold-world streaming settle is ~7–9% slower than it could be on this synthetic
  workload. Accepted: it is a one-time cost and the benchmark is not representative of
  real generation.
- The decision rests on a *reasoned* estimate of edit re-mesh cost (the 8× cell-count
  ratio), not a measured one. A dedicated edit-throughput benchmark would confirm it;
  none exists yet.

## Revisit if

- A real-generation streaming benchmark (post Phase D) shows size 32 holding a
  materially larger advantage than the ~7–9% measured here, **and** an edit-throughput
  benchmark shows the per-edit re-mesh cost at size 32 staying inside the frame budget.
- View distance requirements grow enough that mesh-chunk draw-call count, not edit cost,
  becomes the dominant meshing concern — the same trigger ADR 0001 names for
  reconsidering `VoxelTerrain` versus `VoxelLodTerrain`.
- Voxel Tools changes the supported `mesh_block_size` set or the data-block size in a
  later version.
