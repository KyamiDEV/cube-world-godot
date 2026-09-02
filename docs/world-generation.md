# World generation

Phase D (bricks 056–090). This document grows one section per brick; it states the
contracts generation code is written against, not the code itself.

Adjacent contracts, not restated here: `docs/rng.md` (how randomness works),
`docs/persistence.md` (what is stored and what is recomputed), `docs/voxel-tools.md`
(the terrain node the generator feeds). The authority question — who is allowed to
generate — is answered in `docs/reference/world-generation-authority.md`.

## 1. Seed configuration (brick 056)

Implementation: `world/generation/world_seed.gd` (`WorldSeed`).
Tests: `tests/unit/test_world_seed.gd`.

### 1.1 A seed is not an integer

`docs/rng.md` §6 already says it: **a seed alone does not identify a world; the pair
`(seed, generation version)` does.** A bare `int` passed around lets the two drift
apart, and the symptom of that drift is a world generated half under one algorithm and
half under another — cliffs cut off mid-face at the boundary of where a player had
already explored (`docs/persistence.md` §3).

So generation call sites take a `WorldSeed`, never an integer. It carries three fields:

| Field | Is | Used for |
|---|---|---|
| `value` | the numeric seed | every `WorldHash` call; the input to sequential streams |
| `text` | what a player typed, trimmed, or `""` | display and bug reports — provenance, not identity |
| `generation_version` | the algorithm version this world was created under | deciding whether two sides, or a save and a build, agree |

`text` is deliberately excluded from identity. Two players who reached the same seed by
different routes — one typed it, one followed a link — are in the same world.

### 1.2 Where a seed comes from

| Route | Call | Notes |
|---|---|---|
| a player typed it | `WorldSeed.from_text()` | numeric text is taken at face value, so `12345` in a bug report reproduces; anything else goes through the project's own stable string hash |
| a number from elsewhere | `WorldSeed.from_value()` | a share link, a test fixture, a copied header |
| nobody chose one | `WorldSeed.arbitrary()` | a new world |
| a save | `WorldSeed.from_header()` | null (logged) on a header `SaveVersion` rejects |

`from_text("")` is seed **0** — a real, reproducible world, not an error. A blank seed
field in a UI means "pick one for me", which is `arbitrary()`; that translation belongs
to the UI, not to this type.

`arbitrary()` is the **one** deliberately unreproducible call in the generation stack,
and it is unreproducible in the only harmless way: it picks *which* world to create,
once, and is never consulted again. Everything downstream is a pure function of the seed
it returned. It still avoids engine-global randomness — `docs/rng.md` §1 forbids that
under `world/` and `tests/unit/test_rng_discipline.gd` enforces it — and mixes wall
clock, uptime and process id through the project's own stable hash instead.

### 1.3 The round-trip rule

`validate()` enforces that whenever `text` is set, re-hashing it produces `value`.

A drifted pair is worse than no text at all: the seed a player is shown, quotes in a bug
report and types back in would create a *different* world than the one they are looking
at. `display_text()` is what to show — the typed text when there is one, otherwise the
number, which `from_text()` reads at face value, so the round trip holds either way.

### 1.4 Identity is a network contract

`docs/reference/world-generation-authority.md` establishes that a client may generate
terrain locally for presentation — that is why terrain need not travel over the wire at
all. The price is that `(seed, generation version)` agreement stops being an internal
detail and becomes a **checked precondition**: a client generating from a different seed
produces a world that looks right and is wrong.

`mismatch_reason()` is that check, and it names what differs so the failure can be
explained rather than merely refused. `matches()` is its boolean form. Enforcing it at
session start is bricks 235–236; this brick provides the check, not the handshake.

### 1.5 Two ways the seed is consumed

| Need | Route | Why |
|---|---|---|
| world generation | `WorldHash.*(config.value, …)` | positional: a cell's value depends on the cell, never on visit order |
| server gameplay rolls | `config.rng_for("loot")` | a named sequential stream per subsystem, so one system drawing a different number of values cannot shift another's results |

Both are `docs/rng.md` §2's split, not a new idea; `rng_for()` exists so the world-seed
half of `DeterministicRng.from_seed_and_key()` is not spelled out at every call site.

### 1.6 What a seed writes to a save

`to_header()` builds the save header through `SaveVersion.make_header()` — container and
data versions stay that class's business — and then overrides `generation_version` with
the world's own. The build's constant describes the build; the header describes the
world, and a world keeps generating with the version it was created under
(`docs/persistence.md` §3). `from_header()` reads that value back rather than the
constant, so loading an older world on a newer build does not silently re-date it.

`seed_text` is an optional header key. A header without it still loads: the numeric seed
is the identity.

### 1.7 Out of scope for this brick

- The generation **version lifecycle** — what a bump means, which versions a build still
  implements, how a world on a retired version is handled — is brick 057, §2 below.
  `WorldSeed.generation_version` only records which version applies.
- Where a world's save directory lives (bricks 102–103) and what else its metadata holds
  (103).
- Any actual generation. The first field lands with brick 060.

## 2. Generation version lifecycle (brick 057)

Implementation: `world/generation/generation_version.gd` (`GenerationVersion`).
Tests: `tests/unit/test_generation_version.gd`.

Three files touch the number and each owns one thing, deliberately:

| File | Owns |
|---|---|
| `core/serialization/save_version.gd` | the constants (`GENERATION_VERSION`, `MIN_SUPPORTED_GENERATION_VERSION`) and the header verdicts — `core/` cannot depend on `world/`, so the number lives there |
| `world/generation/world_seed.gd` | which version applies to **one world** |
| `world/generation/generation_version.gd` | the **lifecycle**: when to bump, what this build still implements, what happens to a world whose algorithm is gone |

### 2.1 What forces a bump

`generation_version` answers one question: *would terrain generated now match terrain
already generated in this world?* Bump it whenever the answer becomes no —

- any generator, field, mask, or placement rule changes its output for some
  `(seed, coordinates)`;
- a noise or salt constant changes, or a salt is reused/renumbered (`docs/rng.md` §4);
- the RNG or string-hash algorithm changes (`docs/rng.md` §3);
- generation starts or stops consuming values in a different order for the same cell.

Do **not** bump it for anything that leaves output identical: refactors, performance
work, added logging, new content that no existing world can contain. A bump costs every
existing world its ability to grow consistently, so a spurious one is not free.

The honest test is not "did the code change" but "would a cell an existing world has not
reached yet still come out the same".

### 2.2 The supported set

`SUPPORTED` lists every algorithm this build can still reproduce, oldest first.
`docs/persistence.md` §3 is the reason it is a *set*: a world keeps generating with the
version it was created under, so a build that only implements its newest algorithm can
only open worlds it created itself.

A **hole** in the list is legal — retiring one short-lived broken version while keeping
its neighbours is a real decision. It is also why `SaveVersion.classify()` must never be
called for a world header without the list: its fallback is the
`MIN_SUPPORTED_GENERATION_VERSION..GENERATION_VERSION` *range*, which would happily
accept the retired version in the hole. `GenerationVersion.classify_header()` is the one
entry point, and it always passes the list.

### 2.3 Where a version stands

`status(version)` (and its pure form `status_of(version, current, supported)`, which the
handshake in bricks 235–236 will use to judge the *other* side's declared set):

| Status | Meaning | What happens |
|---|---|---|
| `CURRENT_VERSION` | the algorithm this build writes | new worlds get it |
| `LEGACY` | older, still implemented | loads, and keeps generating with its own version |
| `RETIRED` | older, no longer implemented | refused — never re-generated under a newer algorithm |
| `FUTURE` | newer than this build knows | refused |
| `INVALID` | not a version number | refused |

`explain(version)` and `explain_header(header)` put that in a sentence naming the
version's own summary. A refusal that says what the world was made with is a bug report;
one that says only "cannot load" is a deleted save (`docs/persistence.md` §2).

### 2.4 Retiring a version

Retiring is deliberate and announced: every world created under that version stops
loading. Remove it from `SUPPORTED`, keep its `SUMMARIES` entry so the refusal can still
name it, and raise `SaveVersion.MIN_SUPPORTED_GENERATION_VERSION` when the retirement is
at the oldest end.

### 2.5 The bump checklist

`self_check()` enforces the parts a checklist cannot be trusted with, and
`tests/unit/test_generation_version.gd` asserts it, so a half-finished bump fails the
suite rather than the first save nobody can open:

1. raise `SaveVersion.GENERATION_VERSION`;
2. append the new version to `SUPPORTED` — the newest supported version **must** equal
   the current one, or the build cannot reproduce what it writes;
3. add a one-line `SUMMARIES` entry — every supported version is describable;
4. keep `SUPPORTED[0]` equal to `SaveVersion.MIN_SUPPORTED_GENERATION_VERSION`, so the
   two files never disagree about the oldest world that still opens;
5. record what changed and why in this document.

Steps 2–4 are checked; steps 1 and 5 are the ones a human still has to mean.

### 2.6 Out of scope for this brick

- Actually implementing more than one generation algorithm, and any migration or
  side-by-side execution of two. Nothing needs it until a second version exists.
- Enforcing version agreement between a client and a server at session start (bricks
  235–236). `WorldSeed.mismatch_reason()` and `status_of()` are the checks; the handshake
  that runs them is not written yet.
- Where the header is stored (bricks 102–103).

## 3. Coordinate spaces and positional hashing (brick 058)

Implementations: `world/generation/generation_grid.gd` (`GenerationGrid`),
`world/generation/generation_hash.gd` (`GenerationHash`).
Tests: `tests/unit/test_generation_grid.gd`, `tests/unit/test_generation_hash.gd`.
Reference evidence: `docs/reference/region-coordinate-hashing.md`.

### 3.1 The spaces

Generation asks questions at five grids, and they are not interchangeable.

| Space | Type | Edge | Asked at |
|---|---|---|---|
| voxel | `Vector3i` | 1 voxel | per-cell content: stone, air, ore |
| column | `Vector2i` (x, z) | 1 voxel | per-column fields: elevation, temperature, humidity, biome |
| chunk | `Vector3i` | 16 voxels | the generator's work unit — one `VoxelBuffer` fill |
| chunk column | `Vector2i` | 16 voxels | "does this column of chunks need anything generated at all?" |
| region | `Vector2i` | 1024 voxels (512 m) | macro placement: structures, POIs, region-scale variation |

Sizes:

- **Chunk = 16 voxels** because that is Voxel Tools' *data* block size, fixed for
  `VoxelTerrain`. A generator is handed one such block at a time, so any other generation
  grid would straddle block boundaries on every fill. This is **not**
  `DEFAULT_MESH_BLOCK_SIZE` (ADR 0002), which is a rendering choice and may become 32
  without moving a generated voxel.
- **Region = 1024 voxels** so the region grid is exactly 1024 × 1024 across `WorldBounds`'
  horizontal extent (brick 050). The 1024 × 1024 *shape* is the one piece of the
  original's grid worth keeping; the size in voxels is ours, scaled to our own, much
  smaller world.

Two rules the conversions enforce:

1. **Floor division, never truncation.** `-1 / 16` is `0` in GDScript, which would put
   voxel −1 and voxel 0 in the same chunk and make every grid asymmetric around the
   origin. `GenerationGrid.floor_div()`/`floor_mod()` are the only correct forms, and are
   public so a later, coarser grid uses the same ones.
2. **Grids are half-open**: a cell owns `[origin, origin + size)`. `WorldBounds.aabb()` is
   inclusive at its maximum face because `AABB.has_point()` is, so the single voxel plane
   at `x == +524288` is inside the world bounds and outside the region grid.
   `is_region_in_world()` is the authority for "is there a region here".

Unlike the reference's `0..1023` grid counted from a corner, ours is signed and centred:
region coordinates run `−512..511`. A player standing at spawn is not standing in a
corner.

### 3.2 One binding per world

`GenerationHash.for_world(world_seed)` is how generation code obtains a hash, and the
only supported way. It adds three things to the `WorldHash` primitive:

| Adds | Why |
|---|---|
| binding to a `WorldSeed` | §1.1 — call sites take a `WorldSeed`, never an integer. Reading `config.value` at each call site would re-open the drift hole the type exists to close |
| a version check, **once** | this is where a `WorldSeed` becomes numbers, so it is where "this build cannot reproduce that world's algorithm" is refused (§2.3). Never per call: hashing is the hottest path in the project |
| a **space tag** per grid | chunk `(3, 0, 5)` and voxel `(3, 0, 5)` are different places carrying the same numbers. Untagged, a per-chunk pass and a per-voxel pass sharing a salt would agree cell for cell |

The tag is `space * SPACE_SALT_STRIDE + salt`, applied to the salt. `Space.VOXEL` is `0`,
so voxel-space hashing stays byte-identical to a bare `WorldHash` call — the tagging is
free for the base case. Space values are baked into every world generated with them and
follow the salt rule of `docs/rng.md` §4: append, never renumber, never reuse. Every
`WorldHash.SALT_*` constant must stay below the stride, which the tests assert over the
whole constant list rather than trusting the next person to check.

`refuse_reason()` is the pure form of the check, for a load screen or the session
handshake (bricks 235–236) to ask before anything is constructed.

### 3.3 The generation version is not mixed into the hash

A version **selects** which algorithm runs; it is not an **input** to that algorithm.

Mixing it in would look tidy and cost two real things: every bump would reshuffle every
unrelated pass, so a fix to the tree mask would move every mountain; and "version 2 is
version 1 with different numbers" would become indistinguishable from a genuine
algorithmic change, which is exactly the distinction §2.1 asks a human to make. The
version is therefore checked at binding time and never touched again.

### 3.4 What the original did, and what we do instead

`docs/reference/region-coordinate-hashing.md` records the read; §9 there is the full
divergence table. The short form: the original seeded the C library's **process-global**
`rand()` with a **linear** combination of the region coordinates and the world seed
(`srand(regX + 0x108a + regZ * 0x400 + seed * 3)`), then took its first decision from the
low bit of an LCG. We hash instead of seeding a global, avalanche instead of adding, and
read from the top bits — for reasons `docs/rng.md` §§1–3 already state, now with a
concrete example behind them.

### 3.5 A defect this brick found in the primitive

Brick 058's first test run failed on `hash2(-7, -9) == hash2(7, 9)`, and the collision was
real. `WorldHash` combined its per-axis products with XOR; negating an integer flips every
bit above its lowest set bit, so two axis products with the same trailing-zero count
contribute the *same* suffix mask, and XOR cancelled both. The result was a point symmetry
through the origin across every coordinate pair whose trailing-zero counts matched —
roughly a quarter of all columns, mirrored, plus the same effect for any subset of axes.

The fix multiplies by an odd constant between axis folds, so each axis reaches the high
bits before the next one arrives and no later term can cancel an earlier one.
`tests/unit/test_world_hash.gd` covers it.

This was free to fix here and would not have been later: after brick 060 the same change
is a generation version bump (§2.1). It is the concrete argument for `docs/rng.md` §3 —
the algorithm is a contract, and the time to get it right is before the first world
exists.

### 3.6 Out of scope for this brick

- Any actual field, noise layer or placement rule. `GenerationHash` produces uniform
  values at coordinates; turning those into terrain starts at brick 060.
- New salts. Each pass adds the one it needs to `WorldHash` as it lands, per
  `docs/rng.md` §4.
- Using `is_region_in_world()` for anything. Region-scale placement is bricks 089–090.
- A region *record* — what a region contains, and whether it is cached. This brick
  defines the coordinate and its hash, nothing that lives at it.

## 4. Deterministic test fixtures (brick 059)

Implementation: `tests/fixtures/generation_fixtures.gd` (`GenerationFixtures`).
Tests: `tests/unit/test_generation_fixtures.gd`.

### 4.1 What every generation pass owes

Bricks 060–090 each add one pass — a noise layer, a field, a classifier, a placement
rule. Every one of them owes the same four properties, which come straight from
`CLAUDE.md` §1's determinism rule:

| Property | The failure it rules out |
|---|---|
| **repeatable** | the same coordinate answered twice gives two answers |
| **order-free** | the answer depends on what was generated before it, so walking into a chunk from the east builds different ground than walking in from the west |
| **seed-sensitive** | the seed never reaches the result, and every world is the same world |
| **in range** | a value leaves its stated interval, or is NaN, and the terrain built from it is silently missing |

Left to each brick, those would be re-asserted thirty different ways, each against
whichever handful of coordinates its author happened to think of — and, as §4.3 explains,
the coordinates an author thinks of are the ones that work.

`GenerationFixtures` is the shared floor: the worlds, the coordinates, and the checks.
A pass's own test file supplies the pass; everything else is common.

### 4.2 The named worlds

Four `WorldSeed`s, each with a **pinned** numeric value: seed `0` (the accidental default
of every uninitialised field, and the seed where a pass that multiplies by it collapses),
a typed phrase through the string-hash branch, `"12345"` through `seed_from_text()`'s
face-value branch, and `-1`, every bit set, for a pass that assumes a non-negative seed.

The values are pinned rather than computed. That makes the fixture set a **contract on the
seed hash**: if `WorldHash.seed_from_text()` ever changes, the fixture fails rather than
quietly agreeing with itself, and `docs/rng.md` §3 says a changed hash after brick 060 is
a version bump. The same argument is why `test_generation_fixtures.gd` also pins one
golden signature (§4.5).

### 4.3 The coordinate samples

Five sample lists — voxels, columns, chunks, chunk columns, regions — every entry present
for a stated reason, and each list handed out freshly built so a test that sorts what it
was given does not change what the next test samples.

What they deliberately cover:

- **the origin**, which every off-by-one lands on or beside;
- **negative axes**, where `floor_div` vs truncation and sign symmetries live — half the
  world, and the half a positive-quadrant sample set never visits;
- **`(-7, 5, -9)` and its mirror `(7, 5, 9)`**, the exact pair brick 058's defect
  identified, so a returning symmetry is visible rather than merely improbable;
- **`(9, -9)` and `(-9, 9)`**, two columns holding the same numbers in the opposite
  order, which a pass that folds x and z together cannot tell apart and a diagonal-only
  sample set never asks about;
- **cell boundaries**: the last voxel of a chunk and the first of the next, on both sides
  of the origin; the last column of region `(0, 0)` and the first of `(1, 1)`;
- **the extremes**: the world ceiling and floor, the far horizontal corners of
  `WorldBounds`, and both corners of the region grid — coordinates large enough that a
  32-bit intermediate overflows and a float one loses exactness.

`self_check()` re-asserts that coverage. Adding a sample is free; deleting the one
negative-axis voxel would quietly turn every Phase D determinism test into a
positive-quadrant test, and nothing else would notice.

### 4.4 The checks, and why two of them take a factory

All of them return `""` when the property holds and a reason when it does not — the
convention `WorldSeed.validate()`, `GenerationHash.refuse_reason()` and
`GenerationVersion.self_check()` already use, so a check reads the same in a test, in a
debug probe and in a server-side self-test.

`repeatability_reason()`, `range_reason()` and `variation_reason()` take a sampler.
`determinism_reason()` and `seed_sensitivity_reason()` take a **factory** that builds one,
because their properties can only be observed against a freshly built pass: a pass that
numbers cells as it first meets them answers a repeated call consistently — it passes
repeatability — and is entirely visit-order dependent. Order independence is checked by
running three orders (forward, reversed, odds-then-evens) against three separate
instances.

`variation_reason()` is the least obvious and not the least useful: a stub returning
`0.0`, a field whose amplitude ended up zero, and a mask nothing ever passes are all
repeatable, all order-free, all in range, and all wrong.

### 4.5 Golden signatures

`signature()` digests what a sampler answered across a sample list into 16 hex digits —
order-sensitive, and type-strict, so a field that started returning integers moves it. A
pass pins one string; when it changes, the test asks the question that matters: **is this
a bug, or a generation version bump?** (§2.1). Pinning one digest is cheap; pinning a
hundred expected values is how a test file stops being read.

The digest reads the exact bits of a float rather than its `str()` form, because two
genuinely different terrains print identically to six digits.

### 4.6 A second defect this found in the primitive

Brick 058 fixed one route to a mirror world (§3.5). The first fixture run found a second
one, which that fix had left open: for the `typed` world, `value01_column(-7, -9)` and
`value01_column(7, 9)` were still equal, and so were `(9, -9)` and `(-9, 9)`.

Multiplication distributes over negation — `(-v) * C == -(v * C)` — so multiplying
*preserves* an exact negation instead of destroying it. And the running value does come
out of the first fold as the exact negative of its mirror, systematically:
`s ^ (-a) == -(s ^ a)` holds for every odd `a` whenever the effective seed
`seed_value * 31 + salt` is **even**. The second axis's own negation mask then cancels
against it and the two coordinates hash identically. That is half of all (seed, salt)
pairs, mirrored through the origin, for every column with both coordinates odd — measured
at 15% of a 151 263-pair sweep before the fix.

Brick 058's own regression test did not catch it because every assertion in it happens to
use an odd effective seed, where the identity does not hold. The lesson is in the test
now: `test_no_mirror_world_at_any_seed_and_salt_parity` sweeps both parities.

The fix adds an odd constant after each fold (`WorldHash._ROUND`), which turns the mirror
value into `-v + 2 * _ROUND` — no longer any negation mask away from `v`, so nothing
downstream can cancel it. A rotation fixes the same class and was measured 69% slower in
this interpreter against 2% for the addition, on what `generation_hash.gd` already calls
the hottest path in the project. Free to fix now; after brick 060 it is a version bump
(`docs/rng.md` §3).

Both defects were found the same way: by a test that sampled a coordinate somebody had
picked *because* it was awkward. That is the entire argument for §4.3.

### 4.7 Out of scope for this brick

- Any generation pass to run the checks against. 060 is the first one.
- Golden *terrain* — a stored chunk of voxel content to diff against. Nothing generates
  voxels yet, and the digest in §4.5 is the cheaper form of the same guarantee.
- A performance fixture. Generation's row in `docs/performance-budget.md` stays empty
  until there is something to measure (bricks 257–258).
- Making the checks available to production code. They live under `tests/`, which
  `docs/architecture.md` already exempts from the layer rules in one direction only.

## 5. The coherent noise layer and the continentalness field (brick 060)

Implementation: `world/generation/value_noise.gd` (`ValueNoise`),
`world/generation/continentalness.gd` (`Continentalness`).
Tests: `tests/unit/test_value_noise.gd`, `tests/unit/test_continentalness.gd`.
Reference: `docs/reference/terrain-value-noise.md`.

**This is the first brick that generates anything.** From here on, a change to
`WorldHash`, `GenerationHash`, `ValueNoise` or the pinned constants in `Continentalness`
moves ground a player has already walked on, which makes it a generation version bump
(§2.1), not a fix. Both of the free fixes this project had were taken in 058 and 059.

### 5.1 Why `GenerationHash` is not a field

`GenerationHash` (§3) answers every coordinate independently. That is exactly what a
placement mask wants — "does a tree stand here?" must not depend on the neighbours — and
exactly what a *field* cannot use. Terrain whose height is a hash per column is a forest
of one-voxel spikes: there is no slope to walk up, no valley to put a river in, no
coastline to find, and no scale at which a biome could be said to exist.

A field needs **spatial coherence**: neighbouring columns must be related, and related by
a stated amount. `ValueNoise` is that layer, and it is built out of `GenerationHash`
rather than beside it, so everything §3 guarantees — the seed binding, the checked
version, the space tag, the order-freedom — still holds underneath it.

### 5.2 What the layer is

Value noise: hash the corners of a coarse lattice, interpolate between them, sum a few
such layers at halving cell sizes.

| Parameter | Meaning |
|---|---|
| `cell_size` | edge of the coarsest lattice cell, in voxels — a power of two |
| `octaves` | how many layers are summed, each at half the previous cell size |
| `gain` | amplitude ratio between one layer and the next |
| `salt` | the pass's own `WorldHash.SALT_*`, so this field does not correlate with any other |

`value()` returns `[-1, 1]` and `value01()` returns `[0, 1]`; both are closed intervals,
clamped at the ends, because a caller that is promised a closed range should not have to
handle the one-ulp overshoot a normalised floating-point sum can produce.

Four decisions in the implementation are determinism decisions before they are quality
ones:

1. **The lattice lives in integer voxel space.** No float ever carries a world
   coordinate, so nothing loses exactness at the ±524288-voxel corners of `WorldBounds`.
   The interpolation weight is `floor_mod(x, cell) / cell` — an exact float, because the
   cell is a power of two.
2. **`GenerationGrid.floor_div()`, never `/`.** Truncating division puts voxel −1 and
   voxel 0 in the same cell and mirrors the whole field about the origin. This is not a
   hypothetical: it is what the original's own `valueNoise2D` does
   (`docs/reference/terrain-value-noise.md` §4), and it is the third time in Phase D that
   the same class of defect has appeared in the half of the world a positive-quadrant test
   never visits.
3. **The fade is a polynomial** — §5.3.
4. **Octaves are separated by a lattice offset, not by a salt.** Salts are one per pass
   and must stay below `GenerationHash.SPACE_SALT_STRIDE` (`docs/rng.md` §4), so
   `salt + octave` would walk into the next pass's salt. Offsetting the lattice reads a
   different part of the same hash field instead. Without the offset every octave samples
   lattice `(0, 0)` at the world origin and agrees there, putting a spike at the one
   coordinate everything else is measured from.

### 5.3 The fade is a polynomial, and that is a networking decision

The original interpolates with `(1 − cos(π·t)) / 2`. We use Perlin's quintic fade,
`6t⁵ − 15t⁴ + 10t³`.

`cos` is a C library implementation detail: nothing requires two platforms, or two
versions of one platform, to return the same last bit. Addition, subtraction and
multiplication on doubles are exactly specified by IEEE-754 and identical everywhere.
Since **both the server and the client generate** the world from the same seed
(`docs/reference/world-generation-authority.md`), a last-bit disagreement about a
coastline is a disagreement about where the land is — the client may generate, but the two
copies have to agree about what they generated.

The quintic is also the better curve on its own merits: zero first *and* second derivative
at both ends, so cell boundaries leave no crease once the field becomes a slope, where the
cosine leaves a `C¹`-only join and a linear blend leaves a visible ridge along every
lattice line.

### 5.4 The slope bound

`max_slope_per_voxel()` states the most the field can change between two columns one voxel
apart. It is derived, not measured: along one axis an octave is `lerp(a, b, fade(t))` with
`a, b ∈ [-1, 1]`, so its slope is at most `2 · 1.875 / cell` per voxel (`1.875` is the
maximum of `fade'(t) = 30t²(1−t)²`), and the layer's bound is the amplitude-weighted sum of
those over the amplitude sum.

Having it as a number rather than a comment is the point. "Coherent" is the entire claim
this brick makes, and a claim nothing checks is a claim that quietly stops being true:
`tests/unit/test_value_noise.gd` walks 1201 adjacent columns across the origin and asserts
every step against the bound, then runs the same walk over raw `GenerationHash` values to
show the check can fail. A useful consequence falls out of the algebra: with `gain = 0.5`
and halving cells, **every octave contributes the same amount to the bound** — detail
octaves buy detail, not coherence.

### 5.5 The continentalness field

`Continentalness` is the layer's first user and the first thing this project generates: a
per-column value in `[0, 1]` where `0` is the middle of an ocean and `1` the middle of a
landmass.

| Constant | Value | Why |
|---|---|---|
| `CELL_SIZE_VOXELS` | `GenerationGrid.REGION_SIZE_VOXELS * 8` = 8192 voxels = 4096 m | the coarsest layer is eight regions across, so a continent is something you travel through rather than across |
| `OCTAVES` | 4 | which makes the finest layer exactly one region across — the grid brick 089 places structures on gets a value of its own rather than an interpolation of its neighbours' |
| `GAIN` | 0.5 | the field stays dominated by its coarsest layer, which is what makes it a *macro* field |
| salt | `WorldHash.SALT_CONTINENTALNESS` (10) | appended, never renumbered (`docs/rng.md` §4) |

**It deliberately decides nothing.** It does not say where sea level is (brick 080), how
high the ground stands (061), or what grows there (067–073). Every one of those reads this
field and adds its own rule, and keeping the field and the thresholds apart is what lets
080 move a coastline later without reshaping the continents underneath it.

One property no determinism check covers, and the field's own test asserts: it has to
**span** its range. A macro field whose values all sit near 0.5 is repeatable, order-free,
seed-sensitive, in range, varied — and has no oceans and no interiors. Measured over 2304
columns spread across roughly 24 coarse cells per axis: lowest `0.083`, highest `0.970`,
mean `0.501`.

### 5.6 Out of scope for this brick

- Anything that reads the field. Elevation is 061; the shaping passes are 062–063; the
  climate fields are 064–065; sea level is 080.
- A redistribution curve or a land-fraction target. The field is the raw macro shape;
  which part of it counts as land is a decision, and it belongs to the brick that makes it.
- 3D noise. Caves (077–078) need a 3D form of the same layer; nothing before them does,
  and adding it now would ship an untested surface.
- Domain warping, ridged/billow variants, and analytic derivatives. Real needs, none of
  them this brick's.
- Any voxel. Nothing is written to a `VoxelBuffer` yet; the generator that does that
  arrives with the passes that have something to write.

## 6. The elevation field (brick 061)

Implementation: `world/generation/elevation_field.gd` (`ElevationField`).
Tests: `tests/unit/test_elevation_field.gd`.
Reference: `docs/reference/terrain-base-height-field.md`.

The first field that answers a question about *terrain* rather than about the world map.
`Continentalness` (§5.5) says how far inland a column is; this turns that into a height.

### 6.1 The datum

**Elevation is a signed height in voxels, measured from `y = 0`.** That plane is the
centre of `WorldBounds`' vertical extent and the only vertical landmark this project has
agreed on. Voxels rather than metres, because the generator that will consume this field
writes voxels; `at_metres()` exists for a log line, never for generation arithmetic.

`y = 0` is a datum, **not a sea level**. Where the water goes is brick 080, and it is a
constant applied to these numbers rather than a property of them — which is what lets 080
move the waterline without regenerating a column.

### 6.2 The composition

```text
shore     = shore_weight(continentalness(column))          # [0, 1]
base      = lerp(OCEAN_FLOOR_VOXELS, LAND_BASE_VOXELS, shore)
amplitude = lerp(RELIEF_AMPLITUDE · RELIEF_OCEAN_SCALE, RELIEF_AMPLITUDE, shore)
height    = base + amplitude · relief01(column)            # relief01 in [0, 1]
```

| Constant | Value | Why |
|---|---|---|
| `OCEAN_FLOOR_VOXELS` | `-96` = −48 m | the floor of a basin, deep enough to read as ocean once 080 fills it |
| `LAND_BASE_VOXELS` | `64` = +32 m | the continental plain. Not symmetric with the ocean floor: relief is added *upward*, so the mean of the land is `LAND_BASE + RELIEF_AMPLITUDE / 2`, and a symmetric pair would put that mean far above anything the ocean floor balances |
| `RELIEF_AMPLITUDE_VOXELS` | `128` = 64 m | valley floor to ridge line on fully landward ground |
| `RELIEF_OCEAN_SCALE` | `0.25` | what a fully seaward column keeps of that amplitude. Not zero — a dead-flat sea floor is as wrong as a mountainous one |
| `SHORE_MIDPOINT` / `SHORE_WIDTH` | `0.5` / `0.16` | §6.3 |
| relief layer | cell `1024`, 6 octaves, gain `0.5`, salt `WorldHash.SALT_ELEVATION` | §6.4 |

Range: `[-96, +192]` voxels, i.e. `[-48 m, +96 m]`. The minimum is the bare ocean floor,
because **relief is additive-upward and never signed** — the base is a genuine floor, and
an ocean floor cannot be turned into a mountain by a noise sample. That is the one shape
decision taken from the original (`terrain-base-height-field.md` §3, claim 2). Both ends
sit inside a quarter of `WorldBounds.HALF_EXTENT_VERTICAL_VOXELS`, leaving room for caves
below (077) and sky above; the test asserts the headroom rather than trusting it.

### 6.3 The shore band

`shore_weight()` is `0` at or below continentalness `0.42`, `1` at or above `0.58`, and
Perlin's quintic in between — the same `ValueNoise.fade()` the noise layer interpolates
with, exposed for the purpose rather than copied.

Two decisions:

1. **The band is narrow and centred on `0.5`.** Narrow, so the ocean floor and the
   interior are each themselves over most of their range and the transition is a *coast*
   rather than a world-wide ramp. Centred on the field's own middle, because how much of
   the world ends up as **land** is 080's decision (where the water plane goes), not
   something 061 should pre-bake. §5.6 said a land-fraction target belongs to the brick
   that makes it; this is that promise kept.
2. **The quintic, not a cubic `smoothstep()`.** §5.3's argument one level up, and it bites
   harder here: a `C¹`-only curve leaves a slope discontinuity at each end of the band, and
   a slope discontinuity in a *blend* becomes a crease running along a continentalness
   contour — in-game, a straight-edged terrace following the coast at exactly the band's
   edge. Written through `ValueNoise.fade()` rather than the engine's `smoothstep()` for
   the same reason the fade is a polynomial at all: the shape of the world should not
   depend on an engine implementation detail.

### 6.4 Relief starts where continentalness stops

The relief layer's coarsest cell is `GenerationGrid.REGION_SIZE_VOXELS` (1024 voxels =
512 m) — **exactly the cell size at which `Continentalness`' finest octave stops** (§5.5).
The two fields meet at the region grid instead of overlapping: continentalness carries
every scale coarser than a region, relief every scale finer. Six octaves take the finest
relief cell to 32 voxels = 16 m, a hillside feature and still four times the terrace
height brick 063 will quantise to, so the detail survives that pass rather than being
rounded away by it.

The layer has its own salt (`SALT_ELEVATION`), not continentalness's: two fields sharing a
salt are one field, and the test asserts they differ.

### 6.5 The step bound, and what it is for

`max_step_per_voxel()` states the most `at()` can change between two columns one voxel
apart. Derived before any sample is taken, in the same spirit as
`ValueNoise.max_slope_per_voxel()` (§5.4):

```text
|dh/dx| <= (|LAND_BASE - OCEAN_FLOOR| + RELIEF_AMPLITUDE·(1 - RELIEF_OCEAN_SCALE))
           · shore_max_slope() · |dc/dx|          # the coast
         + RELIEF_AMPLITUDE · |dr/dx|             # the hillside
```

which comes to **2.179 voxels per voxel**. `shore_max_slope()` is
`ValueNoise.FADE_MAX_SLOPE / SHORE_WIDTH` = `11.719`: narrowing the shore band steepens
the coast in exact proportion, which is why it is a named number rather than a division
buried in the bound.

The bound is a worst case over the whole world; a real kilometre walk across the origin
measures a largest step of `0.231` voxels and 95 voxels of total climb. What the number is
*for* is that the test can assert a real walk against a figure derived from the constants
alone — and `test_the_step_bound_is_a_real_constraint` runs the same check over raw
`GenerationHash` values at the same amplitude, where it fails on essentially every step, so
the assertion is known to be capable of failing.

### 6.6 What the field measures

Over 2304 columns spread across ~24 continentalness cells per axis (the same sweep §5.5
uses): lowest `-93.2`, highest `+180.5`, mean `+24.3` voxels. 50.1% of those columns are
landward of the shore midpoint and 53.1% stand above the datum — the field is not biased
toward either end of its own range, which is the property a height field can satisfy every
determinism check while failing.

### 6.7 Out of scope for this brick

- **Sea level, water, and the land fraction.** Brick 080. This field says how high the
  rock is and nothing about what covers it.
- **Erosion and a per-place ruggedness field.** Brick 062. The original modulates each of
  its three relief tiers by a separate *squared* weight field one decade coarser
  (`terrain-base-height-field.md` §3, claim 3), which is the mechanism 062 should reach
  for first — the squaring is the part that makes flat the default and mountains the
  exception. 061 modulates by the field it already has and stops there.
- **Terracing.** Brick 063. `at()` returns a continuous height on purpose; the blocky
  silhouette is a separate, later quantisation, and the relief layer's finest octave is
  sized so it survives that pass.
- **Rivers, roads, and structure flattening.** Bricks 062, 080–083, 089–090. The original
  applies all of them as terms that scale relief *toward* the base and never away from it
  (claim 6) — worth keeping when those bricks arrive.
- **Climate.** Bricks 064–065. Whether temperature and humidity share elevation's weight
  fields or get their own is `terrain-base-height-field.md` `U2`, and 064 should resolve
  it rather than assume.
- **Any voxel.** Still nothing is written to a `VoxelBuffer`; the surface a column's height
  lands on is the generator's business.

## 7. The erosion / shape pass (brick 062)

Implementation: `world/generation/erosion_pass.gd` (`ErosionPass`).
Tests: `tests/unit/test_erosion_pass.gd`.
Reference: `docs/reference/terrain-base-height-field.md` §3 claim 3, §8.

§6 gives every column the same relief budget once its shore weight is known: a landward
column always carries the full `RELIEF_AMPLITUDE_VOXELS`. That is a world where every
stretch of land is equally hilly — no plains to cross, and no ranges to stand out against
them. This pass decides **where** the ground may be rugged, and **what shape** the
surviving relief takes.

### 7.1 It is a pass, not a second field

```text
base_at(column) <= at(column) <= elevation().at(column)
```

Every term multiplies relief by something in `[0, 1]`; nothing touches the base. That is
exactly the shape of all four of the original's own post-passes — a river/climate gate, a
road field, a water-depth field and a structure falloff, each of which scales relief
*toward* the base and never away from it (`terrain-base-height-field.md` §3 claim 6,
`INV-2`).

Three consequences worth stating, because they are why the brick is built this way:

1. **The range is inherited, not restated.** `MINIMUM_VOXELS`/`MAXIMUM_VOXELS` are §6's,
   and both ends stay reachable — the minimum at a column with no relief, the maximum at
   full ruggedness on a landward relief peak. So it is still a closed range, and the
   `WorldBounds` headroom argument of §6.2 carries over unchanged.
2. **Bricks 080–083 and 089–090 join the same product.** Rivers, roads and structure
   flattening are more factors, not a rewrite of the composition.
3. **061 stays readable on its own.** `unshaped_at()` is the height before shaping, which
   is what makes "the pass only lowers" a thing a test can check rather than a claim.

### 7.2 The two terms

```text
shore  = elevation.shore_at(column)                          # [0, 1], sampled once
relief = ruggedness(column) · valley_shaped(relief01(column))
height = base_for(shore) + relief_amplitude_for(shore) · relief
```

| Term | Answers | Curve |
|---|---|---|
| **ruggedness** | *where* the ground may be rugged | `RUGGEDNESS_FLOOR + (1 − FLOOR)·w²`, `w` a `ValueNoise` layer in `[0, 1]` |
| **valley bias** | *what shape* the surviving relief takes | `lerp(r, r², VALLEY_BIAS)` |

| Constant | Value | Why |
|---|---|---|
| `RUGGEDNESS_CELL_SIZE_VOXELS` | `8192` = 4096 m | eight regions, i.e. 8 × §6's relief cell. The original's weight field sits one *decade* coarser than the tier it modulates; a decade is not available to us (powers of two only, §5.2), so this is the nearest one |
| `RUGGEDNESS_OCTAVES` | `3` | finest cell `2048` voxels — see §7.3 |
| `RUGGEDNESS_GAIN` | `0.5` | the conventional half |
| `RUGGEDNESS_FLOOR` | `0.1` | what the flattest ground in the world keeps: 12.8 voxels = 6.4 m of roll. Not zero — `w²` at zero is a mathematical plane, and a plane is not a plain |
| `VALLEY_BIAS` | `0.5` | half-way to a full squaring of the relief |
| salt | `WorldHash.SALT_RUGGEDNESS` (`11`, appended) | a weight field sharing the relief's salt would place mountains exactly where the relief already peaks, which is not a decision |

**The squaring is the mechanism, and it is the original's.** Its weight fields are each
remapped to `[0, 1]` as `(n + 1)·0.5` and then multiplied by themselves (claim 3): `w²`
puts most of its mass near zero, so **flat is the default and rugged is the exception**.
That is the half of claim 3 brick 061 deliberately left here (§6.7). Measured over the
sweep of §7.5, the mean ruggedness weight is `0.342` against a `[0.1, 1]` midpoint of
`0.55` — the `1/3` the reference note predicts for a squared uniform weight, shifted by
the floor.

**The valley bias is why the pass is called erosion rather than modulation.**
`lerp(r, r², k)` has fixed points at `0` and `1` and is strictly below `r` in between, so
it lowers slopes without moving either the valley floor or the ridge line: material comes
off the hillsides, and the stated range survives untouched.

Both curves are integer powers written as multiplications, never `pow()`. Same argument
§5.3 makes about `cos`: `pow` is a libm entry point with no bit-exactness guarantee, both
server and client generate from the same seed, and a last-bit disagreement about a
hillside is a disagreement about where the ground is.

### 7.3 A weight field is coarser than what it weights

`RUGGEDNESS_OCTAVES = 3` puts the finest ruggedness cell at `8192 >> 2` = 2048 voxels,
**twice** the coarsest relief cell (1024). Every scale this field carries is therefore
coarser than every scale it modulates, which is the property the octave count is chosen
for: a weight octave finer than a relief octave stops *placing* relief and starts *being*
relief — with the amplitude of a multiplier and no slope bound of its own. The test
asserts the inequality rather than the octave count alone.

The scale ladder across the three fields is now, coarsest first:

| Field | Cells | Carries |
|---|---|---|
| `Continentalness` | 8192 → 1024 | land and ocean |
| `ErosionPass` ruggedness | 8192 → 2048 | where relief is allowed |
| `ElevationField` relief | 1024 → 32 | the hills themselves |

Ruggedness overlaps continentalness deliberately — a mountain range and a landmass are the
same size of thing — and it is a different field because it has a different salt.

### 7.4 The step bound, and an honest note about it

`max_step_per_voxel()` is derived before any sample is taken, like §5.4's and §6.5's:

```text
|dh/dx| <= (|LAND_BASE − OCEAN_FLOOR| + RELIEF_AMPLITUDE·(1 − RELIEF_OCEAN_SCALE))
           · shore_max_slope() · |dc/dx|                       # the coast, as in §6.5
         + RELIEF_AMPLITUDE · ( 2·(1 − RUGGEDNESS_FLOOR)·|dw/dx|
                              + (1 + VALLEY_BIAS)·|dr/dx| )    # the hillside
```

which comes to **2.627 voxels per voxel**, against §6.5's `2.179`. The bound went **up**
while every height went **down**, and that is not a mistake: `v'(r) = (1 − k) + 2kr` peaks
at `1 + k` on a ridge line, so the valley bias multiplies the relief's own slope by up to
`1.5` where the relief is highest. **This pass lowers ground but can locally steepen it.**
Steeper hillsides are the point of an erosion pass; the bound is what keeps "steeper" from
quietly becoming "a cliff", and `test_the_step_bound_is_a_real_constraint` runs the same
check over raw `GenerationHash` values to prove the assertion can fail.

### 7.5 What the pass measures

Over the same 2304-column sweep §5.5 and §6.6 use, for the `typed` world:

| | before (§6.6) | after |
|---|---:|---:|
| lowest | `−93.2` | `−95.7` |
| highest | `+180.5` | `+148.6` |
| mean | `+24.3` | `−5.1` |
| columns above the datum | 53.1% | 49.8% |

It removes `29.4` voxels of ground from the average column and `89.2` from the column it
flattens hardest, and the extremes survive it — the sweep still reaches an ocean basin and
still reaches high ground, which is the property a flattening pass can satisfy every
invariant above while destroying. A kilometre walk across the origin now measures a
largest step of `0.076` voxels and 39.9 voxels of climb (was `0.231` and 95): that
particular line runs over ground the ruggedness field decided is a plain, which is the
pass working rather than a regression.

The mean dropping below the datum is expected and is **not** a statement about sea level:
`y = 0` is a datum (§6.1), the land fraction is brick 080's decision, and 080 now has a
world where the ground under the waterline it picks is genuinely varied.

### 7.6 Out of scope for this brick

- **Sea level and water.** Still brick 080, and now with §7.5's distribution to choose
  against.
- **Rivers, roads, structure flattening.** Bricks 080–083, 089–090. They join §7.1's
  product as further `[0, 1]` factors; the invariant is written so they can.
- **Terracing.** Brick 063, which reads *this* pass rather than 061 — the terraces should
  follow eroded ground, and `at()` stays continuous on purpose.
- **Ruggedness as a biome input.** Brick 066 may want `ruggedness_noise_at()`; the accessor
  is public and unsquared for that, but no biome decision is made here.
- **A hydraulic or thermal erosion simulation.** Both need neighbour context and iteration
  over a whole region, which is `VoxelGeneratorMultipassCB` territory and a different
  brick's problem. Every term here is a pure function of one column, as `docs/rng.md` §2
  requires of a field both the server and the client generate.
- **Any voxel.** Still nothing is written to a `VoxelBuffer`.

## 8. The terrace / block-world shaping pass (brick 063)

Implementation: `world/generation/terrace_pass.gd` (`TerracePass`).
Tests: `tests/unit/test_terrace_pass.gd`.
Reference: none — see §8.6.

§6 and §7 produce a continuous height: a smooth landscape that happens to be stored in
voxels. This pass is what makes it a **block world**. Every column's ground is snapped
down to the terrace plane below it, so a hillside stops being a ramp and becomes a
staircase of flat shelves separated by clean vertical faces. It is the last shaping pass
over the height field, and the one that gives the world its silhouette.

### 8.1 The whole pass

```text
at(column) = floor(erosion.at(column) / H) * H,   H = TERRACE_HEIGHT_VOXELS = 8
```

| Constant | Value | Why |
|---|---|---|
| `TERRACE_HEIGHT_VOXELS` | `8` = 4 m | pinned from the other end by brick 061 — see §8.2 |
| salt | none | quantisation is a pure function of a height this pass is handed; there is nothing here for a seed to vary, and `docs/rng.md` §4's append-only salt list is untouched |
| noise layers | none | the pass costs one division and one `floor` per column on top of §7 |

Three things follow from it being a **floor** rather than a rounding.

**It only ever lowers ground.** `floor` is monotone, so `base <= erosion.at()` gives
`terraced(base) <= at()`, and the family invariant of §7.1 survives the quantisation in
terraced form:

```text
terraced(base_at(column)) <= at(column) <= erosion.at(column)
```

with `at()` never more than one terrace below the height it started from. The *unterraced*
base is no longer a lower bound, and that is honest rather than a regression: a column
sitting just above its base is pulled down past it, by less than one terrace. Rounding
would have raised ground as often as it lowered it and broken the family outright.

**The terrace planes are anchored to the datum.** `y = 0` is a terrace boundary (§6.1), so
every shelf in the world sits at a height a designer, a save file and a server can all
name. The negative side floors too, never truncates toward zero — truncation would put
voxel −1 and voxel 0 on the same shelf and mirror the staircase about the datum, which is
the same defect `GenerationGrid.floor_div()` exists to avoid one level down (§3.5).

**The output is discontinuous, on purpose.** This is the first pass for which
`max_step_per_voxel()` means nothing; §8.3 says what replaces it.

The range is §7's and §6's, unchanged: both ends are exact multiples of the terrace height
(`−96 = −12·8`, `+192 = 24·8`), so quantising maps the range into itself. That divisibility
is a property of 061's vertical anchors rather than of this file, so the test asserts it —
a later change to `OCEAN_FLOOR_VOXELS` or `LAND_BASE_VOXELS` must fail there instead of
silently pushing the world one terrace out of its own stated range. The minimum is now
*easier* to reach than before (any column within one terrace of the ocean floor lands
exactly on it); the maximum needs a column whose eroded height is exactly `MAXIMUM_VOXELS`,
so in practice the world's ceiling is one terrace below it.

`floor` and a power-of-two divisor are also a determinism decision, not only a design one:
`h / 8.0` is an exact exponent shift for every finite double and `floor` is exactly
specified by IEEE-754, so the whole pass is bit-identical on every platform — the same
argument §5.3 makes about the fade, applied to a division.

### 8.2 The terrace height was pinned by brick 061

`ElevationField.RELIEF_OCTAVES = 6` was chosen so the finest relief cell is 32 voxels =
16 m, **four times** the terrace height here (§6.4). Coarsen the terrace and 061's finest
octave is rounded away entirely — the detail it pays four hashes an octave for would never
reach the ground. The test asserts `finest_relief_cell == 4 · TERRACE_HEIGHT_VOXELS`
rather than the constant alone, so the two numbers cannot drift apart.

8 voxels is 4 m, roughly two player heights of shelf to shelf.

### 8.3 What replaces the step bound

```text
riser <= ceil(erosion.max_step_per_voxel() / H) · H
```

because `floor(a/H)` and `floor(b/H)` cannot differ by more than `ceil(|a − b|/H)` steps.
§7.4's bound is `2.627` voxels per voxel, comfortably under one terrace, so
`max_riser_voxels()` comes to exactly **one terrace, 8 voxels**: every riser in the world
is a single 4 m face and never a stacked cliff. That is what the terrace height is sized
for, and it is derived from the constants rather than hoped for — a future pass that
steepened the ground past one terrace per voxel would make this number grow and say so.

`test_the_riser_bound_is_a_real_constraint` quantises raw positional hashing over the same
amplitude and counts the terraces it skips, so the assertion is known to be capable of
failing.

### 8.4 The fixture-column variation check is 2, not 8

Every other Phase D pass asserts at least 8 distinct values over
`GenerationFixtures.columns()`. This one asserts 2, and that is the pass working rather
than a weakened check. Those 15 columns are deliberately *nearby* coordinates — the origin,
its neighbours, cell boundaries, the two region corners — chosen to catch sign and boundary
defects, not to sample the world. §7 answers 15 distinct heights there, but they span
barely 12 voxels, so quantising them lands on exactly two shelves (`+64` and `+56`).
Demanding 8 would demand the terrace be finer than the ground it measures.

The real variation check for this pass runs over the 2304-column sweep instead, and
demands a *populated span* of terraces rather than a count of distinct values.

### 8.5 What the pass measures

Over the same 2304-column sweep §5.5, §6.6 and §7.5 use, for the `typed` world:

| | before (§7.5) | after |
|---|---:|---:|
| lowest | `−95.7` | `−96.0` |
| highest | `+148.6` | `+144.0` |
| mean | `−5.1` | `−8.9` |
| columns above the datum | 49.8% | 49.8% |

It removes `3.9` voxels from the average column — half a terrace, which is what a floor
over a field with no preferred phase should remove — and never a whole one. The sweep
lands on **31 distinct terraces spanning indices −12…18**, i.e. every terrace in the span
is populated: the world uses its whole vertical range in shelves rather than clustering at
one end.

A kilometre walk across the origin (`z = 613`, the line §6.5 and §7.4 use) is now **1992
flat steps and 8 risers**, every riser exactly one terrace. The same line under §7 had zero
flat steps — every one of its 2000 columns differed from its neighbour. That contrast is
the brick: the ground stopped being a curve and became a floor you can stand on.

### 8.6 There is no reference claim behind this

`docs/reference/terrain-base-height-field.md` records nothing about vertical quantisation —
its claims are about how the original stacked noise tiers onto a base and which post-passes
scaled them (§3, claims 2–6). Terracing is therefore **original design** within the pass
shape §7.1 established, motivated by the target look rather than by recovered behavior, and
`docs/reference/traceability.md`'s `061–063` row should be read as covering the height field
underneath it and not this quantisation. Nothing here is asserted about what the original
did.

### 8.7 This is not a generation version bump

§2.1's honest test is "would a cell an existing world has not reached yet still come out
the same". `TerracePass` adds a new pass; it changes no constant, no salt, no hash and no
existing field — `ErosionPass.at()` answers exactly what it answered before, and its pinned
signature is unchanged. No world has ever had a voxel written from any of these fields
(§8.8), so there is no world whose terrain this could contradict. `GENERATION_VERSION`
stays where it is.

That stops being true the moment a generator writes voxels from this chain. From then on a
change to `TERRACE_HEIGHT_VOXELS` is a bump like any other pinned constant.

### 8.8 Out of scope for this brick

- **Sea level and water.** Still brick 080, and now with a terraced sea floor to put a
  waterline against — a flat shelf under water is a beach or a shallow, which is a better
  starting point for 083/084 than a continuous slope was.
- **Rivers, roads, structure flattening.** Bricks 080–083, 089–090. They belong to §7.1's
  product, i.e. **underneath** this pass: shape the continuous height, then terrace it. A
  flattening term applied after quantisation would produce heights that are not terrace
  planes, and every consumer of `surface_y()` would have to re-snap them.
- **Varying the terrace height per place.** A biome-dependent or ruggedness-dependent
  terrace would need the terrace planes to stop lining up between neighbouring columns,
  which turns a single riser into an arbitrary cliff and voids §8.3. If it is ever wanted,
  it is a brick with its own bound, not a constant swapped for a field.
- **Noise on the terrace edges.** The contour a riser follows is exactly a contour of §7's
  continuous field. Perturbing it would need a new salt and a new field, and the brick's
  own sizing note says a terrace needs neither.
- **Materials, and which block a shelf is made of.** Bricks 075–076. This pass says where
  the surface is, never what it is.
- **Any voxel.** Still nothing is written to a `VoxelBuffer`. `surface_y()` is the integer
  plane a generator will fill up to, and the generator is a later brick.

## 9. The temperature field (brick 064)

Implementation: `world/generation/temperature_field.gd` (`TemperatureField`).
Tests: `tests/unit/test_temperature_field.gd`.
Reference: `docs/reference/terrain-climate-blend.md`.

§5–§8 answer *where the ground is*. This is the first field that answers *what kind of
place this is* — one number per column, `0.0` the coldest place in the world and `1.0` the
hottest, with no unit in between. It classifies nothing on its own: which value is a desert
and which is a snowfield is brick 066's job, and brick 067's catalog. Brick 065 mirrors it
for humidity, and 066 reads both plus `ErosionPass.ruggedness_noise_at()`.

### 9.1 The whole field

```text
at(column) = fade( noise01(column) )
```

| Constant | Value | Why |
|---|---|---|
| `CELL_SIZE_VOXELS` | `16384` = 8192 m | `Continentalness.CELL_SIZE_VOXELS * 2` — see §9.2 |
| `OCTAVES` | `2` | so the finest cell is 8192 voxels, exactly the coarsest cell of every field under it — §9.2 |
| `GAIN` | `0.5` | the conventional half; the field stays dominated by its coarsest layer |
| salt | `WorldHash.SALT_TEMPERATURE` = `2` | already in `docs/rng.md` §4's list, appended long before it was used and used by nothing else. Nothing is appended by this brick |
| curve | `ValueNoise.fade()` | as a **redistribution**, not a blend — §9.4 |

Range `[0, 1]`, closed at both ends: `fade()` fixes `0` and `1`, and the layer's own range
is closed, so both are reachable rather than approached.

### 9.2 Climate is the coarsest field in the world

Every Phase D field so far has been sized against the one below it, and this one is sized
against all of them at once:

| Field | Coarsest cell | Finest cell |
|---|---:|---:|
| `TemperatureField` | 16384 | **8192** |
| `Continentalness` (§5.5) | **8192** | 1024 |
| `ErosionPass` ruggedness (§7.3) | **8192** | 2048 |
| `ElevationField` relief (§6.4) | **1024** | 32 |

The finest climate octave is exactly the coarsest cell of the two fields under it, which is
§6.4's "meet, don't overlap" rule applied one level up: climate carries every scale coarser
than a continent and no scale finer. A third octave would put climate detail at 4096 voxels
— a two-kilometre cold patch *inside* a landmass, which reads as noise rather than as
climate and which brick 074's blending would then have to smooth back out.

The ordering is the original's, not a preference. Its climate is blended over a window of
region sites `0x4000` units across, while its coarsest relief tier has a period of about
5000 units and the weight fields that *place* that relief about 10000
(`terrain-climate-blend.md` §3 claim 1, `terrain-base-height-field.md` §3 claims 1 and 3):
climate sits roughly one and a half times above the coarsest thing beneath it. Ours sits
exactly twice above it, because powers of two are a determinism requirement here (§5.2).

### 9.3 Climate does not read elevation, and that is a finding

Brick 061 left `terrain-base-height-field.md` `U2` open: does climate ride on the same
squared weight fields that place the relief tiers? Brick 064 read the two functions that
produce it — `World_temperatureBlend` and `World_humidityBlend` — and the answer is **no**.
The original blends stored per-region climate values over a nearest-site window and samples
no noise for the value at all. The one thing climate and elevation share is the ±768-unit
noise that jitters the region sites, which moves where a boundary falls and never what the
value is.

That closes `U2` and **contradicts** claim 7 of `terrain-base-height-field.md`, which had
guessed the opposite; the claim is struck through there rather than deleted
(`confidence.md` §4). Three consequences land in this section:

1. **Temperature is its own axis**, with its own salt and its own layer, and the test
   measures the consequence rather than trusting the design: `|r| < 0.05` against both
   `ErosionPass.at()` and `Continentalness.at()` over the standard 2304-column sweep
   (measured `+0.007` and `−0.006`).
2. **No lapse rate.** Cold mountain tops are brick 085's snowline reading this field *and*
   a height, not a term baked in here. Baking it in would make every high place cold in
   every world, which is a decision 085 should be free to make differently.
3. **No unit.** The original reads its climate straight off a `[0, 1]` scale against bare
   literals (`> 0.8`, `< 0.2`), and a degree scale here would be a number this project
   could not check against anything.

We also do **not** take two things the reference does: its weight function collapses to a
near-hard Voronoi edge between region sites (`terrain-climate-blend.md` §3 claim 3), and
its temperature has a post-pass that warms cold ground near a structure (claim 6). The
first is brick 074's decision to make, not a property to bake into the field; the second
belongs with structures, at 089–090.

### 9.4 The curve is a redistribution, not a blend

A sum of noise octaves is a sum of near-independent terms, so its values cluster around the
middle of its range. Measured over the standard sweep, the raw layer puts **69.8%** of its
columns in the middle four deciles and reaches neither end (`0.016 .. 0.983`). A climate
field shaped like that has no deserts and no snowfields whatever thresholds brick 066
picks, because the columns those thresholds would select do not exist.

`spread()` is `ValueNoise.fade()`, and the shape that makes it a good *blend* is exactly
what makes it a good *spread*:

- `fade'(0.5) = 1.875` pulls the crowded middle apart;
- `fade'(0) = fade'(1) = 0` pushes the sparse tails out to the ends;
- it is monotone with fixed points at `0` and `1`, so the ordering of any two columns and
  the stated range both survive it untouched.

Reusing the project's one blending polynomial rather than writing a curve here also keeps
§5.3's promise: one polynomial, one `FADE_MAX_SLOPE` to keep it in step with, no `pow()`
and no `cos()` anywhere near a generated world.

The step bound follows directly: `max_step_per_voxel() = FADE_MAX_SLOPE ·
noise.max_slope01_per_voxel()` = `0.000286`, and `minimum_climate_span_voxels()` — its
reciprocal, **3495 voxels = 1.75 km** — is the number a design conversation actually wants.
It is a lower bound on how far apart the coldest and the hottest column can be, and it is
what makes "you walk into a climate" checkable rather than intended.

### 9.5 What the field measures

> **Corrected by brick 065 (§10.4).** The numbers below were measured on the 2304-column
> sweep §6.6, §7.5 and §8.5 use — a spacing of 4093 voxels, a quarter of one climate cell,
> so about **144 independent climate cells** — on the `typed` world alone. They are what
> that sweep says, and that sweep cannot resolve this field: three of the four fixture
> worlds fail the decile band stated here, and the "almost flat" reading is an artifact of
> a sample too small to find the field's tails. §10.4 has the corrected measurement, on a
> climate-scale sweep and on every fixture world. Kept rather than deleted, per
> `docs/reference/confidence.md` §4: the conclusion of the section — that the raw layer
> crowds its middle and that one application of the curve fixes it — survives the
> correction, and only the shape of the fixed distribution changes.

Over the 2304-column sweep, in tenths of the range:

| | 0–.1 | .1–.2 | .2–.3 | .3–.4 | .4–.5 | .5–.6 | .6–.7 | .7–.8 | .8–.9 | .9–1 | sd |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| raw layer | 0.3 | 3.7 | 8.1 | 16.3 | 19.0 | 17.9 | 16.6 | 13.0 | 4.3 | 0.8 | 0.181 |
| `at()` | 7.3 | 7.9 | 11.0 | 10.6 | 10.6 | 9.4 | 10.3 | 11.0 | 11.2 | 10.8 | **0.280** |

~~A uniform field has a standard deviation of `1/sqrt(12)` = `0.289`, so one application of
the curve takes the field from visibly peaked to almost flat~~ — see §10.4; the field is
mildly **U-shaped**, at sd `0.316`, and the sweep above understates its tails. The test
pins the property rather than the histogram: no decile of the range holds a negligible or a
dominating share of the world, which is what brick 066 needs in order for a threshold
anywhere in the range to select a real share of it.

One application, not two, and no linear stretch first. Both were measured, and both
overshoot: `fade(fade(x))` puts 20.6% of the world in the bottom decile and 27.0% in the
top (27–31% on the corrected sweep), i.e. a **bimodal** climate with a fifth of the map
pinned at each extreme and the temperate middle emptied out. Three octaves instead of two
also measurably peaks the histogram (4.9% in the bottom decile against 7.3%), because a
narrower raw distribution gives the curve less to work with.

Walking, on a 400 km east–west line at `z = 613` sampled every 50 voxels: the **worst**
kilometre anywhere on it moves the temperature by `0.301` — a real gradient, comfortably
inside the derived bound of `0.572` per kilometre — while the line as a whole spans
`0.011 .. 0.999`. Gentle everywhere, and still a world with both ends in it: that pair is
the brick.

### 9.6 This is not a generation version bump

§8.7's argument, unchanged. `TemperatureField` adds a new field: it changes no constant, no
hash and no existing layer, it appends no salt (`SALT_TEMPERATURE` has been in
`docs/rng.md` §4's list since brick 015 and had no user), and every pinned signature below
it — `Continentalness`, `ElevationField` `0babd0a337dd7cab`, `ErosionPass`
`cc4f0f5ecb8fa581`, `TerracePass` `2af464f70e43590a` — is untouched and still asserted. No
world has ever had a voxel written from any of this. `GENERATION_VERSION` stays where it
is.

### 9.7 Out of scope for this brick

- **Humidity.** Brick 065 — **done**, §10. It landed with the same constants, measured
  rather than assumed, in its own file with its own salt (`SALT_HUMIDITY`). The two were
  not factored into a shared base class: see §10.5.
- **Biome classification and the catalog.** Bricks 066–067. This field says how warm a
  column is and nothing about what grows there — the same separation §5.5 keeps between
  continentalness and the coastline.
- **Biome transition blending.** Brick 074. The field is continuous and `C²`; whether a
  biome boundary is a blend or a hard line is that brick's decision, and §9.3 says why the
  reference's hard edge was deliberately not imported.
- **A lapse rate, and the snowline.** Brick 085, reading this field and a height. See §9.3.
- **Latitude.** There is none, in the reference or here: climate is a noise field over a
  flat world, not a band structure. If a world with poles is ever wanted it is a term added
  to this field with its own brick and its own version bump.
- **The structure warming pass** (`terrain-climate-blend.md` §3 claim 6). Bricks 089–090.
- **Any voxel.** Still nothing is written to a `VoxelBuffer`.

## 10. The humidity field (brick 065)

Implementation: `world/generation/humidity_field.gd` (`HumidityField`).
Tests: `tests/unit/test_humidity_field.gd`.
Reference: `docs/reference/terrain-climate-blend.md`.

The second climate axis, and 064's mirror: one number per column, `0.0` the driest place in
the world and `1.0` the wettest, with no unit in between. It classifies nothing on its own.
Together with §9 it completes the pair brick 066 will classify on.

```text
at(column) = fade( noise01(column) )
```

| Constant | Value | Same as §9? |
|---|---|---|
| `CELL_SIZE_VOXELS` | `16384` = 8192 m | yes — written as `TemperatureField.CELL_SIZE_VOXELS` |
| `OCTAVES` | `2` | yes |
| `GAIN` | `0.5` | yes |
| salt | `WorldHash.SALT_HUMIDITY` = `3` | **no**, and that is the whole difference |
| curve | `TemperatureField.spread()` | yes, by call rather than by copy |

Nothing is appended to `docs/rng.md` §4's salt list: `SALT_HUMIDITY` has been in it since
brick 015 with no user, and this is its user.

### 10.1 The brick is three decisions, and all three were "no"

`nextsteps.md` handed 065 three open questions. The answers, in the order they were asked:

1. **Are its constants really 064's?** Yes — but re-measured on its own layer rather than
   inherited on the argument that the distribution transfers (§10.2). The measurement is
   what made the answer worth something: it also corrected §9.5.
2. **Should humidity read `Continentalness`?** No. Real coasts are wetter than continental
   interiors, and it is a tempting term — but the reference offers no support for it
   (`terrain-climate-blend.md` claim 1: humidity is the same per-region blend temperature
   is, with no continentalness term), and taking it would make humidity the first climate
   axis derived from another field, which §9.3 spent a full reference read establishing
   climate is not. A coastal-wetness term is a decision brick 066 or 074 can still make,
   *visibly*, on top of two independent axes; baked in here it would be invisible and
   unremovable. The test measures the consequence: `|r| < 0.05` against `Continentalness`
   on every fixture world.
3. **Do the two axes get factored into a shared base class?** No — §9.7's rule, and §10.5
   says what was coupled instead and why that is not the same thing.

`terrain-climate-blend.md` `U1` — which region field the original's humidity actually
blends, lost with its value accumulator — was checked before designing and **does not gate
this brick**: our humidity is a noise layer, not a region blend, so which word of a region
record the original read cannot change anything here. It stays open for 089–090.

### 10.2 The constants were re-measured, not inherited

Run on the layer at `SALT_HUMIDITY`, over the climate-scale sweep of §10.4, on 12 seeds and
both climate salts (24 layers):

| | end deciles | middle four deciles | sd | span |
|---|---:|---:|---:|---|
| raw layer | `0.018 .. 0.028` each | `0.577 .. 0.609` | `0.212 .. 0.218` | reaches both ends on ~0.1% of columns |
| `at()` | `0.0713 .. 0.1584` (every decile) | — | `0.312 .. 0.320` | `0.0000 .. 1.0000` |

So the answer to "does 064's distribution transfer" is yes, and the two axes are
statistically the same field with different values — which is exactly what the reference
describes (`terrain-climate-blend.md` `INV-3`: same window, same warp, same weight, a
different region word).

The alternatives fail the same way they failed for temperature, and the wider sweep makes
the failure sharper: **no curve** leaves under 3% of the world in each end decile, so brick
066 could put a desert threshold nowhere; **two applications** puts 27–31% in each end
decile, a bimodal climate with the temperate middle emptied out. One application it is.

One thing the wider sweep changed: the field is **not** near-uniform. Every decile holds
between 7% and 16% of the world, with the ends the fattest — a mild U, at sd `0.316`
against a uniform field's `0.289`. `fade()` moves mass outward from the middle faster than
it thins the middle, and over 4096 independent cells the tails are populated enough to see.
That is a better climate field than a flat one, not a worse one: the extremes brick 066
needs are the ones that are hardest to reach.

### 10.3 Independence is the property, and it is measured on every axis

Two climate axes are only worth two fields if they are independent — otherwise the world has
a line through the climate square rather than the square itself, and half the catalog brick
067 writes describes places that do not exist. Measured over the climate-scale sweep, on all
four fixture worlds:

| Pair | worst `abs(r)` |
|---|---:|
| humidity x temperature | `0.023` |
| humidity x ground height (`ErosionPass`) | `0.021` |
| humidity x continentalness | `0.013` |

And the same statement in the form 066 will use it, over a 4x4 grid of the climate square on
12 seeds: **every one of the 16 cells holds between 3.9% and 9.3% of the world**, against an
even 6.25%. The corners — hot desert, hot swamp, cold desert, tundra — are the fattest cells
rather than the empty ones, because both axes are U-shaped. On a single 800 km line the two
axes are `0.94` apart at their widest: a hot desert is a place a player can walk to, not an
average of two middling fields.

### 10.4 The sweep was wrong, and that is 065's finding

Every Phase D field before this one is measured on a 2304-column sweep at a spacing of 4093
voxels (§6.6, §7.5, §8.5, and §9.5). For a relief field, whose coarsest cell is 1024 voxels,
that is four independent samples per cell and an excellent instrument. For a **climate**
field, whose coarsest cell is 16384 voxels, it is a quarter of one cell: those 2304 columns
are about **144 independent climate cells**, and everything measured on them moves by more
than the thing being measured when the seed changes.

The evidence, all on that sweep:

| Measurement | `zero` | `typed` | `numeric` | `negative` |
|---|---:|---:|---:|---:|
| temperature, smallest decile | 0.045 | **0.072** | 0.037 | 0.043 |
| temperature, sd | 0.262 | **0.280** | 0.251 | 0.260 |
| `r`(humidity, temperature) | −0.042 | **−0.148** | −0.126 | +0.019 |
| `r`(temperature, ground) | +0.016 | **+0.008** | +0.077 | −0.029 |

§9.5's test asserted `0.05 <= decile <= 0.16` and `sd > 0.26` on the `typed` column alone.
Three of the four worlds fail it. And a correlation of `−0.148` between two fields that
share no salt, no lattice offset and no term is not a coupling — it is the standard error of
a correlation over ~144 independent samples, which is about `0.08`.

The correction, and it is a test and documentation correction only — no constant, hash, salt
or field changed, and `TemperatureField`'s signature `fb91406f3e801b7f` is the one 064
pinned:

- a **climate-scale sweep** — 64 x 64 columns at a spacing of `16381` voxels from `−524192`,
  spanning 1032003 of the world's 1048576 voxels on each axis and staying inside
  `WorldBounds` at both ends. 16381 is prime and just under the cell edge, so consecutive
  samples walk the phase of the lattice rather than landing on the same corner of every
  cell;
- every distributional and correlational test in **both** climate files runs on it, and on
  **all four fixture worlds** rather than one;
- the bands are the 24-layer measurement with room for seed variance: every decile in
  `[0.055, 0.18]`, sd in `[0.30, 0.33]`, every joint 4x4 cell in `[0.03, 0.11]`. They still
  catch both ways the curve can be got wrong, by a factor of about two at each end.

One claim did not survive the wider sweep and was withdrawn rather than re-tuned. §9.5 said
the raw layer "reaches neither end" (`0.016 .. 0.983`); over 4096 cells it reaches
`0.004 .. 0.994`. Reaching an end on 0.1% of the world is not the same as having a decile
there, so the assertion is now distributional — each end decile under 3% — which is both
true and the thing that actually mattered.

The general rule, for brick 066 and everything after it: **a field is measured at its own
scale.** A sweep whose spacing is a fraction of the coarsest cell of the field under test
measures the same cell repeatedly and reports the result as if it were a sample of the
world. The fine sweep is still the right instrument for §6–§8; it is the wrong one here.

### 10.5 What was coupled, and why it is not a base class

§9.7 said the two axes stay two files, and they do. But three lines of this file name
`TemperatureField`, and the distinction is worth stating:

| Coupled | Not coupled |
|---|---|
| `CELL_SIZE_VOXELS`, `OCTAVES` and `GAIN` are written as `TemperatureField`'s, so the two axes cannot silently end up at different scales | either file may change its own line; the test asserts the equality, so such a change is answered rather than absorbed |
| `spread()` calls `TemperatureField.spread()`, so the redistribution *decision* has one home | neither field inherits from the other; there is no shared constructor, no shared configuration and no third class |

The difference between this and a base class is what happens when brick 066 wants to retune
one axis. Here that is a one-line edit in one file, and a test failure that asks whether the
other axis meant to follow. With a `ClimateField(cell, octaves, gain, salt)` base it is a
new configuration argument, a decision about defaults, and two callers to re-check — and
brick 066 is the first code that will actually see both users, so it is the brick entitled
to make that call.

### 10.6 This is not a generation version bump

§9.6's argument, unchanged. `HumidityField` adds a new field: it changes no constant, no
hash and no existing layer, it appends no salt, and every pinned signature below it —
`Continentalness`, `ElevationField` `0babd0a337dd7cab`, `ErosionPass` `cc4f0f5ecb8fa581`,
`TerracePass` `2af464f70e43590a`, `TemperatureField` `fb91406f3e801b7f` — is untouched and
still asserted. The §10.4 correction touches test files and this document only. No world has
ever had a voxel written from any of this. `GENERATION_VERSION` stays where it is.

### 10.7 Out of scope for this brick

- **Biome classification and the catalog.** Bricks 066–067. This field says how wet a column
  is and nothing about what grows there.
- **Coastal wetness.** §10.1, decision 2: available to 066 or 074 on top of two independent
  axes, deliberately not baked in here.
- **Rain shadow.** The same argument as the lapse rate (§9.3): it would couple humidity to a
  height, and it belongs to whichever brick owns mountains and weather together, not to the
  field.
- **Biome transition blending.** Brick 074, reading both axes.
- **Factoring the two climate axes.** Brick 066's call. §10.5.
- **Rainfall in millimetres, or any unit.** §9.3's reasoning, applied to this axis.
- **Any voxel.** Still nothing is written to a `VoxelBuffer`.

## 11. The biome classifier (brick 066)

Implementation: `world/biomes/biome_classifier.gd` (`BiomeClassifier`).
Tests: `tests/unit/test_biome_classifier.gd`.
Reference: `docs/reference/terrain-climate-blend.md` claim 5.

The first Phase D pass whose answer is an **id** rather than a number, and the first
consumer of both climate axes at once. One stable ID per column, always one of six, and
nothing about what that biome contains: the catalog is brick 067 and the per-biome content
is 068–073.

```text
at(column) = classify( temperature.at(column),
                       humidity.at(column),
                       erosion.ruggedness_noise_at(column) )
```

### 11.1 The partition

A **decision list**: the first rule that matches wins, the last one matches everything.

| # | Rule | Id |
|---|---|---|
| 1 | `ruggedness >= RUGGEDNESS_MOUNTAIN` | `biome.mountain` |
| 2 | `temperature < TEMPERATURE_COLD` | `biome.snow` |
| 3 | `humidity < HUMIDITY_ARID` | `biome.desert` |
| 4 | `humidity >= HUMIDITY_WETLAND` | `biome.wetland` |
| 5 | `humidity >= HUMIDITY_WOODED` | `biome.forest` |
| 6 | — | `biome.grassland` |

Totality is structural rather than checked: there is no input the list does not answer, so
`GenerationFixtures.range_reason()` — which every field before this owed — has no meaning
here, and `test_answers_only_with_ids_it_declares` is what replaces it. The digest still
applies, and it is type-strict, so a classifier that started answering with an index rather
than an id fails the pin instead of quietly re-keying every consumer.

Every cut is **half-open at the low end**: `<` for a low cut, `>=` for a high one, so a
column sitting exactly on a threshold belongs to the upper region. `HUMIDITY_ARID` and
`HUMIDITY_WETLAND` are exact binary fractions and columns really do land on them, so this
is asserted rather than left to chance.

Six ids, under the `biome` domain of `core/ids/stable_id.gd` — a biome id reaches a save
file and a log, so it obeys the same grammar as an item or a block id. `biome.wetland` is
named for the *climate*, not for water: nothing here knows where the water is, and an
aquatic biome (open sea, lake bed) is a height decision that belongs with the waterline in
brick 080.

### 11.2 Where the five thresholds come from

None of the five was fitted to a target share. Three come from the reference, one is a
field's own middle, and one is derived from the pass it reads.

| Threshold | Value | Anchor |
|---|---:|---|
| `TEMPERATURE_COLD` | `0.2` | the reference's own literal (`terrain-climate-blend.md` claim 5: the original reads climate on a bare `[0, 1]` scale against `< 0.2` and `> 0.8`) |
| `HUMIDITY_WETLAND` | `0.8` | the same claim's other literal — humidity `> 0.8` gates a second lookup in `World_generateRegionSite` |
| `HUMIDITY_ARID` | `0.2` | written as `1 - HUMIDITY_WETLAND`: the dry mirror of that literal, so both ends of the axis are cut at the same distance from it |
| `HUMIDITY_WOODED` | `0.5` | the field's own middle, `ElevationField.SHORE_MIDPOINT`'s neutral choice. `HumidityField.spread()` fixes `0.5`, so this cuts the temperate band in half |
| `RUGGEDNESS_MOUNTAIN` | `1/sqrt(2)` | **derived**: the ruggedness at which `ErosionPass.ruggedness_weight()` reaches the middle of its own range |

The last one is the one worth reading twice. `ruggedness_weight(r)` is
`RUGGEDNESS_FLOOR + (1 - RUGGEDNESS_FLOOR) * r²` — how much of its 128-voxel relief
amplitude a column keeps — and its midpoint sits at `r² = 0.5`. So rule 1 reads *"a column
that keeps more than half the relief in the world is a mountain"*, which is a claim about
the ground a player walks on rather than about a noise value, and it moves with
`ErosionPass` if that pass is ever retuned. The test asserts the identity, not the number.

It reads the **raw** ruggedness layer rather than `ruggedness_at()`: squaring is monotone,
so both give the same partition, and the raw field keeps the threshold on the scale the
number is quoted on. That is also why brick 062 left `ruggedness_noise_at()` public and
unsquared.

We cannot reuse the original's climate *mechanism* — it blends stored per-region values and
ours is a noise layer (§9.3) — but the scale it reads the result on is exactly ours, and
its two literals are the one piece of its classification that survived the read. Taking
them is a cheaper and more defensible decision than inventing two numbers.

### 11.3 The order of the rules is part of the design

Two places in the order carry as much as the numbers do:

- **Relief outranks climate.** A column rugged enough to be a mountain is a mountain in any
  weather, because relief is the one input a player can see from a distance. A hot mountain
  and a cold one are 072's problem and 067 can still split the id; a mountain classified as
  a swamp because it happens to be wet is a bug you can walk into.
  `test_relief_outranks_climate` asserts it over the whole climate square, not at one point.
- **Cold outranks dry and wet.** Cold-and-dry is tundra and cold-and-wet is taiga; with six
  baseline biomes and one of them named `snow`, both of those are the snow biome. Putting
  the cold test above the humidity tests says so in one line, rather than three extra
  thresholds saying it less clearly.

### 11.4 What the classifier measures

On the climate-scale sweep of §10.4 — 64 x 64 columns at a spacing of `16381` voxels from
`−524192` — the six shares, over 12 seeds:

| Biome | share of the world |
|---|---|
| `biome.snow` | `0.1941 .. 0.2102` |
| `biome.grassland` | `0.1597 .. 0.1775` |
| `biome.forest` | `0.1572 .. 0.1775` |
| `biome.desert` | `0.1465 .. 0.1628` |
| `biome.wetland` | `0.1479 .. 0.1589` |
| `biome.mountain` | `0.1426 .. 0.1616` |

Against an even sixth, `0.1667`. **That evenness was not aimed at**, and it is the most
interesting measurement of the brick: it is inherited from §10.2's distribution. `spread()`
leaves each climate axis with about a quarter of the world below `0.2` and a quarter above
`0.8`, so cutting an axis at `0.2 / 0.5 / 0.8` cuts it into four near-equal parts; and
`1/sqrt(2)` on the ruggedness layer happens to take about a seventh. Six rules over two
quartered axes and one tail land within a factor of `1.5` of each other without a single
constant chosen for balance. The test bands are `[0.12, 0.24]` — room for seed variance,
still far tighter than what a re-ordered rule does.

The sweep is the right instrument here for 065's reason (§10.4): a classifier is a climate
consumer, and the 2304-column sweep the relief tests use resolves a 16384-voxel field only
about 144 times. `test_the_sweep_is_wide_enough_to_measure_a_climate` carries that forward
as geometry.

One more measurement, and it is the mechanism behind the table: **mountains are not a
climate.** Ruggedness shares no salt and no term with either climate axis, so the mountains
of a world are as cold as the world is — the share of mountain columns below
`TEMPERATURE_COLD` is asserted inside `[0.15, 0.35]` against a world that is cold on about
`0.24` of its columns. If a later edit derived ruggedness from temperature, or classified
on a height (which follows continentalness), that is where it shows up, before it shows up
as every mountain in the world being snow-capped.

### 11.5 A biome is a place, and the slivers are real

On the 800 km line of §10.4 at `z = 613`, on all four fixture worlds: **123–131 runs**, mean
run length **3.05 – 3.25 km**, and all six biomes present on every line. That is the
consequence of classifying fields whose cells are kilometres wide — a biome is somewhere a
player spends minutes, not a texture that changes every few steps.

The honest half: the **shortest** run on those lines is `0.025 – 0.125 km`. A threshold on a
continuous field always produces the occasional sliver where the line grazes a boundary, and
no choice of constants removes them. So the test asserts the **mean**, not a floor: a
minimum-run assertion would be a test of where the line happens to be rather than of the
classifier. Smoothing the boundaries is brick 074's job, and this is the measurement it
inherits.

`minimum_climate_band_voxels()` is the derived floor on the *climatic* boundaries only:
either climate axis needs at least `minimum_climate_span_voxels()` = 3495 voxels to cross
its whole range (§10), and the closest two cuts on one axis are `0.3` apart, so a purely
climatic band is at least `1048` voxels = **524 m** wide. A floor on band width, not a
promise about the map — the mountain rule reads a field eight times finer and cuts across
climate bands freely.

### 11.6 What it refuses to read, and why

- **`Continentalness`, and so coastal wetness.** Brick 065 left a coastal-wetness term to
  066 or 074 on the condition that it be visible rather than baked into the humidity axis
  (§10.1, decision 2). 066 declines it too, for a reason of its own: a coast is a place you
  can only *see* once there is water in it, and the waterline is brick 080. A `biome.coast`
  drawn on continentalness alone would put a biome boundary where nothing on the ground
  changes. The decision stays open, and it stays cheap — the classifier reads three
  `[0, 1]` inputs and a fourth is one rule and one field.
- **Ground height, and so sea level.** The same argument and the same brick. `ErosionPass`
  is held for its ruggedness layer; the classifier never calls its `at()`. Brick 072's
  mountain biome and 080's waterline are where a height enters the picture.
- **A rain shadow, and a lapse rate.** §9.3 and §10.7, unchanged: both couple a climate axis
  to a height, and both belong to the brick that owns mountains and weather together (085),
  not to a classifier.

### 11.7 The two climate axes stay two files — 065's open question, answered

§10.5 named brick 066 as the one entitled to decide whether `TemperatureField` and
`HumidityField` get factored into a shared base class, on the grounds that 066 is the first
code to see both users. It is, and the answer is **no** — now for a reason stronger than
"not yet".

The first consumer reads the two axes **by name**, not by iteration. `classify()` takes
`temperature` and `humidity` as separate parameters and treats them asymmetrically: one cut
on the temperature axis, three on the humidity axis, and an order between them that is the
design (§11.3). A common base type buys nothing at that call site — there is no loop over
climate axes to write, and nowhere the classifier would accept either field where it wants
the other. What §10.5 coupled instead (the three constants, and `spread()` by call) is
exactly what this file depends on, and it already holds.

### 11.8 This is not a generation version bump

§10.6's argument, unchanged. `BiomeClassifier` adds a new consumer: it changes no constant,
no hash and no existing field, it appends no salt, and every pinned signature below it —
`ElevationField` `0babd0a337dd7cab`, `ErosionPass` `cc4f0f5ecb8fa581`, `TerracePass`
`2af464f70e43590a`, `TemperatureField` `fb91406f3e801b7f`, `HumidityField`
`76802ec9aa907fee` — is untouched and still asserted. It pins one of its own,
`33a42963660cb452`, over `GenerationFixtures.columns()` on the `typed` world. No world has
ever had a voxel written from any of this. `GENERATION_VERSION` stays where it is.

Its own five thresholds join the pinned set from here on: they are part of every world made
with them, so retuning one once a world exists is a version bump, not a tuning knob (§2.1).

### 11.9 Out of scope for this brick

- **The biome catalog.** Brick 067. This file names six biomes and describes none of them.
- **Per-biome content** — surface blocks, vegetation, spawns. Bricks 068–073, 075–076,
  086–088.
- **Biome transition blending.** Brick 074, which is what §11.5's slivers are for.
- **A coastal or aquatic biome.** §11.6; it waits for the waterline (080).
- **Altitude, and a snowline.** Bricks 072 and 085.
- **Caves.** Bricks 077–078. A cave is currently in the biome of the column above it.
- **Any voxel.** Still nothing is written to a `VoxelBuffer`.

## 12. The baseline biome catalog (brick 067)

Implementation: `world/biomes/biome_definition.gd` (`BiomeDefinition`),
`world/biomes/biome_registry.gd` (`BiomeRegistry`), `world/biomes/biome_catalog.gd`
(`BiomeCatalog`), `data/biomes/*.tres`, written by
`tools/generators/generate_biome_catalog.gd`.
Tests: `tests/unit/test_biome_definition.gd`, `test_biome_registry.gd`,
`test_biome_catalog.gd`.
Reference: `docs/reference/matrix-world.md` §1 (`cube::WorldInfo`), §2 (biome content
population) — and see §12.5, which is a divergence rather than an implementation.

§11 gave six ids. This is the six **records** behind them, and the first Phase D brick that
is content rather than a field: no noise layer, no salt, no constant, nothing sampled at a
coordinate.

```text
data/biomes/*.tres  --BiomeCatalog.load_default()-->  locked BiomeRegistry
                                                       |
                              BiomeClassifier.at(column) -> id -> get_biome(id)
```

### 12.1 The classifier owns the set; the catalog is checked against it

`BiomeClassifier.IDS` is closed **in code** (§11.1), and 067 does not reopen it. The catalog
is the six records for those ids and nothing else, which makes the relationship between the
two files an equality that can be asserted rather than a convention:

| Direction | Failure | Where it is caught |
|---|---|---|
| a record for an id nothing can classify | dead content, usually a typo | `BiomeRegistry.register_biome()`, per entry |
| an id with no record | a world with columns that resolve to nothing | `BiomeRegistry.coverage_reason()`, once over the whole catalog |

The second is the one that matters and the one a per-entry check structurally cannot see.
`BlockSet` (038) has no equivalent because blocks are an **open** set — a registry holding
three or thirty is equally correct — and that difference is the whole reason `BiomeCatalog`
is its own loader rather than a second call into `BlockSet`'s.

`coverage_reason_for()` is the same comparison over a bare id list, and it exists so both
directions are reachable: a live registry can only ever be *short*, because
`register_biome()` refuses the other case, and a branch no test can reach is a branch
nobody has run.

### 12.2 Three fields, and the argument for stopping there

| Field | Is |
|---|---|
| `id` | the stable id, domain `biome` — permanent, reaches saves, logs and (as a network index) packets |
| `display_name` | tooling/UI label. Never a key |
| `debug_color` | a flat opaque colour for telling six biomes apart in a **debug** view |

Everything else one wants to write on a biome belongs to a brick that has not happened yet:
surface and subsurface materials are 075–076, vegetation and scatter 086–088, spawn tables
095 and 106–107, water and snowline 080 and 085, transition width 074. A field nothing fills
is worse than a record that grows, so the record is the three things all six entries can
fill today with nothing invented.

`debug_color` is explicitly **not** the terrain or vegetation tint. That is a shading
decision made from the surface material (075) and the renderer (Phase J); naming the field
for what it is for keeps the first chunk-tinting brick from silently adopting a palette
chosen for legibility on an overlay. `BiomeRegistry.palette_reason()` holds every pair at
least `MINIMUM_DEBUG_COLOR_DISTANCE` = `0.25` apart in RGB — a guard against two biomes
being handed the same swatch, not a colour-science claim. The shipped palette's closest pair
is grassland against mountain, at **0.28**.

### 12.3 It is a data catalog, and that was the decision to make

The alternative was a static table in code, and the closed set argues for it: six entries,
already named in `BiomeClassifier`. The data route wins on where 068–073 put their work.
Each of those bricks fills one biome, and a per-biome `.tres` is where content belongs
(`CLAUDE.md` §9); `data/biomes/` has existed and been empty since brick 005 waiting for
exactly this. It also gets locking, aliases, sorted network indices and `content_hash()`
from `DefinitionRegistry` (016) for free — and a biome id does reach the wire, so those are
not hypothetical.

`tools/generators/generate_biome_catalog.gd` writes the six files, the way
`generate_block_set.gd` wrote the first three blocks. It reads the set from
`BiomeClassifier.IDS` and **fails** on an id with no row, rather than quietly writing five
files; the catalog is then self-checked in the generator before it claims success, so the
drift `coverage_reason()` exists to catch is caught at authoring time as well as at load
time. It needs the thin-entry/runner split (`nextsteps.md`, brick 052) that
`generate_block_set.gd` avoids only because `BlockDefinition` happens to touch nothing.

### 12.4 What a load guarantees

`BiomeCatalog.load_default()` degrades per entry exactly as `BlockSet` does — a missing
directory, an unloadable file, a wrong resource type or a rejected definition is one logged
error, never a crash — and then runs `BiomeRegistry.self_check()` (coverage, then palette)
over the result and logs loudly if the catalog as a whole is unusable. It still **returns**
the registry rather than aborting: the caller decides, the same way `GenerationVersion`
hands back a verdict.

The registry comes back locked, always, including when nothing loaded. Network indices are
therefore assigned from the moment a catalog exists, in sorted id order, so two peers that
loaded the same six files agree without exchanging a table.

The end-to-end test is the one worth naming: the real classifier runs over every fixture
column of every fixture world and each answer is looked up in the real catalog. That asserts
coverage against actual classifications rather than against the id list.

### 12.5 The reference has no biome catalog, and that is the finding

Recorded because it is a **divergence**, not a gap. The reference has no biome enum, table
or record anywhere. Its notion of a biome is a *continuous colour* —
`Terrain_computeBiomeColor` (`GAP_ANALYSIS.md`, LOW) blends constants against
temperature/humidity/height noise into terrain and vegetation RGBA, and
`terrain_biomeColorFromNoise` does the same from two noise layers — plus a content-placement
routine, `WorldInfo_generateBiomeContent`, which populates spawns, terrain features and
decoration. Nothing in either binary names a biome and nothing looks one up.

`WorldInfo_generateBiomeContent` was opened (brick 067, targeted read) and closed again: it
is a decompiled placement routine with a ~6 KB stack frame, calling water/path feature
generators and a rotate-and-place helper, with no recoverable record structure. It is about
*content population*, which is 068+, 086–088 and 095 — not about what a biome record holds.
That resolves `matrix-world.md` §2's `067–068` row for 067's half.

So the discrete, addressable, catalogued biome is ours, deliberately. `CLAUDE.md` §9's
stable-id policy needs it, a save file and a quest condition need it, and §11 already
committed to it. The one idea taken from the reading is small and honest: the only per-biome
datum the original carries at all is a **colour**, and this catalog carries one too —
discrete, per-id and debug-only, where theirs is continuous and is the terrain itself.

### 12.6 This is not a generation version bump

Nothing here is generation. No hash, no noise layer, no salt, no threshold, no coordinate.
Every pinned signature below stands untouched and still asserted (`ElevationField`
`0babd0a337dd7cab`, `ErosionPass` `cc4f0f5ecb8fa581`, `TerracePass` `2af464f70e43590a`,
`TemperatureField` `fb91406f3e801b7f`, `HumidityField` `76802ec9aa907fee`,
`BiomeClassifier` `33a42963660cb452`). `GENERATION_VERSION` stays where it is.

Adding, removing or renaming a biome later is a different question, and it is a
`BiomeClassifier` question before it is a catalog one: the ids are the classifier's, and
changing the partition is what §11.8 already calls a version bump. A record's
`display_name` or `debug_color` is not — neither is an input to anything generated.

### 12.7 Out of scope for this brick

- **Per-biome content** — surface and subsurface blocks (075–076), vegetation and scatter
  (086–088), creature spawns (095, 106–107). Bricks 068–073 fill one biome each, and every
  field they need is added then, to a record that already exists.
- **Biome transition blending.** Brick 074, and §11.5's slivers are what it inherits.
- **Terrain and vegetation colour.** §12.2; Phase J, from 075's materials.
- **A coastal or aquatic biome.** §11.6, unchanged: it waits for the waterline (080).
- **Procedural region and place naming.** `matrix-world.md` Q4 asked whether the biome
  catalog owns it. It does not: a biome record names a *kind* of place, permanently and in
  six copies, where a region name names *one* place and is generated per world. It is a
  Phase J map/UI concern (229) or its own brick, and 067 declines it explicitly rather than
  leaving the question open.
- **Any voxel.** Still nothing is written to a `VoxelBuffer`.

## 13. Biome transition blending (brick 074)

Implementation: `world/biomes/biome_transition.gd` (`BiomeTransition`).
Tests: `tests/unit/test_biome_transition.gd`.
Reference: none — §13.5.

`BiomeClassifier.at()` (066) answers one id per column, always, with no notion of a border,
and it names its own future reader while doing it: `sample_at()`'s doc comment reads "for
brick 074, which needs the distance to a threshold rather than the side of it." This is that
brick — a second, presentation-facing question over the same three inputs, for 075's material
blend and Phase J's terrain tint. It never changes which biome a column is in.

```text
neighbor_at(column)        = the second id blending in, or "" past TRANSITION_WIDTH
neighbor_weight_at(column) = [0, 0.5], 0.5 exactly on a boundary, 0 at TRANSITION_WIDTH
```

### 13.1 068–073 are folded in here, not implemented separately

Before this brick could be written, it needed a decision the backlog itself did not settle:
`nextsteps.md` flagged, across bricks 065–067, that bricks 068–073 ("implement the grassland
biome" through "implement the aquatic/wet biome") each own **nothing** under the current
architecture. `BiomeDefinition` is deliberately three fields (§12.2), and every field one of
those six bricks would plausibly add — surface/subsurface material (075–076), vegetation and
scatter (086–088), spawn tables (095, 106–107), water and snowline (080, 085) — already
belongs to a later brick that does not exist yet. Filling a `BiomeDefinition` field six times
before anything reads it would be six bricks each adding a field nothing reads, which
`nextsteps.md` named directly as worse than the alternative it also named: fold the six into
whichever later brick actually needs the field, once it exists.

So 068–073 are marked folded in `backlog.md`, each pointing at the brick that will actually
add its content, and this brick — 074, next in the dependency chain and the one biome-related
task that genuinely owns new work today (`BiomeClassifier.sample_at()`'s own comment says so)
— is implemented now rather than waiting behind six empty bricks. This is a scope correction,
not scope creep: no field was invented to give 068–073 something to do, and 075 (surface
material selection) is still where a `BiomeDefinition` next grows, for all six entries in one
pass, exactly as `nextsteps.md` proposed.

### 13.2 Finding the neighbor: asking the real function

`classify()` is a **decision list**, not five independent range checks (§11.1, §11.3), so "the
nearest threshold" is not always the nearest *relevant* one. A column deep in `SNOW` (rule 2)
can sit close to `HUMIDITY_WOODED` (rule 5) in raw humidity terms, but rule 2 already returned
before rule 5 is ever tested — nudging humidity there changes nothing, because temperature is
what is holding the answer. Re-encoding the decision list's short-circuit precedence a second
time to know this in advance would be a second copy of `classify()` to keep in step with the
first.

`nearest_boundary()` does not re-encode it. For each of the five thresholds, it nudges that
one input to just the other side (`_flip_low()`/`_flip_high()`, a threshold-exact value or a
`FLIP_EPSILON` below it, whichever side is the "just crossed" one) and calls
`BiomeClassifier.classify()` again with the other two inputs untouched. A nudge that leaves
the answer unchanged is not a boundary this column is near, in the only sense that matters
here — the SNOW/WOODED case above computes exactly that, correctly, with no special case for
it. A nudge that changes the answer is exactly the neighbor 075 needs, and the smallest such
distance across all five thresholds wins. `test_the_neighbor_is_the_biome_just_past_the_
boundary` is the worked proof, including the case above (a cold column 0.05 from the mountain
cut has `MOUNTAIN` as its neighbor even though a humidity cut sits closer in id order — relief
outranks climate, §11.3, and the probe reproduces that ordering rather than assuming it).

Every one of the five thresholds changes `classify()`'s answer when nudged in isolation —
flipping ruggedness across `RUGGEDNESS_MOUNTAIN` always enters or leaves `MOUNTAIN`, and each
of the other four always changes which temperature or humidity rule matches — so
`nearest_boundary()` never actually returns empty. It still returns a dictionary and checks
rather than assumes: `test_a_boundary_always_exists` covers the claim over the whole unit
cube instead of trusting it.

### 13.3 The width: half the narrowest gap, one constant for three different axes

`TRANSITION_WIDTH = 0.15`, exactly half of `BiomeClassifier.narrowest_climate_gap()` (`0.3`,
§11.5 — the humidity axis's tightest cut spacing, `HUMIDITY_ARID` to `HUMIDITY_WOODED` or
`HUMIDITY_WOODED` to `HUMIDITY_WETLAND`). Half, not the whole gap, for the "coarser than what
it weights" reason a weight field owes the thing it modulates (§7.3, §6.4): a column exactly
at the midpoint of the *narrowest possible* climate band is `TRANSITION_WIDTH` from each
neighboring cut, so both blend zones fade to zero exactly there — they **meet**, at zero,
rather than overlapping into a three-way mix nothing asked for.
`test_the_two_sides_of_the_narrowest_band_meet_without_overlapping` is the exact case, at the
humidity band's own midpoint.

One constant covers all five thresholds, including the ruggedness cut — an honest
simplification, not an exact one. Temperature and humidity share a measured scale (`spread()`,
§9.4/§10.2) that the ruggedness cut does not derive its own width from at all: it is a single
threshold against a ceiling, not a gap between two cuts on its own axis (§11.2). Reusing the
climate width is the least invented number available, not a measured property of the
ruggedness layer. If the mountain edge ever needs a width of its own, that is 072's or 085's
call, once either exists to make it — not a reason to invent a second constant here for a case
nothing yet reads.

The weight curve is `ValueNoise.fade()`, the project's one blending curve (§5.3), applied to
`distance / TRANSITION_WIDTH` and folded so `0.5` sits at the boundary and `0.0` at the width —
reused rather than a second `C¹`-only ramp with a slope discontinuity of its own to keep in
step with `FADE_MAX_SLOPE`, the same reason §6.4 gives for the shore band.

### 13.4 What the width measures — and what it does not

Over the same dense 21³ grid `test_biome_classifier.gd` sweeps for totality, **73.5%** of the
unit cube sits within `TRANSITION_WIDTH` of some threshold. That number is large enough to be
worth stating plainly rather than tuning away: `HUMIDITY_ARID`, `HUMIDITY_WOODED` and
`HUMIDITY_WETLAND` sit exactly `2 · TRANSITION_WIDTH` apart, so their three blend zones tile
the humidity axis edge to edge from `0.05` to `0.95` — only the outer `0.05` at either end of
the humidity axis is ever purely one biome with respect to humidity alone.

**That is a property of the unit cube, not of the world**, and the two must not be conflated.
A climate field only ever visits the cube along an 8192-metre-per-cell path (§9.4); the number
that actually describes the *world* is §11.5's — a mean biome run of 3.05–3.25 km on an 800 km
line, measured by `test_a_biome_is_a_place_a_player_walks_across`. A column being
"mathematically close to a threshold" and a player being "near a biome edge" are related but
not identical claims, because the world only samples a vanishingly thin slice of the climate
cube at any resolution a player experiences it at. `test_most_of_the_climate_cube_is_within_
the_transition_width` pins the cube-level number so a future change to `TRANSITION_WIDTH`
that quietly merges two humidity cuts into one continuous smear — or narrows the width until
blending stops doing anything — fails there, without claiming anything about how often a
player actually sees a blend.

### 13.5 Reference: none

The original has no boundary to smooth, because it has no discrete biome to have one. §12.5
already found this reading `Terrain_computeBiomeColor`: the original blends
temperature/humidity/height noise straight into terrain and vegetation RGBA, continuously,
with no id anywhere to draw an edge between. There is no boundary-blending *mechanism* in
either binary to diverge from — only the same "continuous under the hood" property this
project arrives at from the opposite direction: a discrete id for everything that needs one
(saves, quests, logs, §12.5), and a blend weight for the one thing here that reads like the
original after all — a tint that does not jump.

### 13.6 This is not a generation version bump

§12.6's argument, unchanged, and stronger here than it was there: nothing in this brick is
generation. No hash, no salt, no noise layer, no new field is sampled — `nearest_boundary()`
reads the same three numbers `BiomeClassifier.sample_at()` already produces, a second way.
`BiomeClassifier.at()` is untouched and still asserted at its pinned signature
(`33a42963660cb452`), and nothing this file computes ever feeds back into anything that
decides where a voxel goes. `GENERATION_VERSION` stays where it is.

### 13.7 Out of scope for this brick

- **Per-biome content.** Still 075–076 (materials), 086–088 (vegetation), 095/106–107
  (spawns) — §13.1 folds 068–073 into whichever of those actually needs the field, it does
  not pull their content forward into this brick.
- **A width specific to the mountain edge.** §13.3; the shared constant is a simplification
  stated as one, not a claim that ruggedness and climate blend at the same true rate.
- **Blending the actual terrain colour or material.** Still Phase J and 075 — this brick
  produces the weight they would blend with, not the blend itself.
- **A coastal or aquatic biome, and its own edge.** §11.6, unchanged: waits for the
  waterline (080).

## 14. Surface material selection (brick 075)

Implementation: `world/generation/surface_material.gd` (`SurfaceMaterial`);
`BiomeDefinition.surface_block_id` (new field on the 067 schema);
`tools/generators/generate_surface_blocks.gd` (two new block kinds); updated
`tools/generators/biome_catalog_generator.gd` (all six records regenerated with the field
filled in). Tests: `tests/unit/test_surface_material.gd`;
`tests/unit/test_biome_definition.gd`, `test_biome_registry.gd` and `test_block_set.gd`
extended for the new field and the two new blocks.
Reference: none — §14.5, the same finding as §12.5 and §13.5.

§13's transition weight named its own future reader — "for 075's material blend" — three
times over. This is that brick: one block id per column, blended across a biome edge by
dithering rather than by a hard cut, because a `VoxelBlockyModel` cube cannot fade the way
a colour can.

```text
BiomeTransition.blend_at(column) -> {primary, neighbor, neighbor_weight}
        |
        +-- primary biome's BiomeDefinition.surface_block_id         -> the default answer
        +-- neighbor_weight > 0  ->  a per-column dithered roll        -> the blended answer
                (GenerationHash.value01_column(column, SALT_SURFACE_MATERIAL))
```

### 14.1 A dither, because blocky ground cannot blend

`neighbor_weight` is a continuous `[0, 0.5]` value; a block id is not continuous at all.
`SurfaceMaterial.block_id_at()` reads a deterministic per-column roll in `[0, 1)` and picks
the neighbor's block when the roll falls under the weight, the primary's otherwise. At
`neighbor_weight = 0` the roll can never win, so every column away from an edge is exactly
the primary — no different from no blend at all — and exactly on a boundary
(`neighbor_weight = 0.5`) the two blocks are chosen with even odds, so a band of columns
near an edge salt-and-peppers between them rather than snapping cleanly from one to the
other. This is the discrete-ground form of the "tint that does not jump" §13.5 already
named — the same property, produced by a coin flip instead of a blend because the medium
here cannot fade.

The roll carries its own salt, `WorldHash.SALT_SURFACE_MATERIAL`, appended rather than
borrowed from 074's or 066's — `WorldHash`'s own rule (one salt per pass, so two passes
near the same edge cannot correlate by accident, `docs/rng.md` §4).

### 14.2 The block mapping: two new kinds, not six

Only three block kinds existed before this brick (038: grass, dirt, stone) and six biomes
need six honest grounds. Rather than invent a new block for every biome — a field nothing
distinguishes is worse than a record that grows, applied here to blocks instead of a biome
schema field — four of the six reuse what already exists:

| Biome | Block | Why |
|---|---|---|
| `grassland` | `block.grass` | the reference case grass was authored for |
| `forest` | `block.grass` | still grassy ground between trees; canopy/litter is 086–088's vegetation, not a different ground block |
| `desert` | `block.sand` | **new** — no existing block is an honest desert floor |
| `snow` | `block.snow` | **new** — same reason, for a snowfield |
| `mountain` | `block.stone` | `RUGGEDNESS_MOUNTAIN` (066) already means "bare rock wins over relief"; the ground it describes already reads as stone |
| `wetland` | `block.dirt` | swamp/marsh ground is honestly mud, and `block.dirt` is that texture already |

`tools/generators/generate_surface_blocks.gd` writes the two new kinds with the same
speckled-placeholder-PNG technique `generate_block_set.gd` (038) used for the first three —
no Blender/bpy asset pass, matching the backlog row's own "Blender MCP: not needed by
default." `data/blocks/` now holds five records; `tests/unit/test_block_set.gd`'s counts
(`3` → `5`, `4` → `6` library models including the air placeholder) moved with it.

### 14.3 The cross-domain check `BiomeRegistry` deliberately does not own

`BiomeDefinition.surface_block_id` validates grammar and domain only
(`StableId.validate()`, domain `block`) — the same independence `id` itself already has
from `BiomeClassifier`'s partition, and the same reason `BlockDefinition.drop_item_id`
(033) checks grammar only. `BiomeRegistry` stays unaware of `BlockRegistry` by the same
logic it stays unaware of the classifier's own set at the schema layer: two different
domains, two different registries, no field elevated to know about a registry it does not
own. `nextsteps.md` asked whether `BiomeRegistry.self_check()`/`coverage_reason()` needed a
new coherence check for this field; the answer is no, because the check that matters is
cross-domain, and it lives where both domains actually meet.

That is `SurfaceMaterial.for_world()` and its static half,
`SurfaceMaterial.surface_block_reason_for(biomes, blocks)` — the same shape as
`BiomeRegistry.coverage_reason_for()`: static and taking both registries so the failing
branch is reachable by a test or a content tool, not just by a live catalog that
`register_biome()` already kept clean one entry at a time. `for_world()` refuses to build
(logged, not a crash) when either registry is unlocked, when the biome registry fails its
own `self_check()`, or when any `surface_block_id` names a block the block registry has no
record for — a typo here is the same shape of "broken world" bug 067 and 074 already
guard against, just one domain over.

### 14.4 Not a generation version bump — and where that stops being free

§12.6's and §13.6's argument, and the last brick that gets to make it for free: **no world
has ever had a voxel written from any Phase D pass**, so nothing this brick computes can
contradict a world a player has already explored. `BiomeTransition.neighbor_weight_at()` is
unchanged; the new pieces are `BiomeDefinition.surface_block_id` (a record field — §12.6's
own stated exception) and `WorldHash.SALT_SURFACE_MATERIAL` (an appended salt with no prior
user, `SALT_HUMIDITY`'s exact precedent from brick 065).

That stops being free the moment some later brick's `VoxelGenerator` actually calls
`block_id_at()` to fill a `VoxelBuffer`. From that point on, every input this file reads —
the salt, every `surface_block_id`, and `BiomeTransition.TRANSITION_WIDTH` (already
flagged generation-adjacent by §13.6 the moment it feeds a material choice, which it now
does) — is baked into every world generated with it, and changing any of them becomes a
version bump (§2.1) exactly as `BiomeClassifier`'s thresholds already are. This is the
answer `nextsteps.md` asked 075 to record explicitly rather than assume: the bump policy
takes effect at the first `VoxelBuffer` write, not before, and not automatically at this
brick just because it is the first one whose output looks like content.

### 14.5 Reference: none

§12.5 and §13.5's finding a third time: the original has no discrete biome and so no
discrete material either. `Terrain_computeBiomeColor` blends climate noise straight into
terrain and vegetation RGBA, continuously, with no block or tile lookup anywhere in either
binary. There is no material-selection mechanism to diverge from — only the same
divergence already on record, applied a third time: a discrete id and a discrete block for
everything that needs one, dithered here rather than tinted because the ground is blocky
and theirs was not.

### 14.6 Out of scope for this brick

- **Subsurface layers and depth.** Still 076 — this brick is the top face of a column
  only; what is under it is a column-depth question this file says nothing about.
- **Caves, and what lines them.** 077–079, unchanged.
- **An actual `VoxelGenerator` / `VoxelBuffer` write.** §14.4 — nothing before this brick
  wrote a voxel and this brick does not start; it is a pure `(column) -> block id`
  function for whichever later brick assembles the real generator.
- **Real art.** The two new textures are the same deterministic speckled placeholders 038
  used, not a Blender/bpy pass (`CLAUDE.md` §10) — consistent with the backlog row's own
  "Blender MCP: not needed by default."

## 15. Subsurface material rules (brick 076)

Implementation: `world/generation/subsurface_material.gd` (`SubsurfaceMaterial`);
`BiomeDefinition.subsurface_block_id` (new field on the 067/075 schema, its second and, per
§12.2, last field from that original table); `SurfaceMaterial.biome_id_at()` (new accessor
on the 075 file, refactored under it); updated `tools/generators/biome_catalog_generator.gd`
(all six records regenerated with the field filled in). No new blocks — every biome's
subsurface reuses grass/dirt/sand/stone, already on disk after 038 and 075. Tests:
`tests/unit/test_subsurface_material.gd`; `tests/unit/test_biome_definition.gd`,
`test_biome_registry.gd` and `test_surface_material.gd` extended for the new field and
accessor.
Reference: none — §15.6, the same finding as §12.5, §13.5 and §14.5, a fourth time.

§14.6 named its own future reader — "subsurface layers and depth. Still 076" — three times
over, and §12.2's original wishlist named this as the *last* field the record had no
consumer for. This is that brick: what a column looks like under its own surface, down to
where every column becomes the same bedrock.

```text
SurfaceMaterial.biome_id_at(column) -> winning biome id      (075's roll, reused, not re-rolled)
        |
        +-- TerracePass.surface_y(column) - y  <= 0                     -> "" (not this pass's question)
        +-- 1 .. SUBSURFACE_DEPTH_VOXELS                                -> winning biome's subsurface_block_id
        +-- deeper                                                      -> SubsurfaceMaterial.DEEP_BLOCK_ID
```

### 15.1 Reading the surface's pick, not re-dithering

A column near a biome edge already dithers its surface block between the primary and the
neighbor at the **column** level (075, §14.1) — one coin flip per column, not one per voxel.
An independent second roll for the layer underneath would let part of the dithered band put
a neighbor's grass over the primary's dirt: two different biomes' ground stacked in one
column, which is not a blend, it is a seam. `SurfaceMaterial.biome_id_at()` — a new public
accessor on the 075 file, exposing the winning id `block_id_at()` already computed rather
than only the block it resolves to — is what 076 reads instead of re-deriving the decision.
`block_id_at()` itself is unchanged in behavior: `test_surface_material.gd`'s pinned
signature (`671f7833af3596ab`) still passes untouched, because the refactor moved the roll
into a named method without changing what it returns.

No new salt, for the same reason: appending one here would be a second dither stacked on the
first, not a second decision. This is the one place this brick's design differs from every
material-adjacent brick before it (066, 074, 075 each added their own salt or width) — the
difference is that 076 is not deciding *which* biome a column belongs to a second time, only
reading what 075 already decided.

### 15.2 Two layers only: topsoil, then bedrock

| Biome | `subsurface_block_id` | Why |
|---|---|---|
| `grassland` | `block.dirt` | the classic case dirt-under-grass was authored for |
| `forest` | `block.dirt` | canopy/litter is 086–088's vegetation, not a different ground |
| `desert` | `block.sand` | real deserts are sand for a long way down, not a thin veneer |
| `snow` | `block.dirt` | frozen ground under a snowfield, not more snow |
| `mountain` | `block.stone` | its own surface already reads as bare rock (075, §14.2) |
| `wetland` | `block.dirt` | swamp mud goes deep, same texture as its own surface |

No new block kinds — every id above is one 038 or 075 already shipped. Below the topsoil,
every biome hits the same `SubsurfaceMaterial.DEEP_BLOCK_ID` (`block.stone`): a third,
per-biome bedrock layer is exactly the kind of field nothing yet reads (067's argument, a
third time), and `block.stone` is not invented for the purpose — it is already what a
mountain's surface and several biomes' topsoil read as.

### 15.3 The depth constant, derived from the pass it sits under

`SUBSURFACE_DEPTH_VOXELS = 4` (2 m), half of `TerracePass.TERRACE_HEIGHT_VOXELS` (8, §8.1) —
the same "half, not the whole" shape `BiomeTransition.TRANSITION_WIDTH` already used against
a different constant (§13.2), applied here for a different reason: `TerracePass`'s own risers
can be up to one full terrace tall (`max_riser_voxels()`, §8.3), and a topsoil layer that
shallow means a cliff crossing a whole shelf shows bedrock beneath the soil partway down its
face. A topsoil as deep as a full terrace would make every riser read as soil top to bottom,
which is the less legible result. `TerracePass.TERRACE_HEIGHT_VOXELS` is a genuine constant
reference (unlike `narrowest_climate_gap()`, a function 074 could not put in a const
initializer), but the derivation is still asserted at runtime in
`SubsurfaceMaterial.self_check()` rather than trusted from the comment, matching the
project's one existing precedent for a derived width.

### 15.4 The cross-domain check, extended one field

`subsurface_block_reason_for(biomes, blocks)` is `SurfaceMaterial.surface_block_reason_for()`'s
exact shape, one field over, plus one extra check the surface file did not need: every
biome's `subsurface_block_id` must resolve, **and** the fixed `DEEP_BLOCK_ID` must resolve
too, since nothing per-biome names it. `SubsurfaceMaterial.for_world()` delegates the
registries'-locked/`self_check()`/`surface_block_id` checks to `SurfaceMaterial.for_world()`
rather than re-running them, and adds only the check that is 076's own.

### 15.5 Not a generation version bump — same boundary as 075's

§14.4's argument, unchanged and for the same reason: no world has ever had a voxel written
from any Phase D pass, so nothing this brick computes can contradict one. The new pieces are
`BiomeDefinition.subsurface_block_id` (a record field, §12.6's stated exception) and
`SUBSURFACE_DEPTH_VOXELS` (a pure constant — no hash, no salt, no noise layer). The boundary
§14.4 opened still holds: the first later brick whose `VoxelGenerator` actually calls
`block_id_at_voxel()` — on either file — to fill a `VoxelBuffer` is where every input both
files read becomes a pinned generation input, not before.

### 15.6 Reference: none

§12.5, §13.5 and §14.5's finding, a fourth time: the original has no discrete biome and no
discrete surface material, so it has no discrete subsurface either —
`Terrain_computeBiomeColor` never reads more than one voxel deep in either binary. Nothing to
diverge from, only the same divergence already on record, one layer further down.

### 15.7 Out of scope for this brick

- **Caves, and what lines them.** Still 077–079: this brick describes solid ground only,
  with no cavity carved into it yet.
- **Per-biome bedrock.** §15.2 — a field nothing reads today.
- **An actual `VoxelGenerator` / `VoxelBuffer` write.** §15.5, unchanged from §14.4: this
  is still a pure `(column, y) -> block id` function for whichever later brick assembles the
  real generator.

## 16. The cave mask (brick 077)

Implementation: `world/generation/cave_mask.gd` (`CaveMask`), plus the 3D extension of
`world/generation/value_noise.gd` (`ValueNoise.value3()`/`value301()`/`octave_value3()`)
it is built on.
Tests: `tests/unit/test_cave_mask.gd`, `tests/unit/test_value_noise.gd`.
Reference: none — see §16.5.

Every pass from §6 through §15 answers a question about one column: how high is the
ground, and what is it made of. This is the first pass that needs a third coordinate. A
cave is not a height and not a material choice — it is a *hollow*, the same voxel column
saying yes in one place and no a few voxels below it — so it is the first field in this
project sampled at a voxel rather than a column, and the first consumer of the 3D form
§5.6 deliberately deferred: "3D noise. Caves (077–078) need a 3D form of the same layer;
nothing before them does, and adding it now would ship an untested surface." That surface
is `ValueNoise.value3()`/`value301()`/`octave_value3()`, added in this brick alongside the
2D forms they mirror, sharing every constant, every construction check and — critically —
`max_slope_per_voxel()`, which bounds a single axis holding the other two fixed and so
needs no 3D-specific restatement.

### 16.1 One layer, thresholded

```text
density_at(voxel) = noise.value301(voxel)              # [0, 1], ValueNoise.value3()'s unit form
is_cave_at(voxel)  = density_at(voxel) < DENSITY_THRESHOLD
```

`CaveMask` holds one `ValueNoise` layer at its own salt (`WorldHash.SALT_CAVES`, reserved
since brick 015 with no user until now) and answers a voxel with a bool. Nothing else:
no height, no material, no dependency on `TerracePass` or `SubsurfaceMaterial` anywhere in
the file.

### 16.2 Why the mask reads neither the surface nor the material

`nextsteps.md` carried this decision into the brick rather than leaving it to be
re-derived: a mask is a boolean/density field, and it sits *between* `TerracePass` (the
solid ground) and `SubsurfaceMaterial` (what that ground is made of) rather than reading
either. Reading `TerracePass` here would answer two questions at once — "is this hollow"
and "is this underground" — that brick 078 needs to ask separately: 078 is what clips this
mask's answer against the terraced surface before it ever reaches a `VoxelBuffer`, so a
`density_at()` sampled at, say, y = +800 stays a legitimate answer (there is noise
everywhere in the field) without ever surfacing as a hole in the sky. Keeping the two
questions apart is also what lets 079 (underground material rules) combine this mask with
`SubsurfaceMaterial` as two independent inputs rather than one pass quietly deciding both.

### 16.3 The scale, mirrored from `ElevationField`'s relief

| Constant | Value | Why |
|---|---|---|
| `CELL_SIZE_VOXELS` | `128` = 64 m | an eighth of `ElevationField.RELIEF_CELL_SIZE_VOXELS` (1024) |
| `OCTAVES` | `4` | finest cell `128 >> 3` = 16 voxels = 8 m |
| `GAIN` | `0.5` | the conventional half, matching every other layer |
| salt | `WorldHash.SALT_CAVES` (`4`, reserved since brick 015) | its own — a cave field sharing a salt with any other pass would correlate with it |

`ErosionPass.RUGGEDNESS_CELL_SIZE_VOXELS` sits eight times *coarser* than
`ElevationField.RELIEF_CELL_SIZE_VOXELS` because it decides *where* relief may exist, a
coarser question than the relief itself. `CaveMask.CELL_SIZE_VOXELS` sits eight times
*finer*, in the other direction, because a cave system is a smaller thing than a mountain
range. The finest cave cell (16 voxels) is **half** of `ElevationField`'s own finest relief
cell (32) — the same "half, not the whole" legibility argument bricks 074
(`TRANSITION_WIDTH`) and 076 (`SUBSURFACE_DEPTH_VOXELS`) already used, here so the smallest
cave detail resolves finer than the smallest hill the ground itself carries. Both
relationships are asserted at runtime by `CaveMask.self_check()` rather than written as a
`const` expression: GDScript's warnings-as-errors flags integer division even where the
result is exact (`generation_grid.gd`'s `floor_div()` precedent), so `CELL_SIZE_VOXELS` is
a literal and the derivation is checked rather than trusted from the comment —
`SubsurfaceMaterial`'s exact precedent for the same constraint (§15.3).

### 16.4 The threshold, and the measurement behind it

`DENSITY_THRESHOLD = 0.25` is a round quarter of the field's own `[0, 1]` range, the same
style of round fraction `ElevationField.SHORE_MIDPOINT`/`SHORE_WIDTH` use. What it actually
selects is not a quarter of the world. 3D trilinear interpolation blends eight independent
hashed corners per octave against a 2D layer's four, so a summed 3D field concentrates far
more tightly around its own mean than any 2D layer in this project: measured at these exact
constants over a 13824-voxel sweep (spacing 131, just under the coarsest cell, so the walk
crosses many independent cells rather than resampling one), on each of four fixture-style
seeds — `mean 0.499`, `sd 0.150`. A comparable 2D layer runs noticeably wider (a uniform
field's own `1/sqrt(12) = 0.289`, and every fade-shaped 2D field measured in this project
sits near that, `0.28 – 0.32` — §10.4's corrected `HumidityField` measurement is the most
recent). At `0.25` that
puts **4.1% – 4.3%** of raw 3D space below threshold, consistent across every seed
measured — not a defect of the 3D form, but the property the threshold is chosen against:
caves are meant to be rare and worth finding, not the majority of the underground, and the
measured fraction already reads that way before 078 clips it down further to the ground
that is actually underground. `test_cave_mask.gd::test_the_measured_fraction_is_a_minority`
pins a plausible band (`0.5% – 15%`) around this rather than the exact figure, so a future
retune has room without the test becoming the thing being tuned against.

### 16.5 Reference: none

The three-file grep of `reference/CubeWorld-Reversal` for "cave" (case-insensitive) finds
exactly one hit with any content: the literal wide string `L"Cave"` in a name-to-id map in
`server/world/World.cpp`, almost certainly a structure or POI label rather than a terrain
generation mechanism — no recoverable density field, threshold or carving routine sits
near it. §12.5, §13.5, §14.5 and §15.6's finding, a fifth time and the least ambiguous
version of it yet: there is nothing to diverge from, so this is original design, clean-room
by construction rather than by choice (`CLAUDE.md` §16).

### 16.6 Not a generation version bump

A new field and a new 3D noise capability, both unused by any world generated so far —
still true of every Phase D brick since 062 (§7's `no world has ever had a voxel written`
argument). `WorldHash.SALT_CAVES` moves from reserved-unused to reserved-and-pinned the
moment a real `VoxelGenerator` reads it, which is the same "first `VoxelBuffer` fill"
boundary §14.4 and §15.5 already named for `SALT_SURFACE_MATERIAL` and
`SUBSURFACE_DEPTH_VOXELS`. Every pinned signature below this brick is untouched: `ValueNoise
.value()`'s own `0d355b4d9ddddd7d` still passes unchanged, and the new `value3()` form pins
its own signature (`70c1c6e87feda219`) rather than reusing or perturbing it.
`GENERATION_VERSION` stays where it is.

### 16.7 Out of scope for this brick

- **Actually carving anything.** Brick 078. This file only says which voxels *would* be
  hollow; nothing here has touched a `VoxelBuffer`.
- **Clipping the mask to underground ground.** Also 078 — §16.2 states explicitly why this
  file does not read `TerracePass`.
- **What lines a cave once it is carved.** Brick 079, which combines this mask with
  `SubsurfaceMaterial`.
- **Worm-like tunnels, domain warping, a ridged remap.** `cave_mask.gd`'s own class
  comment states the reason: a thresholded blob field is the smaller, honest first cut;
  a tunnel-shaped brick can revisit this file without changing its contract.
- **Any voxel.** Still nothing is written to a `VoxelBuffer`.
