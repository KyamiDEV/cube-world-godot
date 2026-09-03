# CubeWorld-Godot

A clean-room **behavioural reimplementation** inspired by Cube World Alpha (2013): a
blocky voxel world with a server-authoritative simulation, built in Godot.

This repository contains newly authored code, data and assets. It ships no original
game binaries, assets, data files, names or trademarks, and is not affiliated with
Picroma or Wollay. See [§ IP discipline](#ip-discipline).

> **Status: the world generates.** Bricks 001–067, 074–091 and 091b of 266 are
> done (86 bricks; 068–073 folded into later ones rather than left owning nothing) —
> verified toolchain, project skeleton, test harness, the core contracts (scale, time,
> RNG, IDs, saves, protocol, authority), the reverse-engineering reference mapping
> (Phase B), a complete voxel edit pipeline (Phase C: block schema/registry, a generated
> block set, a `VoxelBlockyLibrary` builder, a baseline `VoxelTerrain` +
> `VoxelMesherBlocky` + `VoxelViewer`, raycast place/remove with layered structural +
> gameplay validation, undo/delta representation, SQLite-backed save/load proven by an
> integration test, world bounds/authority policy, chunk profiling hooks, the
> `mesh_block_size` 16-vs-32 benchmarks and a baseline voxel performance budget
> ([`docs/performance-budget.md`](docs/performance-budget.md))), a complete pass of
> procedural generation (Phase D: world seed, generation versioning, coordinate
> hashing and grids, shared determinism fixtures, a value-noise primitive, the
> continentalness → elevation → erosion → terrace chain, two independent climate axes, a
> six-biome classifier over them, the biome catalog behind those ids, biome-edge blending,
> per-biome surface/subsurface material selection, a 3D cave mask with carving and
> underground material rules, a water-level model with rivers/lakes/oceans carved into it,
> shoreline and altitude-driven snowline surface rules, density-driven tree and rock spawn
> masks, and deterministic structure seeding, placement and an initial walled-plinth
> generator, [`docs/world-generation.md`](docs/world-generation.md)) — and, as of brick
> 091b, all of it **assembled into a real `VoxelGenerator`**: the world is written into
> `VoxelBuffer`s, streamed by a live `VoxelTerrain`, and walkable-through in a free-fly
> debug preview (`tools\scripts\godot.ps1 res://tools/debug/world_preview.tscn`). There is
> still no player, camera or gameplay — that is Phase F. Progress is tracked in
> [`backlog.md`](backlog.md) and [`nextsteps.md`](nextsteps.md).

## Technical baseline

| Item | Value |
|---|---|
| Engine | `Godot 4.7.2.stable.custom_build [ed1daf0bf]`, double-precision editor build |
| Voxel stack | Voxel Tools `1.7.0`, compiled in as an engine **module** |
| Renderer / physics | Forward+ / Jolt, 60 Hz |
| Scale | `1 voxel = 0.5 m`, `1 m = 2 world units`, Y-up |
| Authority | Server authoritative; clients send intent only |
| Generation | Deterministic from `(seed, world coordinates, generation version)` |

Both the engine build and the Voxel Tools module are **pinned and verified**: a
mismatched binary is a hard stop, never a silent fallback. See
[`docs/environment.md`](docs/environment.md) and
[`docs/voxel-tools.md`](docs/voxel-tools.md).

## Getting started

The engine binary lives outside the repository — only its fingerprint is committed. Point
the tooling at your copy of the contracted build:

```powershell
# $env:GODOT_BIN, or:
"C:\path\to\godot.windows.editor.double.x86_64.exe" | Set-Content tools\local\godot_path.txt
```

Then:

```powershell
tools\scripts\check.ps1      # engine build + Voxel Tools + full GDScript compile + headless boot
tools\scripts\test.ps1       # headless test suite
tools\scripts\run.ps1        # run the game
tools\scripts\godot.ps1 -e   # open the editor
```

`check.ps1` is the pre-commit gate. `test.ps1` takes `-File`, `-Filter`, `-Verbose_` and
`-NoImport`.

Current state: **60 test files, 889 tests, ~127 735 assertions, 0 failures.**

## What is implemented

| Area | Files | Provides |
|---|---|---|
| Logging | `autoload/log.gd` | levels, channels, `check()` vs `invariant()`, test capture |
| Scale | `core/math/world_scale.gd` | metres ↔ world units ↔ voxel coordinates; the only place `0.5`/`2.0` may appear |
| Time | `core/time/simulation_clock.gd` | 60 Hz fixed step, catch-up clamping, snapshot cadence |
| Randomness | `core/random/deterministic_rng.gd`, `world_hash.gd` | splitmix64 stream + positional hashing for order-independent generation |
| Identity | `core/ids/stable_id.gd`, `definition_registry.gd` | ID grammar, content catalogues, aliases, network indices |
| Saves | `core/serialization/save_version.gd` | four independent version numbers, load verdicts, migration steps |
| Protocol | `network/protocol/`, `network/packets/edit_block_command.gd` | message kinds, direction rules, handshake compatibility, PLACE/REMOVE edit intent |
| Authority | `network/authority/command_gate.gd` | ownership, tick window, replay and rate-limit checks |
| Blocks | `world/terrain/block_definition.gd`, `block_registry.gd` | block-kind schema (textures, collision, destructibility, hardness, drops, footstep tag) and its validated, network-indexed catalogue |
| Blocks | `world/terrain/blocky_library_builder.gd`, `block_set.gd`, `data/blocks/*.tres` | builds a real `VoxelBlockyLibrary` from the registry; first committed content — `block.grass`/`block.dirt`/`block.stone` |
| Terrain | `world/terrain/voxel_terrain_builder.gd`, `voxel_viewer_builder.gd` | baseline `VoxelTerrain` (collision, placeholder flat-ground generator, `VoxelMesherBlocky`, configurable `mesh_block_size`, world bounds) plus a `VoxelViewer` for streaming interest |
| Editing | `world/terrain/block_raycast_service.gd`, `block_edit_validator.gd`, `block_edit_applicator.gd`, `block_edit_delta.gd` | raycast → structural + gameplay validation → apply → undoable delta, the full server-authoritative edit pipeline |
| Persistence | `world/persistence/voxel_stream_builder.gd`, `world/terrain/world_bounds.gd` | `VoxelStreamSQLite` deltas-only save/load, proven end-to-end by an integration test; authoritative world extent |
| Generation | `world/generation/world_seed.gd`, `generation_version.gd`, `generation_hash.gd`, `generation_grid.gd` | world identity as `(value, text, generation version)` with a client/server parity check; the version lifecycle and its self-check; positional hashing bound to one world; the five coordinate spaces generation asks questions at, with floor-correct conversions |
| Generation | `world/generation/value_noise.gd` | the coherent-noise primitive every field stands on — an integer voxel lattice, a quintic fade (never `cos`: libm is not bit-reproducible and both sides generate), octaves separated by a lattice offset, and a slope bound derived before any sample is taken |
| Generation | `world/generation/continentalness.gd`, `elevation_field.gd`, `erosion_pass.gd`, `terrace_pass.gd` | the world-shape chain: a land/ocean macro field → signed ground height on a datum → a ruggedness/valley erosion pass that only ever lowers → 4 m terracing that makes it a block world |
| Generation | `world/generation/temperature_field.gd`, `humidity_field.gd` | two independent climate axes on the coarsest cells in the world, each a redistributed noise layer reading no elevation — no lapse rate and no rain shadow, which are a later brick's, on top, where they can be seen |
| Biomes | `world/biomes/biome_classifier.gd` | which of six biomes a column is in: a six-rule decision list over temperature, humidity and ruggedness, total by construction, with three thresholds taken from the reference's own literals and one derived from the erosion pass |
| Biomes | `world/biomes/biome_definition.gd`, `biome_registry.gd`, `biome_catalog.gd`, `data/biomes/*.tres` | the records behind those ids — a validated, network-indexed catalogue that is checked for covering *exactly* the closed set the classifier can answer with, because a biome with no record is a world with columns that resolve to nothing. Fields grew one brick at a time: `surface_block_id` (075), `subsurface_block_id` (076), `vegetation_density` (087) |
| Biomes | `world/biomes/biome_transition.gd` | how close a column sits to a biome edge and which neighbour it is nearing, found by nudging the classifier's own thresholds rather than re-deriving its decision-list precedence |
| Generation | `world/generation/surface_material.gd`, `subsurface_material.gd` | per-biome ground/subsoil block selection, blended across biome edges by `BiomeTransition`'s own weight |
| Generation | `world/generation/cave_mask.gd`, `cave_carving.gd`, `underground_material.gd` | a 3D value-noise cavity mask, which of those cavities are actually carved, and the material rules for the surfaces that carving exposes |
| Generation | `world/generation/water_level.gd`, `river_pass.gd`, `lake_pass.gd`, `ocean_pass.gd` | a sea-level model, then rivers, lakes and large open oceans carved into the terrain on top of it |
| Generation | `world/generation/shoreline_material.gd`, `snowline_material.gd` | beach-edge block rules where land meets `WaterLevel`, and altitude-driven snow cover derived from a lapse rate over `TerracePass` |
| Generation | `world/generation/decoration_mask.gd`, `tree_mask.gd` | an order-free eligibility + one-anchor-per-cell mechanism for natural decoration, and its first real content — biome-density tree spawn masks that exclude wet, shoreline and snow-capped ground |
| Tests | `tests/fixtures/generation_fixtures.gd` | the shared determinism floor every generation pass is tested against: pinned named worlds, coordinate samples chosen for negative axes/cell boundaries/world corners, repeatability + order-independence + seed-sensitivity + range + variation checks, and golden signatures |
| Profiling | `world/terrain/voxel_terrain_metrics.gd`, `tools/benchmarks/` | typed access to Voxel Tools' own debug counters; a `mesh_block_size` (16 vs 32) benchmark harness |
| Tooling | `tools/` | engine verification, whole-tree compile check, test runner, content generators, benchmarks |

## Design decisions worth knowing

A few choices that shape everything else — the reasoning is in the linked documents.

- **Server authority from the first system, not retrofitted.** Adding it later means
  rewriting combat, inventory, quests and world edits.
  → [`docs/server-authority.md`](docs/server-authority.md)
- **Randomness is written out, not taken from the engine.** `RandomNumberGenerator` is an
  implementation detail that may change; a world that regenerates differently after an
  engine upgrade is a silently corrupted world. → [`docs/rng.md`](docs/rng.md)
- **Generation is positional, not sequential.** A chunk's content must not depend on how
  many chunks were generated before it, or a player arriving from the north would see a
  different world than one arriving from the south.
- **Generation constants are pinned, not tuned.** Cell sizes, amplitudes and curves are
  part of every world ever made with them, so changing one is a *generation version bump*,
  not a knob. Every pass pins a golden signature over a shared fixture set, so the bump has
  to be made deliberately instead of noticed by a player whose world moved.
  → [`docs/world-generation.md`](docs/world-generation.md)
- **Four version numbers, not one.** Otherwise adding a block invalidates every save,
  and a generator change is indistinguishable from it.
  → [`docs/persistence.md`](docs/persistence.md)
- **Fixed 60 Hz simulation; frame delta never reaches gameplay code.**
  → [`docs/simulation-time.md`](docs/simulation-time.md)
- **Layering is enforced by a test**, not by convention alone.
  → [`docs/architecture.md`](docs/architecture.md)
- **Plain `VoxelBlockyLibrary`, not the attribute-driven `VoxelBlockyType` system.** The
  block schema has no rotation/connected-state axis yet, so the simpler model is the
  correct minimal fit — revisit only if a block kind genuinely needs per-voxel state.
  → [`docs/voxel-tools.md`](docs/voxel-tools.md)

## Repository layout

```
autoload/   global services (Log)
core/       math, serialization, RNG, time, IDs — no gameplay knowledge
world/      terrain, generation, biomes, structures, streaming, persistence
gameplay/   entities, combat, stats, inventory, skills, quests
ai/         behavior, navigation, perception
network/    protocol, packets, replication, authority
client/     presentation, camera, UI, effects, boot scene
server/     dedicated server entry points and simulation
assets/ data/ tests/ tools/ docs/
```

Each top-level directory has a README stating what it owns.
[`docs/architecture.md`](docs/architecture.md) defines which layer may depend on which,
and `tests/unit/test_layering.gd` fails the build when a file breaks it.

## Documentation

| Document | Covers |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | the development contract this project is built under |
| [`backlog.md`](backlog.md) | 266 auditable implementation bricks with dependencies |
| [`nextsteps.md`](nextsteps.md) | compact session handoff state |
| [`docs/architecture.md`](docs/architecture.md) | the four kinds of code and the dependency table |
| [`docs/conventions.md`](docs/conventions.md) | naming, files, classes, stable IDs |
| [`docs/simulation-time.md`](docs/simulation-time.md) | fixed-step tick contract |
| [`docs/rng.md`](docs/rng.md) | deterministic randomness |
| [`docs/ids-and-registries.md`](docs/ids-and-registries.md) | content identity and catalogues |
| [`docs/persistence.md`](docs/persistence.md) | save format versioning and migrations |
| [`docs/world-generation.md`](docs/world-generation.md) | seeds, generation versioning, coordinate spaces, and every generation pass |
| [`docs/protocol.md`](docs/protocol.md) | network message taxonomy |
| [`docs/server-authority.md`](docs/server-authority.md) | authority invariants |
| [`docs/logging-and-errors.md`](docs/logging-and-errors.md) | logging and error conventions |
| [`docs/environment.md`](docs/environment.md), [`docs/voxel-tools.md`](docs/voxel-tools.md) | verified toolchain |
| [`docs/performance-budget.md`](docs/performance-budget.md) | measured baselines, regression thresholds, re-measure triggers |
| [`docs/adr/`](docs/adr/) | architecture decision records |
| [`docs/reference/`](docs/reference/) | reverse-engineering notes, with confidence levels |

## Development workflow

One backlog brick at a time:

1. Read `CLAUDE.md`, then `nextsteps.md`.
2. Take the next unblocked brick.
3. Implement only that brick.
4. `tools\scripts\check.ps1` and `tools\scripts\test.ps1`.
5. Update `nextsteps.md`, review the diff, commit.

A brick is done only when the implementation exists, targeted tests pass, docs are
updated, and any visual verification is explicitly marked as needing a human playtest.

## IP discipline

The reverse-engineering reference ([qad3n/CubeWorld-Reversal](https://github.com/qad3n/CubeWorld-Reversal))
is used as a source of **behavioural hypotheses only**. It is cloned locally, is not
committed here, and nothing is ported line by line.

- Behaviour is extracted and written up in our own words, with an explicit confidence
  level; decompiled bodies, struct layouts, constant tables and asset data never enter
  this repository.
- Implementations are idiomatic Godot written against a documented contract.
- Assets and data are newly authored.

Cube World and its original code, assets, names and trademarks belong to Picroma and
Wolfram von Funck (Wollay). This project is unaffiliated fan work.

## Licence

Not yet chosen. Until a `LICENSE` file is added, no permissions are granted beyond
viewing the source.
