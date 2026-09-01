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
