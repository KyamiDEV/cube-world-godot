# nextsteps.md — Master session handoff

> Compact durable state for Claude Code. Update after every brick.
> After update: commit when appropriate, then `/clear`.

## Current project state

- Project: CubeWorld-style Alpha 2013 reimplementation
- Engine: `4.7.2.stable.double.custom_build.ed1daf0bf` — VERIFIED (`docs/environment.md`)
- Voxel Tools: `1.7.0`, edition `Module` — VERIFIED (`docs/voxel-tools.md`)
- Voxel scale: `1 voxel = 0.5 m` — implemented in `core/math/world_scale.gd`
- Reference repo: `reference/CubeWorld-Reversal` (local, gitignored, `.gdignore`d) — **not read yet**
- Git: `main`, one commit per brick
- Godot AI MCP: failed to connect this session (`CONNECTION_CLOSED`); not needed so far

## Current phase / milestone / task

- Phase `B — Architecture & reference extraction`
- Milestone `M002 — Voxel sandbox` (M001 bootstrap COMPLETE)
- Next task `025 — Map CubeWorld inventory/item/equipment concepts`

## Completed bricks

`001`–`024`. Phase A complete; Phase B contracts complete (011–020); reference tree
reading started at `021`.

`021` mapped `*/world/` (13 classes: `World`, `Zone`, `Region`, `Dungeon`, `House`,
`Spawn`, `Field`, `Chunk`, `ChunkBuffer`, `LandscapeTile`, `WorldInfo`, `WorldMap`,
`ZoneTile`) into `docs/reference/matrix-world.md`. Notable: `World` is a god-object
whose functions were split by behavior, not kept as one row (see matrix §2); several
classes (`Chunk`, `ChunkBuffer`, block/column accessors, the client per-frame world
tick) are `Placed = NONE` because `VoxelTerrain`/`VoxelMesherBlocky`/Godot's own
process loop supersede them — do not reimplement a parallel chunk cache. Four open
questions recorded (matrix §4), most importantly Q2: the original client re-ran world
generation locally rather than only presenting replicated state — confirm this was a
singleplayer-only pattern before brick 056.

`022` mapped `*/entity/` (6 classes: `Creature`, `Sprite`, `SpriteManager`, `Speech`,
`QuestText`, `QuestTextNode`) into `docs/reference/matrix-entity.md`. Notable:
`Creature`'s own attributed functions are almost entirely ctor/dtor/container plumbing
— actual creature behavior (locomotion, player-controller reset, replicated-state
apply, appearance/equipment defaults) is scattered across `game_misc` and the client
`World`/`Interface` sections and was split out in matrix §2, same pattern as `World` in
brick 021. `QuestText`/`QuestTextNode` are physically in `*/entity/` but reserved for
`matrix-quests.md` (026) per `matrix-index.md` — rows added with `Placed = NONE` so
they aren't silently dropped. Three open questions recorded (matrix §4): Q1 no backlog
brick currently cites this matrix for creature/player locomotion (112/116/128/243); Q2
`*/db/` (`cube::Database`) has no planned matrix at all; Q3 `Sprite`/`SpriteManager`
are stub-only in both binaries, role undetermined.

`023` mapped `*/ai/` (8 classes: `CombatBehavior`, `CompanionBehavior`,
`LookAtPlayerBehavior`, `RandomInteractionBehavior`, `RandomWalkBehavior`,
`SequentialBehavior`, `SpawnLocationBehavior`, `WalkPathBehavior`) into
`docs/reference/matrix-ai.md`. Every leaf shares one tick+clone interface (no separate
`Behavior` base class survived attribution — inferred and recorded in matrix §2, same
"concept with no single class" treatment as 021/022). `CombatBehavior`'s tick is an AI
decision shell but almost all of its named functions are ability timing/resolution math
— that math is `Placed = NONE` here, reserved for `matrix-combat.md` (024), continuing
the split pattern from `matrix-entity.md`. Nav/locomotion primitives
(`NavGraph_*`, `World_getBlockFloat`, `Creature_resolveSeparation`) are called by three
different leaves and owned by none — cross-referenced to `matrix-entity.md`'s Q1
instead of duplicating it. Three open questions recorded (matrix §4): Q1
`SequentialBehavior` executes like a first-success Selector despite its decompiled
name — need to decide if bricks 177/178 need both a true Sequence and a Selector; Q2
`SpawnLocationBehavior`'s location-switch condition reads an unconfirmed `world` field,
possibly the day/night clock (brick 216); Q3 `RandomInteractionBehavior`'s tick body
(773 lines) was not read in full, only GAP-summarized — revisit before brick 189/199 if
the one-line role proves insufficient.

`024` mapped combat resolution/damage/hit-detection into `docs/reference/matrix-combat.md`.
No reference class is named `Combat`/`Damage`/`Hit` — everything is 14 "concepts with no
single class" rows (ability timing table, attack-speed/haste, base-damage formula,
max-health formula, armor mitigation, resist diminishing-returns, ability power/mana
cost, resource regen, equipment stat-bonus plumbing, threat/target selection, hostility
gate, aggro-alert propagation, attack-opcode/animation classification, buff/status-effect
list), gathered from server `game_misc`/`CombatBehavior` GAP rows, `cube_types.h`'s
VERIFIED `cube_Creature_offsets`/`cube_BuffNode_offsets` enums, and client `Interface`
(`stat::calc*`) rows read only for corroboration. Three open questions recorded (matrix
§4): Q1 server `World.cpp`'s `readCombatActionFromStream`/`readHitFromStream` deserialize
fixed-size records from a SQLite-loaded blob (adjacent to `SpeechDb_loadBlobToVector`),
not obviously a live network read despite the name — unresolved whether this is
quest-script trigger data or prefigures the combat-event wire format (blocks 136, 137,
249); Q2 the damage/armor/mana formulas share an unexplained `2^a*2^b[/2^c]` shape across
independent functions in both binaries — shape is corroborated, meaning of the exponents
is not, and per the clean-room policy we may not need to recover it (blocks 141–144); Q3
the two attack-*selection* decision trees (`Combat_selectNextAttackAnim`,
`Combat_selectSpiritAttackId`) were read only via their one-line GAP summary, not their
bodies (blocks 138, 139, 192).

## Commands

```powershell
tools\scripts\check.ps1      # engine + import + voxel + full GDScript compile + headless boot
tools\scripts\test.ps1       # test suite  (-File / -Filter / -Verbose_ / -NoImport)
tools\scripts\run.ps1        # run the game (-Headless; game args forwarded past --)
tools\scripts\godot.ps1 -e   # open the editor
```

Last run: `check.ps1` **OK** · `test.ps1` **OK** — 15 files, 195 tests, 9 978 assertions, 0 failed.

## What exists now

| Area | File | Gives you |
|---|---|---|
| Logging | `autoload/log.gd` | levels, channels, `check()` vs `invariant()`, test capture |
| Scale | `core/math/world_scale.gd` | metres ↔ units ↔ voxels; the only place `0.5`/`2.0` may appear |
| Time | `core/time/simulation_clock.gd` | 60 Hz fixed step, catch-up clamp, snapshot cadence |
| RNG | `core/random/deterministic_rng.gd`, `world_hash.gd` | splitmix64 stream + positional hashing for generation |
| IDs | `core/ids/stable_id.gd`, `definition_registry.gd` | ID grammar, catalogues, aliases, network indices |
| Saves | `core/serialization/save_version.gd` | four version numbers, load verdicts, migration steps |
| Protocol | `network/protocol/*.gd` | message kinds, direction rules, handshake compatibility |
| Authority | `network/authority/command_gate.gd` | envelope validation: owner, tick window, replay, rate limit |
| Docs | `docs/architecture.md`, `conventions.md`, `rng.md`, `persistence.md`, `protocol.md`, `server-authority.md`, `simulation-time.md`, `logging-and-errors.md`, `adr/0001` | the contracts those files implement |

## Next 10 actions

1. `025` map inventory/item/equipment concepts → `docs/reference/matrix-items.md`.
2. `026` quests (`QuestText`/`QuestTextNode` deferred from 022) · `027` UI (`WorldPreviewWidget` belongs here, deferred from 021) · `028` client/server split.
3. `029` confidence/uncertainty convention (baseline already in `docs/reference/README.md` §4).
4. `030` traceability index from notes to bricks.
5. `031`–`038` block definition schema, registry, block set — first use of `DefinitionRegistry`.
6. `039`–`042` `VoxelTerrain` + `VoxelMesherBlocky` + viewer baseline.
7. `052`–`055` mesh block size benchmarks; record the measured choice.
8. Before `056`: resolve Q2 from `matrix-world.md` (client-side world generation — singleplayer-only pattern?) — `matrix-ai.md`'s observation that both binaries carry near-identical AI-tick bodies is corroborating evidence, still unresolved.
9. Before `112`/`116`/`128`/`243`: resolve Q1 from `matrix-entity.md` (cite the matrix for creature/player locomotion, or add a dedicated brick) — `matrix-ai.md`'s nav/locomotion-primitives row cross-refs the same question.
10. Before `177`/`178`: resolve Q1 from `matrix-ai.md` (does the `BehaviorNode` tree need both a true Sequence and a first-success Selector, given `SequentialBehavior` observably behaves as the latter?). Before `190`/`216`: resolve Q2 from `matrix-ai.md` (unconfirmed world-clock field gating `SpawnLocationBehavior`'s location switch).
11. Before `136`/`137`/`249`: resolve Q1 from `matrix-combat.md` (is `readCombatActionFromStream`/`readHitFromStream` quest-script trigger data or a combat-event wire-format precursor?). Before `141`–`144`: Q2 (unexplained `2^a*2^b` formula shape — may not need resolving under clean-room policy). Before `138`/`139`/`192`: Q3 (attack-selection decision-tree bodies unread).
12. Update this file after every brick.

## Working set

At session start read `CLAUDE.md`, then this file, then only the active backlog row, its
dependency rows, and the files the task names. For 021+ also read
`docs/reference/README.md` and `matrix-index.md` before opening the reference tree.

## Human test state

- Last human playtest: `NOT STARTED`. Nothing visual exists yet — the main scene prints a
  boot report to a label. First `HUMAN_REQUIRED` brick is `091`.
- Last reported visual/gameplay issues: `NONE`

## Technical notes worth keeping

- **Class cache.** Headless `--script` runs read `.godot/global_script_class_cache.cfg`
  and never refresh it, so a new `class_name` is invisible until `godot --headless
  --import` runs. `check.ps1`/`test.ps1` do it; a raw `godot --script` does not.
- **Parse checking.** `load()` returns a resource even for a broken script. Validity is
  decided by `can_instantiate()` (runner) or a detached `GDScript` parse
  (`check_scripts.gd`, which renames the `class_name` in its copy because the real file
  is already registered globally).
- **A test with zero assertions fails.** A GDScript runtime error unwinds the method
  without stopping the runner, so that is the only signal the body aborted.
- **Warnings are errors** for integer division, narrowing conversion and shadowed
  variables (`project.godot [debug]`). Intentional cases need `@warning_ignore*`.
  Watch for: `_init(domain)` shadowing a `domain()` method; `var x := something_untyped`.
- **PowerShell 5.1** wraps native stderr in ErrorRecords; `Invoke-Godot` relaxes
  `ErrorActionPreference` around the call only.
- **GDScript int64** wraps two's-complement as needed, but `>>` sign-extends — use the
  masked logical shift in `DeterministicRng`. Literal negative operands in shifts are a
  parse error; only runtime values work.
- `VoxelGeneratorMultipassCB` exists in 1.7 — the route for generation needing neighbour
  context (structures/villages, bricks 089–093).
- `VoxelTerrainMultiplayerSynchronizer` exists but replicates terrain blocks only; it is
  not a gameplay authority mechanism (evaluate at brick 050 / Phase K).

## Known risks

- Decompiled behavior can be ambiguous.
- Generation determinism can regress accidentally.
- Networking must be designed before late-stage multiplayer integration.
- Heavy voxel generation should not become a large thread-unsafe GDScript loop.
- Visual similarity is not proof of behavioral parity.
- The engine binary is machine-local; only its fingerprint is committed.

## Session handoff rule

At the end of every task, keep this file to: current phase/milestone/task, completed
brick IDs, next 3–10 actions, blockers, changed files, test result, human-test result,
and only important technical notes. Do not paste large logs here.
