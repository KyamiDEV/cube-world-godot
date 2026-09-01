# Terrain base height field

| Field | Value |
|---|---|
| Subsystem | `world` |
| Reference source | `server/world/World.cpp`, `server/GAP_ANALYSIS.md` |
| Read on | `2026-09-02` |
| Overall confidence | `MEDIUM` (the noise ladder and its amplitude modulation, claims 1–5, are `HIGH`; the region blend and the post-passes, claims 6–9, are `MEDIUM`/`LOW`) |
| Backlog bricks | `061` (written for), `062`–`063`, `080`, `089`–`090` |
| Godot contract | `world/generation/elevation_field.gd`, `docs/world-generation.md` §6 |

## 1. Scope

Answers one question for brick 061: **how did the original turn its noise into a ground
height?** `terrain-value-noise.md` covered the primitive (`valueNoise2D`) and left the
question of how it is stacked open as its uncertainty `U2`; this note reads
`World_baseHeightField`, the function that does the stacking, and closes `U2`.

It covers the noise ladder, the amplitude modulation, the region blend and the order the
post-passes are applied in. It does **not** cover the bodies of `World_riverClimateGate`,
`World_roadField`, `World_waterDepthField`, `World_objectFalloffWeight` or
`World_findNearestEntityInRegion` — each is named where it is called and rated `LOW`,
because 061 uses none of them (they belong to bricks 062, 080–083 and 089–090).

## 2. Sources examined

| Path | What was read | Read depth | Notes |
|---|---|---|---|
| `server/world/World.cpp` | `World_baseHeightField`, lines 4496–4900 | `FULL` for the height composition; `PARTIAL` past the region-entity branch at 4855 | the decompiler's `[AUDIT]` header rates the whole function `low` confidence, so every claim below is stated against the code, not the header |
| `server/world/World.cpp` | `valueNoise2D`, lines 3495–3536 | already read | see `terrain-value-noise.md` |
| `server/GAP_ANALYSIS.md` | the `World_baseHeightField` row | `GAP-ONLY` | "Multi-octave terrain/biome generator: sums value-noise layers, computes climate/height and blends region data" |

## 3. Observed behavior

1. `HIGH` — **The ladder is three tiers of relief, not an fBm.** Height is a sum of five
   `valueNoise2D` terms at three frequencies, with the amplitude written at each call
   site rather than by a shared octave loop:

   | Frequency | Terms | Amplitude each |
   |---|---|---|
   | `0.0002` | 2 | `(n + 1) · 100` — so `0 .. 200` |
   | `0.002` | 2 | `(n + 1) · 50` — so `0 .. 100` |
   | `0.01` | 1 | `(n + 1) · 20` — so `0 .. 40` |

   Frequency ratios are `10 : 5`, not `2 : 2`; amplitude ratios are roughly `1 : 0.5 :
   0.2`. This closes `terrain-value-noise.md` `U2`: the original is **decade-spaced with
   roughly halving amplitude**, not a doubling ladder.

2. `HIGH` — **Every relief term is positive-only.** All five are `(noise + 1) · k` with
   the noise in `(−1, 1]`, so each contributes `[0, 2k)`. Relief is added **upward** from
   a base; nothing in the sum can dig below it.

3. `HIGH` — **Each tier's amplitude is modulated by a separate, coarser noise field, and
   that field is squared.** Five weight samples are taken first — two at `0.0001`, two at
   `0.001`, one at `0.002` — each remapped to `[0, 1]` as `(n + 1) · 0.5` and then
   multiplied by itself. The `0.0001` pair weights the `0.0002` relief terms, the `0.001`
   pair weights the `0.002` terms, and the `0.002` weight weights the `0.01` term. Every
   tier of detail is therefore *placed* by a field one decade coarser than itself: a
   region is mountainous or flat before it is detailed.

   The squaring is a redistribution curve. `w²` for `w` uniform on `[0, 1]` has mean
   `1/3`, so most of the world gets a fraction of the stated amplitude and a minority gets
   most of it — flat is the default and mountains are the exception.

4. `HIGH` — **The base the relief stands on comes from region data, not from noise.** The
   function scans the region grid within `±0x4000` units of the column, finds the nearest
   region site, then inverse-distance-weights the *heights* of every region in that window
   with `w = (1 − clamp(d² − d²_nearest, 0, 1))²`, giving `Σ(height · w) / Σw`. A second
   accumulator over the same weights, `Σ(w where height > 0) / Σw`, is the fraction of the
   neighbourhood that is land — and it multiplies the whole `0.0002` relief tier before
   the base is added.

5. `HIGH` — **Region site positions are jittered by noise.** The window corners are taken
   from the column, but the site lookup is offset by
   `valueNoise2D(z · 0.0005, 3423) · 3 · 256` and
   `valueNoise2D(x · 0.0005, 23421) · 3 · 256` — about `±768` units — so the region
   lattice never shows as a straight edge in the terrain.

6. `MEDIUM` — **Four post-passes scale the relief tiers down, never up.** In order: a
   river/climate gate (`min(gate · 4, 1)`, put through a cubic smoothstep and squared)
   multiplies the two finer tiers; a road field above `0.5` flattens the finest tier; a
   water-depth field scales all three by `0.9 .. 1.0` and the finest by `0.5 .. 1.0`; and
   an object-falloff weight near a structure multiplies all three by `1 − (1 − w)² · 0.5`.
   Every one of them is a *flattening* term. `MEDIUM` because none of the four helper
   bodies was read.

7. `MEDIUM` — **Climate and height share the same ladder.** The `GAP_ANALYSIS` row calls
   this a "terrain/biome generator", and the two `0.0001` weight fields are read before
   anything height-specific happens, which is consistent with the same samples feeding the
   temperature/humidity blends. Not confirmed: this note did not trace the weights past
   their use in the height sum.

8. `LOW` — **A per-region entity can lower the terrain around itself.** Past line 4855 the
   function looks up the nearest entity in the region, and if its field at `+0x18` is
   negative, subtracts a smoothstepped radial falloff from the height. Read for shape
   only; the entity layout was not traced.

9. `LOW` — **Units are not recoverable from this function.** Heights are added as bare
   floats, and the region grid stride (`0x4000` = 16384) is the only length constant with
   a known meaning (`region-coordinate-hashing.md`, claim 1). Amplitude *ratios* transfer;
   absolute amplitudes do not.

## 4. Inputs / outputs

| Direction | Data | Confidence |
|---|---|---|
| in | a world column `(x, z)`, plus a fourth argument only some call sites pass | `HIGH` |
| in | the world's noise seed offsets, at `this + 0x80018c .. 0x8001d8` — fourteen of them, two per `valueNoise2D` call | `HIGH` |
| in | the region array on `this`, and the entity list per region | `MEDIUM` |
| out | one float height | `HIGH` |

## 5. State and transitions

None of its own: it reads world state and returns a number. It is not pure in our sense —
the region array it blends is world state that other systems write — which is the
structural difference from `valueNoise2D` and the reason our own field cannot copy claim 4
directly (§7).

## 6. Invariants

- `INV-1` — relief never lowers the ground below its base (claim 2) — `HIGH`
- `INV-2` — every post-pass scales relief toward the base, never away from it (claim 6) —
  `MEDIUM`
- `INV-3` — a column's height depends on its region neighbourhood, not only on its own
  coordinates (claim 4) — `HIGH`

## 7. Uncertainties

| # | Unknown | How it could be resolved | Impact if wrong |
|---|---|---|---|
| U1 | Where region heights come from (claim 4) — the values blended are already in the region array when this runs | reading the region-generation writer | None for 061, which uses a noise field instead of region data. It matters for bricks 089–090, which own the region grid |
| U2 | Whether the two `0.0001` weight fields also drive temperature/humidity (claim 7) | reading `World_temperatureBlend` / `World_humidityBlend` | None for 061. Bricks 064–065 should resolve it before deciding whether climate shares elevation's fields or gets its own |
| U3 | The absolute vertical scale (claim 9) | mapping the original's unit to a metre | None: our vertical anchors are chosen against `WorldBounds` and `WorldScale`, not imported |

## 8. Deliberate divergences

| Reference | Ours | Why |
|---|---|---|
| decade-spaced frequencies with per-call amplitudes (claim 1) | one `ValueNoise` layer, `cell_size = 1024`, 6 octaves, `gain = 0.5` | Powers of two are a determinism requirement for us, not a taste: `terrain-value-noise.md` §9 — an exact lattice and an exact interpolation weight. A call-site ladder also cannot state its own range or its own slope bound, and the range is what `GenerationFixtures.range_reason()` checks and the bound is what makes "coherent" a claim rather than a hope |
| the base is blended from region-array heights (claim 4) | the base is `lerp(OCEAN_FLOOR, LAND_BASE, shore_weight(continentalness))` | Their base is world *state*; ours has to be a pure function of `(seed, column)` (`docs/rng.md` §2), because our server and client both generate. A noise-derived base also needs no region pass to exist first, which is what lets 061 land before 089 |
| land/ocean comes from the fraction of nearby regions with positive height (claim 4) | `Continentalness` (060), a field | Same reason. Theirs is quantised to a 16384-unit lattice and smoothed by the blend; ours is coherent at every scale by construction |
| each relief tier modulated by its own squared weight field (claim 3) | one amplitude, blended by the shore weight only | Scope: a per-place ruggedness field is a *shaping* decision, and brick 062 owns shaping. Recorded here as the mechanism 062 should reach for first — including the squaring, which is the part that makes flat the default |
| relief is additive-upward (claim 2) | **kept** | The one shape decision this note changed in our implementation. It makes the base a genuine floor, so an ocean floor cannot be turned into a mountain by a noise sample, and it gives `MINIMUM_VOXELS` an exact value instead of a bound |
| four flattening post-passes (claim 6) | none yet | Rivers, roads, water depth and structure flattening are bricks 062, 080–083 and 089–090. The *shape* of the finding — that they all multiply relief toward the base and never add to it — is the part worth keeping when those bricks arrive |

## 9. Tests

| Behavior | Covered by |
|---|---|
| relief never digs below the base (`INV-1`, the kept decision) | `tests/unit/test_elevation_field.gd::test_relief_never_digs_below_the_base` |
| the height stays inside a stated closed range, and the range has headroom inside `WorldBounds` | `tests/unit/test_elevation_field.gd` (through `GenerationFixtures.range_reason()`, plus the headroom assertion) |
| the field is a pure function of `(seed, column)` — the divergence from claim 4 | `tests/unit/test_elevation_field.gd` (through `GenerationFixtures.determinism_reason()` / `seed_sensitivity_reason()`) |
| a coarser field places the finer detail (the surviving half of claim 3) | `tests/unit/test_elevation_field.gd::test_the_deep_ocean_is_calmer_than_the_interior` |
| the ground is walkable — a bounded step per voxel, asserted against a derived bound | `tests/unit/test_elevation_field.gd::test_a_kilometre_of_walking_is_walkable`, with `test_the_step_bound_is_a_real_constraint` proving the check can fail |

Nothing here needs a human playtest yet. Whether the resulting landscape *reads* as Cube
World is a question for the first brick that puts a player on it; the first
`HUMAN_REQUIRED` brick is 091.
