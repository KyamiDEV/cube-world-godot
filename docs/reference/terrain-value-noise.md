# Terrain value noise

| Field | Value |
|---|---|
| Subsystem | `world` |
| Reference source | `server/world/World.cpp`, `server/GAP_ANALYSIS.md` |
| Read on | `2026-09-02` |
| Overall confidence | `MEDIUM` (claims 1–6, the whole `valueNoise2D` body, are `HIGH`; claims 7–9 about how it is *used* are `MEDIUM`/`LOW` and only one design decision leans on them) |
| Backlog bricks | `060` (written for), `061`–`067` |
| Godot contract | `world/generation/value_noise.gd`, `world/generation/continentalness.gd`, `docs/world-generation.md` §5 |

## 1. Scope

Answers one question for brick 060: **what did the original use to make terrain coherent
rather than random?** `matrix-world.md` §2 indexes the evidence in one line ("value noise,
temperature/humidity blend, base height field…"); this note reads the noise function
itself, because a coherent-noise primitive is exactly what brick 060 implements.

It covers `valueNoise2D` — the primitive — and, at a much lower depth, how
`World_baseHeightField` stacks it. It does **not** cover the height, climate, river or
water-depth fields those calls feed (bricks 061–067, 080–083), the biome classifier (066),
or anything about region-site placement, which `region-coordinate-hashing.md` already
covers.

## 2. Sources examined

| Path | What was read | Read depth | Notes |
|---|---|---|---|
| `server/world/World.cpp` | `valueNoise2D`, lines 3495–3536 | `FULL` | the entire function body; it is 35 lines and self-contained |
| `server/world/World.cpp` | `World_baseHeightField`, from line 4496 | `GREP-ONLY` | grepped for its `valueNoise2D` calls and their frequency constants; the ~500-line body was **not** read, and the audit header rates it `low` |
| `server/world/World.cpp` | the domain-warp call pair at lines 4231–4241 | `PARTIAL` | read for the "constant Y as a pass selector" pattern only |
| `server/GAP_ANALYSIS.md` | the `World` section rows for `valueNoise2D`, `World_baseHeightField`, `World::terrainOffset2D`, `World_temperatureBlend`, `World_humidityBlend` | `GAP-ONLY` | one-line summaries |

## 3. Observed behavior

1. `HIGH` — **It is value noise, not gradient (Perlin) noise.** Four integer lattice
   corners are hashed to scalar values and blended; no gradient vector is ever formed.
2. `HIGH` — **The lattice is the integer part of the incoming float coordinate, taken by
   C truncation.** The corners are `(int)x`, `(int)x + 1`, `(int)y`, `(int)y + 1` — and
   `(int)` rounds toward zero, not down.
3. `HIGH` — **Corner keys mix the axes linearly**: `key = i + 0x39 * j` (`0x39` = 57),
   then `key ^= key << 13`, then the corner value is
   `1 − ((key·key·0xec4d + 0x131071f)·key + 0xd208dd0d & 0x7fffffff) · 2⁻³⁰`. That is a
   32-bit integer hash of the Hugo-Elias shape with its own constants.
4. `HIGH` — **A corner value lands in `(−1, 1]`.** The masked hash spans `[0, 2³¹)` and is
   scaled by `2⁻³⁰`, giving `[0, 2)`, subtracted from 1.
5. `HIGH` — **Interpolation is cosine**: the weight is `(1 − cos(π·t)) / 2` on each axis,
   computed through the C library's `cos`, then a plain bilinear blend of the four
   corners with those two weights.
6. `HIGH` — **There is no seed parameter.** The function takes `(x, y)` and nothing else,
   so the noise field is byte-identical in every world the game ever generated.
7. `MEDIUM` — **Passes are separated by sampling a different row of the same field.**
   Call sites pass a large constant as the second coordinate — `3423.0`, `23421.0`,
   `8432984.0` are all visible — so "the temperature field" and "the terrain-offset field"
   are two horizontal slices of one noise texture rather than two fields.
8. `MEDIUM` — **The world seed enters as a coordinate offset, not as a hash input.**
   `World_baseHeightField` samples at `*(int *)(this + 0x8001d4) + z·0.01` and
   `*(int *)(this + 0x8001d8) + x·0.01`; the audit header for the function calls those
   slots "many noise seed offsets". `MEDIUM` because the slots were not traced back to
   their writer, so "seed-derived" is inference from the name and the shape, not proof.
9. `LOW` — **Octaves are decade-spaced, not doubling.** The frequency constants visible in
   `World_baseHeightField`'s calls are `0.0001`, `0.0005`, `0.001` and `0.01`, with the
   per-layer weights applied at the call site rather than by a shared fBm helper. `LOW`:
   the body was not read, so neither the weights nor whether all four belong to one sum is
   confirmed.

## 4. The truncation defect

Claim 2 is worth stating as a consequence rather than a fact, because it is the one thing
this note directly changed in our implementation.

For `x` in `(−1, 0)`, `(int)x` is `0`. The cell to the left of the origin therefore reads
the corners of the cell to the *right* of it, and the interpolation weight becomes
`(1 − cos(π·t))/2` with `t` negative — and `cos` is even, so that weight equals the one at
`|t|`. The result: `f(−a, y) == f(a, y)` for `0 < a < 1`, and the same argument applies in
every negative cell and on both axes. **The original's terrain noise is mirrored about the
origin on each axis.**

Whether that was ever visible in the shipped game is a separate question this note does not
answer: the region grid is unsigned `0..1023` (`region-coordinate-hashing.md`, claim 1),
so a world counted from a corner may never have sampled a negative coordinate. Our world
*is* centred on the origin (`WorldBounds`, brick 050), so for us the defect would be
reachable by walking west, and `ValueNoise` uses `GenerationGrid.floor_div()` /
`floor_mod()` instead. It is the same class of bug bricks 058 and 059 found in
`WorldHash` — an asymmetry that lives entirely in the half of the world a positive-quadrant
test never visits.

## 5. Inputs / outputs

| Direction | Data | Confidence |
|---|---|---|
| in | two float coordinates, already scaled to the caller's chosen frequency | `HIGH` |
| in | nothing else — no seed, no salt, no octave count | `HIGH` |
| out | one float in `(−1, 1]`, continuous, with zero derivative at every lattice line | `HIGH` |

## 6. State and transitions

None. The function is pure and holds no cache, which is the one structural property we
keep unchanged: a coordinate's value never depends on what was sampled before it.

## 7. Invariants

- `INV-1` — the same coordinates always give the same value — `HIGH`
- `INV-2` — the field is continuous, and `C¹` at cell boundaries (the cosine weight has
  zero derivative at `t = 0` and `t = 1`) — `HIGH`
- `INV-3` — two worlds have the same noise field, differing only by where they sample it
  — `MEDIUM` (claims 6 and 8 together)

## 8. Uncertainties

| # | Unknown | How it could be resolved | Impact if wrong |
|---|---|---|---|
| U1 | Whether the `0x8001d4`/`0x8001d8` offsets are derived from the world seed (claim 8) | reading the writers of those slots | None for us: we reject offset-based seeding either way (§9), because it makes two worlds translations of one another |
| U2 | The octave weights and count in `World_baseHeightField` (claim 9) | reading the ~500-line body | None for our correctness; it would only tell us whether our 4-octave, `gain = 0.5` ladder is close to or far from the original's feel, which is a tuning question for bricks 061–067 |
| U3 | Whether the mirror in §4 was ever reachable in the original | mapping the unsigned region grid onto the float coordinates the noise is sampled at | None — we do not have the original's coordinate convention, and our own grid is signed |

## 9. Deliberate divergences

| Reference | Ours | Why |
|---|---|---|
| lattice by C truncation | `GenerationGrid.floor_div()` / `floor_mod()` on **integer voxel** coordinates | §4. Truncation mirrors the field about the origin. Staying in integers also keeps the ±524288-voxel corners of `WorldBounds` exact, which a float coordinate scaled by `0.0005` does not |
| corner key `i + 57·j`, a linear mix | `GenerationHash.value01_column()`: per-axis odd multipliers, a multiply-and-add between axes, finished with splitmix64 | A linear key collides exactly: `(i + 57, j − 1)` is the same corner, so the field repeats along a diagonal lattice. The same argument `region-coordinate-hashing.md` makes about the linear region seed |
| no seed; per-world variation by offsetting the sample point | the seed is an input to the hash, through the `GenerationHash` binding | Offsetting one fixed field means every world is a **translation** of every other: the same coastline is always somewhere, and a player who learns one world's landmarks has learned all of them. It also cannot be made to differ per pass without moving the passes relative to each other |
| pass separation by passing a large constant as the second coordinate | a named `WorldHash.SALT_*` per pass, plus the coordinate-space tag | `docs/rng.md` §4. Rows of one field are not independent — two passes whose constants happen to be close correlate, and nothing in the design says which constants are taken |
| cosine interpolation through libm `cos` | the quintic polynomial `6t⁵ − 15t⁴ + 10t³` | `cos` is a library implementation detail; `+`, `−`, `*` on doubles are exactly specified by IEEE-754. Our server and client both generate (`world-generation-authority.md`), so a last-bit disagreement about a coastline is a disagreement about where the land is. The quintic is also `C²`, where the cosine is only `C¹` |
| corner value in `(−1, 1]` from a 32-bit hash scaled by `2⁻³⁰` | `[−1, 1)` from the top 53 bits of the project's 64-bit hash | One source of randomness for the whole project (`docs/rng.md` §3), and a closed, stated range the tests can assert |
| octave frequencies and weights spelled out at each call site | `(cell_size, octaves, gain)` on the layer, normalised by the amplitude sum | A call-site ladder cannot state its own range, so nothing downstream can be range-checked; it also cannot state a slope bound, which is the property that makes a field *coherent* rather than merely smooth-looking |
| decade-spaced frequencies (`0.0001` … `0.01`) | halving cell sizes, powers of two | Powers of two keep the lattice arithmetic exact and the interpolation weight an exact float; the ratio itself is a tuning choice, revisitable per field within brick 061–067 |

## 10. Tests

| Behavior | Covered by |
|---|---|
| the same column always gives the same value, whatever was sampled between (`INV-1`) | `tests/unit/test_value_noise.gd` (through `GenerationFixtures.determinism_reason()`) |
| the field is coherent, with a stated per-voxel slope bound — and that bound is a real constraint, checked against raw positional hashing | `tests/unit/test_value_noise.gd` |
| the field is not mirrored about the origin, and crosses it without a seam (§4) | `tests/unit/test_value_noise.gd` |
| two worlds are two worlds, not translations of one (the seeding divergence) | `tests/unit/test_value_noise.gd`, `tests/unit/test_continentalness.gd` (through `GenerationFixtures.seed_sensitivity_reason()`) |
| the value stays inside its stated closed range | both files (through `GenerationFixtures.range_reason()`) |

Nothing here needs a human playtest yet. Whether the resulting continents *look* right is
a question for the first brick that turns this field into ground a player stands on
(061 onward), and the first `HUMAN_REQUIRED` brick is 091.
