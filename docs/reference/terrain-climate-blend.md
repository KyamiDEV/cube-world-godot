# Terrain climate blend

| Field | Value |
|---|---|
| Subsystem | `world` |
| Reference source | `server/world/World.cpp`, `server/world/World.h`, `server/GAP_ANALYSIS.md` |
| Read on | `2026-09-02` |
| Overall confidence | `MEDIUM` (claims 1, 2, 5 and 7 are `HIGH`; claim 3's "in practice a Voronoi field" is `MEDIUM` and is load-bearing for §8's second divergence) |
| Backlog bricks | `064` (written for), `065`, `066`–`067`, `074`, `085`, `089`–`090` |
| Godot contract | `world/generation/temperature_field.gd`, `docs/world-generation.md` §9 |

## 1. Scope

Answers one question for brick 064: **where did the original's climate come from, and did
it come from the height field?** `terrain-base-height-field.md` left that open as its `U2`
— its `MEDIUM` claim 7 guessed that the two `0.0001` weight fields feeding the relief
ladder also fed temperature and humidity. This note reads the two functions that actually
produce climate and settles it. The answer is **no**, and claim 7 is contradicted rather
than merely unconfirmed.

It covers the blend both climate axes use, the window and weights it runs over, the scale
the result is read on, and the one post-pass temperature carries. It does **not** cover
where the per-region climate values come from (that is `terrain-base-height-field.md`
`U1`'s question about the region writer, unchanged and still `LOW`), nor the body of
`World_objectFalloffWeight`, nor anything about biome classification — those belong to
bricks 066–067 and 089–090.

## 2. Sources examined

| Path | What was read | Read depth | Notes |
|---|---|---|---|
| `server/world/World.cpp` | `World_temperatureBlend`, lines 4167–4365 | `FULL` | the decompiler rates it `high`; the return value is lost (both functions are typed `void` and return in `st0`), so the *shape* of the accumulator is read from the code and the *use* from the call site |
| `server/world/World.cpp` | `World_humidityBlend`, lines 4376–4491 | `FULL` | structurally identical; its value accumulator did not survive decompilation — see `U1` |
| `server/world/World.cpp` | the call site in `World_generateRegionSite`, lines 5630–5638 | `PARTIAL` | read for the thresholds only |
| `server/world/World.h` | the two declarations, lines 39–40 | `FULL` | `float`/`uint` vs `int`/`int` parameter typing differs between them; both are a column |
| `server/GAP_ANALYSIS.md` | the two rows at `4f8570` / `4f8b40` | `GAP-ONLY` | "Per-column temperature/humidity: weighted average over 3x3 warped site window" — the summary agrees with the read, which is corroboration for claim 1 but not for anything numeric |

## 3. Observed behavior

1. `HIGH` — **Climate is a region-site blend, not a noise ladder.** Both functions do the
   same four things: take the region window spanning `column ± 0x4000` (the region stride,
   `region-coordinate-hashing.md` claim 4, so a 2×2-to-3×3 window); find the site in it
   nearest the *warped* column; then, over the same window again, accumulate
   `Σ(value · w)` and `Σw` and return their quotient. Neither function samples
   `valueNoise2D` for the climate value itself — every value blended is read out of the
   region record.

2. `HIGH` — **The warp is literally the height field's.** The column is offset by
   `valueNoise2D(z · 0.0005, 3423) · 3 · 256` on X and
   `valueNoise2D(x · 0.0005, 23421) · 3 · 256` on Z — the same two calls, with the same
   two seed constants and the same ±768-unit amplitude, that
   `terrain-base-height-field.md` claim 5 found jittering the region sites for the height
   blend. The axes are crossed (X is warped by a function of Z and vice versa) in both
   places. This is the *only* thing climate and elevation share, and it is a lattice
   dejaggering trick rather than a coupling: it moves where the boundary falls, never what
   the value is.

3. `MEDIUM` — **The weight makes it a Voronoi field in practice.** The weight is
   `w = 1 − min((d² − d²_nearest) · 5e-07, 1)`, with distances in position units (the
   `1.5258789e-05` factor is `1/65536`, converting the 16.16 fixed-point site coordinates).
   `w` reaches zero as soon as `d² − d²_nearest ≥ 2·10⁶`. With a region stride of 16384
   units the second-nearest site is typically ~16000 units away against a nearest of a few
   thousand, so its `d²` exceeds the nearest by two orders of magnitude more than that:
   **every site but the nearest gets weight zero almost everywhere**, and the transition
   band around a Voronoi boundary is on the order of a hundred units out of 16384.
   Climate is therefore effectively piecewise constant per region site with a near-hard
   edge — not the smooth "weighted average" the `GAP_ANALYSIS` summary suggests.
   `MEDIUM` because the arithmetic rests on reading `1.5258789e-05` as a fixed-point
   conversion; the code shape itself is `HIGH`.

4. `MEDIUM` — **Temperature reads the region record's fourth word** (`puVar6[3]`, offset
   `0x0C`). Humidity's equivalent read is absent from the decompiled body — only its
   weight accumulator survives — so which field it reads was not recovered. Everything
   else about the two functions is identical line for line.

5. `HIGH` — **Climate is consumed as a `[0, 1]` value against literal thresholds.** At the
   one call site read (`World_generateRegionSite`, line 5632), humidity `> 0.8` gates a
   second lookup, temperature `<= 0.8` then selects between two site variants (`4` and
   `5`), and temperature `< 0.2` is the condition on the post-pass below. Bare float
   literals compared against the blend output; there is no degree scale anywhere near it.

6. `MEDIUM` — **A structure can warm the ground around it.** In `World_temperatureBlend`
   only: when the blended value is `< 0.2` and the tile at the column has its seventh word
   equal to `3`, the function adds `max(1 − w, 0)² · 0.3` and clamps to `1`, where `w` is
   `World_objectFalloffWeight` — the same helper `terrain-base-height-field.md` claim 6
   found flattening terrain near a structure. Humidity has no such pass. `MEDIUM`: the
   helper body was not read and the `== 3` tile tag was not traced.

7. `HIGH` — **Climate shares none of the height field's weight ladder.** Neither function
   samples the `0.0001`, `0.001` or `0.002` fields that `terrain-base-height-field.md`
   claim 3 found modulating the relief tiers. This **closes that note's `U2`** and
   **contradicts its `MEDIUM` claim 7**, which had guessed the opposite from the
   `GAP_ANALYSIS` row calling `World_baseHeightField` a "terrain/biome generator" and from
   the weight samples being taken early. Confidence dropped for cause, per
   `confidence.md` §4.

8. `LOW` — **Where the per-region climate values come from is still unread.** They are
   already in the region array when this runs, exactly as the region *heights* are for the
   base blend. Same question, same owner: `terrain-base-height-field.md` `U1` and bricks
   089–090.

## 4. Inputs / outputs

| Direction | Data | Confidence |
|---|---|---|
| in | a world column `(x, z)` in position units | `HIGH` |
| in | the region array on `this`, indexed `regX * 0x400 + regZ` and bounds-checked to `0..1023` on both axes | `HIGH` |
| in | two `valueNoise2D` seed constants, `3423` and `23421`, shared with the height field | `HIGH` |
| out | one float per axis, read by callers on a `[0, 1]` scale | `HIGH` (temperature); `MEDIUM` (humidity, whose accumulator is lost) |

## 5. State and transitions

None of its own. Like `World_baseHeightField` it reads world state — the region array — and
returns a number, so it is not pure in our sense. That is the same structural difference,
with the same consequence: our climate cannot copy the mechanism, only the shape (§8).

## 6. Invariants

- `INV-1` — climate depends on the column and the region array, never on the height field
  or on anything derived from it (claim 7) — `HIGH`
- `INV-2` — the blend is normalised (`Σ(v·w)/Σw`, `w ∈ [0, 1]`, and it returns early
  unless `Σw > 0`), so the result stays inside the range of the region values it blends —
  `HIGH`
- `INV-3` — both climate axes use the same window, the same warp and the same weight, and
  differ only in which region field they read (claim 4) — `HIGH` for the window/warp/weight,
  `MEDIUM` for "only" — `MEDIUM`
- `INV-4` — the temperature post-pass only ever *raises* a cold column, and only up to `1`
  (claim 6) — `MEDIUM`

## 7. Uncertainties

| # | Unknown | How it could be resolved | Impact if wrong |
|---|---|---|---|
| U1 | Which region field humidity blends (claim 4) — its value accumulator did not survive decompilation | reading the region writer, or the client's copy of the same function | None for 064–065, which use a noise field rather than region storage. It matters for 089–090 if the region record is ever modelled |
| U2 | Whether the stored per-region climate values are drawn uniformly, and so what distribution the blend has | reading the region writer (same read as `U1`) | None: brick 064 settled the distribution question by **measuring** its own field against a uniform one instead of importing a target (`docs/world-generation.md` §9.5) |
| U3 | Which structure the `tile[6] == 3` tag in the warming post-pass names (claim 6) | reading `World_getTileAtCoords`' record layout and the region-site writer | None until 089–090; we do not implement the pass |

## 8. Godot contract

`world/generation/temperature_field.gd` (`TemperatureField`), brick 064, and
`docs/world-generation.md` §9. Brick 065 mirrors it for humidity; brick 066 consumes both.

| Concern | Decision |
|---|---|
| Authority | shared — a pure function of `(seed, column)`, computed identically on server and client (`world-generation-authority.md`) |
| Determinism | required |
| Persistence | generated — nothing is stored per column |
| Replication | none — recomputed, never sent |

Deliberate divergences:

| Reference | Ours | Why |
|---|---|---|
| a nearest-region-site blend over stored per-region values (claims 1, 3) | one `ValueNoise` layer, cell 16384 voxels, 2 octaves, `SALT_TEMPERATURE` | their region array is world *state*; ours has to be a pure function of `(seed, column)` (`docs/rng.md` §2), because server and client both generate. A Voronoi climate would also need the region pass (089–090) to exist first, which is what would have blocked 064 behind it |
| a near-hard Voronoi edge between climate cells (claim 3) | a continuous, `C²` field | whether biome boundaries are hard or blended is brick 074's decision, and a field with a built-in discontinuity takes that decision away from it. Our transition is wide by construction — `TemperatureField.minimum_climate_span_voxels()` — and 074 can still threshold it sharply |
| the per-region value distribution is unknown (claim 3, `U2`) | a noise layer put through `ValueNoise.fade()` until the sweep is near-uniform | the reference cannot supply a target here, so the target is a *measurement*: every tenth of the range has to hold a workable share of the world, or brick 066's thresholds select nothing (`docs/world-generation.md` §9.5) |
| a structure warms cold ground below `0.2` (claim 6) | not implemented | it is a structure-placement effect, and structures are 089–090. Recorded so that brick can pick it up |
| climate is read on a `[0, 1]` scale (claim 5) | the same | kept, and it is why `at()` has no unit. A degree scale would be a number we could not check against anything, and it would invite a lapse rate — which belongs to brick 085, reading this field *and* a height, not to this field |
| climate has no altitude term anywhere in the blend (claims 1, 7) | the same | the finding, kept: cold peaks are 085's snowline, not a lapse rate baked in here |

## 9. Tests

| Test | Asserts |
|---|---|
| `test_temperature_field.gd::test_climate_is_a_separate_axis_from_the_ground` | claim 7 as a measurement: `\|r\| < 0.05` against both ground height and continentalness over the 2304-column sweep |
| `test_temperature_field.gd::test_the_temperature_salt_is_nobody_elses` | the mechanism behind it — climate cannot be a relabelling of a field it shares a salt with |
| `test_temperature_field.gd::test_no_tenth_of_the_climate_range_is_empty` | the `U2` divergence: every decile of the range holds between 5% and 16% of the world |
| `test_temperature_field.gd::test_the_curve_is_what_earns_that_distribution` | the same measurement before `spread()`, so removing the curve fails a test |
| `test_temperature_field.gd::test_a_kilometre_of_walking_never_changes_the_weather_much` | the divergence from claim 3's hard edge: no kilometre of a 400 km line crosses half the range |
