# Region coordinate hashing

| Field | Value |
|---|---|
| Subsystem | `world` |
| Reference source | `server/world/World.cpp`, `cube/control/GameController.cpp`, `server/GAP_ANALYSIS.md` |
| Read on | `2026-09-01` |
| Overall confidence | `MEDIUM` (the load-bearing claims 1–3 and 5 are `HIGH`; claim 4 is `MEDIUM` and nothing depends on it) |
| Backlog bricks | `058` (written for), `061`, `089`–`090` |
| Godot contract | `world/generation/generation_grid.gd`, `world/generation/generation_hash.gd`, `docs/world-generation.md` §3 |

## 1. Scope

Answers one question for brick 058: **how did the original turn world coordinates into
generated content?** `matrix-world.md` §2 already indexed the evidence in one line
(`World_generateRegionSite` seeds by `regX,regZ`); this note reads the function itself,
because "how coordinates become a hash" is precisely what brick 058 implements.

It covers the coordinate→randomness step and the shape of the region grid it runs on.
It does **not** cover what a region site *contains*, the feature-cell placement rules
built on top of it, or any noise/height/climate field — those stay with bricks 089–090
and `matrix-world.md` §2, which already index them.

## 2. Sources examined

| Path | What was read | Read depth | Notes |
|---|---|---|---|
| `server/world/World.cpp` | `World_generateRegionSite`, lines 4993–5030 | `PARTIAL` | the bounds check, the seeding line, the cache index and the first two draws; the rest of the ~200-line body was not read |
| `cube/control/GameController.cpp` | the one line at `87676` | `PARTIAL` | the client's copy of the same seeding expression, located by grep |
| `server/GAP_ANALYSIS.md` | the `World_generateRegionSite`, `Region_getChunkCell`, `Chunk_getColumnAt`, `World_getTileAtCoords` rows | `GAP-ONLY` | one-line summaries; no bodies opened for the latter three |

## 3. Observed behavior

1. `HIGH` — **Region coordinates are unsigned and bounded to `0..1023`.** The function
   returns null for `regX < 0`, `regZ < 0`, `regX > 0x3ff` or `regZ > 0x3ff`. The world
   is a 1024 × 1024 grid of regions counted from a corner, not from an origin.
2. `HIGH` — **A region's content is seeded by a linear combination fed to the C library's
   global `srand()`**: `srand(regX + 0x108a + regZ * 0x400 + worldSeed * 3)`, followed by
   plain `rand()` draws. There is no mixing step: adjacent regions get adjacent seeds.
3. `HIGH` — **Both binaries compute it identically** (`server/world/World.cpp:5002` and
   `cube/control/GameController.cpp:87676`), which is the region-level instance of the
   finding in `world-generation-authority.md`: the client recomputes world content rather
   than receiving it.
4. `MEDIUM` — **A position becomes a region by two successive floor divisions, by 256 and
   then by 64** (the `>> 8` / `>> 6` pairs with their sign-correction masks), implying a
   256-unit intermediate tile with 64 of them per region edge, so a region spans 16 384
   position units. `MEDIUM` because the meaning of the float world-struct slot the
   division consumes is inferred from context, not proven.
5. `HIGH` — **The first decision drawn from that stream is `rand() & 1`** — a coin flip
   taken from the lowest bit of a linear congruential generator, the bit with the
   shortest period.
6. `HIGH` — **Generated sites are cached in a flat array indexed `regX * 0x400 + regZ`,
   while the seed pairs the axes the other way** (`regZ * 0x400 + regX`). Both are
   internally consistent; the axis order is simply not the same in the two expressions.

## 4. Inputs / outputs

| Direction | Data | Confidence |
|---|---|---|
| in | region coordinates `(regX, regZ)`, each `0..1023`; the world's single integer seed | `HIGH` |
| out | a 0x1c-byte site record, cached per region; null when the coordinates are out of range | `HIGH` |

## 5. State and transitions

The generator is a cache-fill: a region is either **ungenerated** (null slot) or
**generated** (site record). Generation is one-way and never re-run for a region.
Both sides own an independent copy of the same cache, populated by the same arithmetic —
so the state is not replicated, it is recomputed (claim 3).

## 6. Invariants

- `INV-1` — the same `(seed, regX, regZ)` always yields the same site — `HIGH`
- `INV-2` — a region outside the grid has no content at all, rather than clamped or
  wrapped content — `HIGH`
- `INV-3` — a region's content does not depend on which regions were generated before it
  — `LOW`. It holds only because each region reseeds the global `rand()` immediately
  before drawing; any code that draws from `rand()` between the `srand()` and the last
  draw would break it, and nothing in the design prevents that.

## 7. Uncertainties

| # | Unknown | How it could be resolved | Impact if wrong |
|---|---|---|---|
| U1 | The unit of the float world-struct slot at `0x8000f0`/`0x8000f4` that claim 4's divisions consume | reading the writers of that slot, or a live memory observation | Only the *interpretation* of claim 4's 256/64 decomposition; no design here depends on the original's absolute sizes |
| U2 | Whether anything else drew from `rand()` between the `srand()` and the site's last draw (`INV-3`) | reading the whole ~200-line body plus every callee | None for us — the project never uses a process-global stream (§9) |

## 8. Godot contract

Coordinates become values through `world/generation/generation_hash.gd`, bound to one
`WorldSeed`, over the coordinate spaces `world/generation/generation_grid.gd` defines.

| Concern | Decision |
|---|---|
| Authority | shared — both sides generate, only the server decides (`world-generation-authority.md`) |
| Determinism | required: pure function of `(seed, coordinates, salt, space)` |
| Persistence | generated — never saved, always recomputed (`docs/persistence.md` §5) |
| Replication | none: terrain does not travel |

## 9. Deliberate divergences

| Reference | Ours | Why |
|---|---|---|
| `srand()` + `rand()`, a process-global stream | `WorldHash` / `DeterministicRng`, a stream owned by the coordinate that asked | `docs/rng.md` §1. A global stream makes `INV-3` an accident: any unrelated draw between the seeding and the last use silently changes the world. It is also unusable from generation worker threads |
| linear seed: `regX + regZ * 0x400 + seed * 3 + 0x108a` | avalanche hash: per-axis odd multipliers, folded with a multiply between axes, finished with splitmix64 | A linear seed makes neighbouring regions produce neighbouring first draws, which an LCG barely decorrelates — visible as axis-aligned structure in placement. It also collides across worlds: `(regX + 3, seed - 1)` reproduces `(regX, seed)` exactly |
| the low bit of an LCG as a coin flip | the top 53 bits of an avalanched hash | claim 5. The low bits are the worst bits of an LCG |
| region grid `0..1023`, counted from a corner | region grid `-512..511` on both axes, centred on the origin | Our world is centred on the origin (`WorldBounds`, brick 050), and a player standing at spawn is not standing in a corner. The 1024 × 1024 *shape* is kept |
| region = 16 384 units, via a 256-unit tile | region = 1024 voxels, via the 16-voxel chunk Voxel Tools already streams in | claim 4's sizes belong to a world roughly 16× wider than ours. The intermediate grid is not ours to choose either: Voxel Tools hands a generator one 16-cube data block at a time |
| axis order differs between the cache index and the seed | one conversion, one order, `GenerationGrid` | claim 6. Two orders in one subsystem is a latent transposition bug |

## 10. Tests

| Behavior | Covered by |
|---|---|
| the same coordinates always hash the same, whatever was sampled between | `tests/unit/test_generation_hash.gd`, `tests/unit/test_world_hash.gd` |
| neighbouring and symmetric coordinates do not collide (the divergences above) | `tests/unit/test_world_hash.gd` |
| the region grid is signed, centred, and covers exactly `WorldBounds` | `tests/unit/test_generation_grid.gd` |
| a region outside the grid has no content (`INV-2`) | `tests/unit/test_generation_grid.gd` (`is_region_in_world()`); the *use* of that check lands with bricks 089–090 |

Nothing here needs a human playtest. Whether the resulting placement *looks* right is a
question for the bricks that place things (089–090), not for the hash.
