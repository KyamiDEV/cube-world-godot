# Conventions — naming, files, classes, IDs

Brick 012. Enforced where mechanically possible by `tests/unit/test_conventions.gd`.
Where it cannot be enforced, it is still binding on review.

## 1. Files and directories

| Thing | Rule | Example |
|---|---|---|
| Directory | `snake_case`, singular unless it holds a collection of peers | `core/math/`, `world/biomes/` |
| Script | `snake_case.gd` | `world_scale.gd` |
| Scene | `snake_case.tscn` | `main.tscn` |
| Resource | `snake_case.tres` | `grass_block.tres` |
| Data file | `snake_case.json` / `.csv` | `blocks.json` |
| Test | `test_<subject>.gd` | `test_world_scale.gd` |
| Doc | `kebab-case.md` | `world-generation.md` |
| ADR | `NNNN-kebab-case.md` | `0001-baseline-technical-stack.md` |

A file declaring `class_name Foo` must be named `foo.gd` — the snake_case of the class.
That is how a reader gets from a type in an error message to the file without grepping.

No spaces, no hyphens, no capitals in script, scene or resource file names. Ever.

## 2. GDScript members

Standard Godot style, with the parts that matter stated explicitly:

| Kind | Style | Example |
|---|---|---|
| Class (`class_name`, inner `class`) | `PascalCase` | `BlockDefinition` |
| Function | `snake_case` | `voxel_to_metres()` |
| Variable, member, parameter | `snake_case` | `block_id` |
| Private member or function | leading `_` | `_channel_levels`, `_format_value()` |
| Unused parameter | leading `_` | `func _process(_delta: float)` |
| Constant | `SCREAMING_SNAKE_CASE` | `VOXELS_PER_METRE` |
| Enum type | `PascalCase`; members `SCREAMING_SNAKE_CASE` | `enum Level { WARN, INFO }` |
| Signal | `snake_case`, **past tense** — it reports, it does not command | `health_changed`, `block_placed` |
| Node in a scene | `PascalCase` | `StatusLabel` |
| Autoload | `PascalCase` global name | `Log` |
| Boolean | reads as a predicate: `is_`, `has_`, `can_`, `should_` | `is_solid`, `has_collision` |

Abbreviations are spelled out except these, which are clearer short:
`id`, `ui`, `ai`, `rng`, `lod`, `aabb`, `db`, `rpc`, `msec`, `min`/`max`.

Types are mandatory on public function parameters and return values. `void` is written
explicitly. `:=` inference is fine when the right-hand side has an obvious type.

## 3. Type-name suffixes

The suffix says which of the four kinds (`docs/architecture.md` §1) a type is. This is
the fastest available signal that a file is doing two jobs at once.

| Suffix | Kind | Holds |
|---|---|---|
| `*Definition` | Definition | immutable data for a *kind of thing*, loaded from `data/` |
| `*State` | State | mutable data for one *instance*, serializable, no behavior |
| `*System` | System | rules; reads definitions, mutates state, emits events |
| `*Service` | System | a process-wide capability with no world state (RNG, IDs, time) |
| `*Registry` | System | owns a keyed collection of definitions |
| `*Command` | Message | client intent, validated by the server before it applies |
| `*Event` | Message | something that already happened, authoritative, replicated outward |
| `*Packet` | Message | a wire representation |
| `*Controller` | Presentation | drives nodes from state (camera, animation, input) |
| `*View` | Presentation | renders one thing |

No suffix is needed for a plain value type (`WorldScale`, `BlockPos`).

## 4. `class_name` policy

Global class names are a **flat, project-wide namespace** shared with every addon. Use
`class_name` only when both hold:

1. the type is referenced from at least two other files, and
2. the name is distinctive enough to be unambiguous project-wide.

Otherwise use a preloaded constant, which keeps the name file-local:

```gdscript
const BlockDefinition := preload("res://world/terrain/block_definition.gd")
```

**Never claim a bare generic name**: `World`, `Entity`, `Player`, `Item`, `Block`,
`Chunk`, `Camera`, `Server`, `Client`, `State`, `System`, `Registry`, `Config`, `Utils`.
Qualify instead — `BlockDefinition`, `CreatureState`, `WorldChunkState`. These are the
names most likely to collide with an addon or with Godot itself, and the ones that tell
a reader least.

Remember that a new `class_name` is invisible to headless runs until a project import
refreshes the class cache (`tools/scripts/test.ps1` does it; a raw `godot --script`
does not).

## 5. Stable IDs

Content is keyed by a stable string ID, never by a display name and never by an array
index (`CLAUDE.md` §9). A display name is localised, edited for feel, and changes late;
an ID is written into save files and network packets and can never change.

### Format

```
<domain>.<name>[.<variant>][.<variant>…]
```

- lower-case ASCII: `[a-z0-9_]` per segment, segments joined by `.`
- `snake_case` inside a segment; digits allowed, but a segment never starts with one
- two to four segments in practice; more means the taxonomy is wrong
- numeric suffixes are zero-padded to two digits when they order a series:
  `quest.village_bandits_01`

Valid: `item.sword.iron` · `creature.goblin` · `skill.dash` · `biome.grassland` ·
`block.stone` · `quest.village_bandits_01`

Invalid: `Item.Sword.Iron` (case) · `item-sword-iron` (hyphens) · `sword_iron`
(no domain) · `item.sword.iron.` (trailing dot) · `item..iron` (empty segment)

### Domains

The first segment is the domain, from this list. Adding a domain is a deliberate change
to this document, not an ad-hoc decision at a call site:

`block`, `item`, `creature`, `npc`, `skill`, `effect`, `quest`, `dialogue`, `faction`,
`biome`, `structure`, `dungeon`, `loot`, `recipe`, `sound`, `ui`.

### Rules

- **An ID is permanent.** Renaming one breaks saves and clients. Deprecate and alias
  instead; the registry (brick 016) owns that mechanism.
- The ID is the primary key everywhere: data files, save deltas, packets, logs.
- Display names live in the definition, never in the key.
- An ID never encodes a number, a stat or a path — only identity.

## 6. Tests

- File `tests/**/test_<subject>.gd`; the subject matches what is under test.
- **Except `tests/fixtures/`**, which holds shared inputs and helpers, not tests: the
  runner only ever collects `test_*.gd`, so a fixture named `test_` would be collected as
  a test that asserts nothing. A fixture file therefore declares no `test_*` method, and
  `test_conventions.gd` enforces both halves.
- Method `test_<behavior_being_asserted>` — a sentence fragment, not `test_1`.
- Every assertion gets a message when the expression alone would not tell a reader what
  broke.
- Helper methods in a test file are `_private`, so the runner does not collect them.

## 7. Comments

Comment *why*, not *what*. A comment restating the code is noise that rots.

`##` doc comments on every public type and non-obvious public function. `#` for
in-function reasoning: an invariant, a non-obvious ordering, a trap avoided, a
reference-derived hypothesis with its confidence level.

## 8. Commits

`<type>(<scope>): <summary> (brick NNN)` — types: `feat`, `fix`, `refactor`, `perf`,
`docs`, `test`, `chore`. The body says what changed and why it was done that way.
One brick per commit where the brick allows it.
