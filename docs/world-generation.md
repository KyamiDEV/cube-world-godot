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
  implements, how a world on a retired version is handled — is brick 057.
  `WorldSeed.generation_version` only records which version applies.
- Where a world's save directory lives (bricks 102–103) and what else its metadata holds
  (103).
- Any actual generation. The first field lands with brick 060.
