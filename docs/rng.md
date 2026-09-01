# Deterministic RNG contract

Brick 015. Implementations: `core/random/deterministic_rng.gd`,
`core/random/world_hash.gd`. Enforced by `tests/unit/test_rng_discipline.gd`.

## 1. The rule

**Simulation code never calls the engine's global randomness.**

Forbidden anywhere under `core/`, `world/`, `gameplay/`, `ai/`, `network/`, `server/`,
`autoload/`:

```
randi()  randi_range()  randf()  randf_range()  randfn()  randomize()
rand_from_seed()  RandomNumberGenerator  Array.pick_random()  Array.shuffle()
```

Two reasons, and the second is the one that bites:

1. They are seeded from process state, so nothing is reproducible.
2. They are **engine implementation details**. Even seeded, the algorithm behind
   `RandomNumberGenerator` may change in a future Godot build. A world that regenerates
   differently after an engine upgrade is a corrupted world, and the corruption is
   silent until a player walks back to a place they remember.

Presentation may use engine randomness for anything that no one else has to agree
about — a particle jitter, a sound variation — as long as it changes nothing the server
or another client can observe.

## 2. Two generators, two jobs

| | `DeterministicRng` | `WorldHash` |
|---|---|---|
| Shape | a stream with state | stateless function of position |
| Reproducible because | the same seed replays the same sequence | the same coordinates always hash the same |
| Order sensitivity | order **matters**: the Nth draw depends on the N−1 before it | none: sampling one cell never affects another |
| Use for | server gameplay rolls: loot, crits, spawn variation, AI choices | world generation: elevation, biomes, caves, tree and prop masks, structure placement — reached through `GenerationHash` (brick 058), never called bare from `world/generation/` |
| Saved? | yes, the stream state is part of world state | no, it is derived from the seed |

### Why generation cannot use a stream

If chunk generation drew from a shared sequence, a chunk's content would depend on how
many chunks were generated before it — so a player arriving from the north would see a
different world than one arriving from the south, and a reloaded world would not match
the one that was saved. Positional hashing removes the question: a cell's value depends
on the cell.

```gdscript
# Placement mask: no sequence at all.
if WorldHash.chance_at(world_seed, voxel, 0.02, WorldHash.SALT_TREES):
    _place_tree(voxel)

# Several related values for one position: a stream owned by that position.
var rng := WorldHash.rng_at_voxel(world_seed, chunk_origin, WorldHash.SALT_STRUCTURES)
var kind := rng.pick(eligible_structures)
var rotation := rng.next_int(0, 3)
```

## 3. The algorithm is a contract

The generator is **splitmix64**, written out in GDScript rather than delegated to the
engine, and pinned by a reference-vector test. String hashing is **FNV-1a 64**, also
written out: `String.hash()` is 32-bit and engine-defined, and these hashes key saved
data and content IDs.

Changing either algorithm changes every world ever generated. That is not a bug fix; it
is a **generation version bump**, with the old version kept readable or the world
explicitly retired — the lifecycle lives in `world/generation/generation_version.gd`
(brick 057, `docs/world-generation.md` §2), whose bump checklist §2.5 names this case.

`WorldHash`'s combining step counts as part of that contract, and it has changed twice,
both times to close the *same* mirror world and both times before any world existed:

- **Brick 058** — XOR-combining the per-axis products made `hash2(-7, -9)` equal
  `hash2(7, 9)`, mirroring a quarter of the world through the origin. Fixed by
  multiplying by an odd constant between folds (`docs/world-generation.md` §3.5).
- **Brick 059** — multiplying preserves an exact negation (`(-v) * C == -(v * C)`), and
  the running value is the exact negative of its mirror whenever `seed * 31 + salt` is
  even, so half of all (seed, salt) pairs were still mirrored. Fixed by adding an odd
  constant after each fold (`docs/world-generation.md` §4.6).

**Brick 060 has landed**, so the window is closed: the world now has generated content
(`world/generation/value_noise.gd`, `world/generation/continentalness.gd`,
`docs/world-generation.md` §5), and a third change to this arithmetic is a version bump,
not a fix. Note what the second
one cost to find: 058's regression test used one seed and salt 0, an odd effective seed,
where the identity does not hold. A hash regression test sweeps **both parities** of
`seed * 31 + salt`.

## 4. Salts and streams

- **Salts** separate generation passes. Without them the tree pass and the cave pass
  agree about which cells are "high", and every cave ends up under a tree. Salts live as
  named constants in `WorldHash` (`SALT_TREES`, `SALT_CAVES`, …). Add one per pass;
  **never reuse or renumber one**, because the numbers are baked into every world made
  with them.
- **Space tags** separate coordinate *grids*, and generation code gets them for free by
  calling `world/generation/generation_hash.gd` rather than `WorldHash` directly. Chunk
  `(3, 0, 5)` and voxel `(3, 0, 5)` are different places carrying the same numbers; the
  tag is what keeps a per-chunk pass from agreeing cell for cell with a per-voxel pass
  that shares its salt (brick 058, `docs/world-generation.md` §3.2). Tag values follow
  the same append-never-renumber rule as salts, and a salt must stay below
  `GenerationHash.SPACE_SALT_STRIDE`.
- **Octaves inside one pass are separated by a lattice offset, not by a salt.** A layered
  field (`ValueNoise`, brick 060) needs its layers decorrelated too, and `salt + octave`
  is not the way: salts are one per pass and adding to one walks into the next pass's.
  Each octave shifts its *lattice coordinate* by a fixed step instead, reading a different
  part of the same hash field. Without it every octave samples lattice `(0, 0)` at the
  world origin and agrees there (`docs/world-generation.md` §5.2). The step value is baked
  into every world made with it, so it follows the same never-change rule as a salt.
- **Forks** separate consumers of a sequential stream. `rng.derive(salt)` or
  `derive_named("loot")` gives a subsystem its own stream, so a change in how many
  values one system draws cannot shift another system's results. Sharing one stream
  between subsystems means every balance tweak silently reshuffles unrelated content.

## 5. Rules for calling

- **Never let a disabled roll consume a value.** `next_bool(0.0)` and `next_bool(1.0)`
  short-circuit for exactly this reason: turning a feature off must not shift the
  stream and change everything after it.
- **Ranges are inclusive on both ends** in `next_int(min, max)`; floats are `[min, max)`.
- **`next_int` uses rejection sampling**, not modulo. Modulo over a span that does not
  divide the range evenly favours low values — invisible in testing, visible as loot
  tables that quietly prefer their first entries.
- **`pick_weighted` returns -1** when nothing is eligible. Handle it; do not treat -1 as
  index 0.
- **`shuffled()` copies.** Never shuffle a definition list in place.
- **One stream, one owner.** `DeterministicRng` is not thread-safe. A generation worker
  takes a positional stream of its own rather than sharing one across threads.
- **Test a generation pass through the shared fixtures.** `tests/fixtures/
  generation_fixtures.gd` (brick 059, `docs/world-generation.md` §4) holds the worlds,
  the coordinates and the checks; both defects above were found by sampling a coordinate
  chosen because it was awkward, which is not what a pass's author picks unaided.

## 6. Seeds

- A world's seed is an integer. `WorldHash.seed_from_text()` maps what a player typed:
  a numeric string is taken at face value (so "12345" in a bug report reproduces), and
  anything else goes through the project's stable string hash.
- The seed, the generation version and the world format version are all persisted with
  the world (bricks 056–057, 103). A seed alone does not identify a world; the pair
  `(seed, generation version)` does — which is why generation call sites take a
  `WorldSeed` (`world/generation/world_seed.gd`, brick 056, `docs/world-generation.md`
  §1) rather than an integer, and why that pair is also compared across a session
  (`docs/reference/world-generation-authority.md`).
- Server-side gameplay streams are seeded from the world seed and a stable key, so a
  reloaded world resumes the same rolls rather than restarting from an arbitrary state.
