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
