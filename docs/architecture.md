# Architecture — layering rules

Brick 011. The rule this document exists to enforce: **dependencies point one way.**
`CLAUDE.md` §2 states the principle; this file says exactly which directory may
reference which, and `tests/unit/test_layering.gd` fails the build when a file breaks it.

## 1. The four kinds of code

Every file is one of these. Mixing two kinds in one file is the failure mode this
architecture exists to prevent.

| Kind | Holds | Never holds |
|---|---|---|
| **Definition** | immutable, data-driven description of a *kind of thing*: block, item, creature, biome, quest. Loaded from `data/`, keyed by a stable ID. | runtime state, behavior, node references |
| **State** | mutable facts about a *specific instance*: this creature's health, this world's modified voxels, this player's inventory. Plain data, serializable, no engine coupling beyond value types. | rules, timers, rendering, RPCs |
| **System** | the rules. Reads definitions, mutates state, emits events. Owns validation and authority. | its own copy of state, direct rendering, direct input |
| **Presentation** | turns replicated state into pixels and sound: scenes, meshes, animation, camera, UI, effects. | authoritative decisions, gameplay rules |

```text
Definition ──▶ State ──▶ System ──┬──▶ Presentation
                                  ├──▶ Replication
                                  └──▶ Persistence
```

A System is the only kind allowed to change State. Presentation, Replication and
Persistence are all *readers* of State; they differ only in where they send it.

Practical consequences:

- A definition can be reloaded without touching a running world.
- State can be serialized without dragging in nodes, and a test can build it directly.
- A system can be unit-tested with no scene tree.
- Presentation can be deleted and rebuilt without changing a single gameplay rule.

## 2. Directory layers and allowed dependencies

A file in layer *L* may reference `res://` paths only in *L* itself and in the layers
listed as allowed for it.

| Layer | May reference | Rationale |
|---|---|---|
| `core/` | `core/` | Engine-agnostic foundations: scale, RNG, time, IDs, serialization. Depends on nothing in the game, so everything may depend on it. |
| `autoload/` | `autoload/`, `core/` | Global services. A service that needs a subsystem is not a service. |
| `world/` | `world/`, `core/` | Terrain, generation, streaming, world persistence. Knows nothing about creatures, combat or players. |
| `gameplay/` | `gameplay/`, `core/` | Entity, combat, stats, items, quests. Knows nothing about terrain internals, AI, networking or rendering. |
| `ai/` | `ai/`, `core/`, `gameplay/`, `world/` | Decides intent from entity state and world queries; the systems it drives live in `gameplay/`. |
| `network/` | `network/`, `core/`, `gameplay/`, `world/` | Serializes commands, state and events. Must know what it replicates; must not know who renders it. |
| `client/` | `client/`, `core/`, `gameplay/`, `world/`, `network/` | Presentation and the client-side session. Reads definitions and replicated state. |
| `server/` | `server/`, `core/`, `gameplay/`, `world/`, `ai/`, `network/` | The authority. Composes every simulation layer. |
| `tests/`, `tools/` | anything | Test and tooling code observes the system from outside. |
| `assets/`, `data/` | — | No scripts. |

### The edges that matter

- **`core/` depends on nothing project-specific.** The moment `core/` imports
  `gameplay/`, it stops being reusable and every test drags the whole game in.
- **`world/` and `gameplay/` never import each other.** Terrain must not know what a
  creature is; combat must not know what a chunk is. Where they must meet — a creature
  standing on ground, a spawn point needing a biome — the meeting happens in `server/`,
  or through IDs and plain values, never through a direct import.
- **Nothing imports `client/`.** If a system needs something from the client, the
  design is wrong: the client is a consumer of state, not a source of truth.
- **Nothing imports `server/` except `server/`.** Same reason.
- **`network/` does not import `client/` or `server/`.** The protocol is shared; both
  sides depend on it, not the reverse. This is what keeps a dedicated server buildable
  without client code.
- **`gameplay/` does not import `network/`.** Systems return results; the network layer
  decides what to send. A system that emits RPCs cannot be unit-tested and cannot be
  reused by the single-player path.

### Autoloads are not an escape hatch

Autoloads (`Log`, and later services) are reachable by global name from anywhere, so
they bypass the path check. That is exactly why the rule for `autoload/` is strict:
only genuine, stateless-or-resettable services belong there. A subsystem placed in an
autoload to dodge a dependency rule is a layering violation the tooling cannot catch —
review has to.

## 3. How the rule is enforced

`tests/unit/test_layering.gd` scans every project `.gd` file for `res://` references
(`preload`, `load`, `extends "res://…"`, resource paths in strings) and asserts the
target layer is allowed for the source layer.

What it catches: a file reaching into a layer it must not know about — the violation
that actually happens in practice, usually as a convenience `preload` during a rush.

What it cannot catch:

- references through a global `class_name`, which carry no path;
- references through an autoload;
- scene (`.tscn`) instantiation of a node whose script lives in another layer;
- runtime string paths assembled at runtime.

So the test is a floor, not a proof. The reviewable rule is the table above.

## 4. Where a new file goes

1. **What kind is it?** Definition, State, System, or Presentation (§1). If it is two
   of them, it is two files.
2. **Who is allowed to know about it?** Pick the layer whose allowed-dependency row
   already covers what the file needs. If nothing fits, the design — not the table —
   is what needs changing.
3. **Does it decide anything a client could lie about?** Then it is a System, and it
   lives on the authoritative side (`gameplay/` rules invoked from `server/`), never in
   `client/`.
4. **Would a unit test of it need a scene tree?** If yes and it is not Presentation,
   the state and the rules are still tangled.

## 5. Changing the rules

The dependency table is a decision, not a preference. Adding an edge means writing an
ADR (`docs/adr/`) that says what forced it and what was tried first, then updating both
this table and the test in the same commit. Never loosen the test to make a commit pass.
