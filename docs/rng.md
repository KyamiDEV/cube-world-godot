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
| Use for | server gameplay rolls: loot, crits, spawn variation, AI choices | world generation: elevation, biomes, caves, tree and prop masks, structure placement |
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
is a **generation version bump** (brick 057), with the old version kept readable or the
world explicitly retired.

## 4. Salts and streams

- **Salts** separate generation passes. Without them the tree pass and the cave pass
  agree about which cells are "high", and every cave ends up under a tree. Salts live as
  named constants in `WorldHash` (`SALT_TREES`, `SALT_CAVES`, …). Add one per pass;
  **never reuse or renumber one**, because the numbers are baked into every world made
  with them.
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

## 6. Seeds

- A world's seed is an integer. `WorldHash.seed_from_text()` maps what a player typed:
  a numeric string is taken at face value (so "12345" in a bug report reproduces), and
  anything else goes through the project's stable string hash.
- The seed, the generation version and the world format version are all persisted with
  the world (bricks 056–057, 103). A seed alone does not identify a world; the pair
  `(seed, generation version)` does.
- Server-side gameplay streams are seeded from the world seed and a stable key, so a
  reloaded world resumes the same rolls rather than restarting from an arbitrary state.
