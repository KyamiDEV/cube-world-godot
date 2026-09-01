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
- Next task `030 — Create traceability index from reference notes to backlog`

## Completed bricks

`001`–`029`. Phase A complete; Phase B contracts complete (011–020); reference tree
mapping (021–028) complete — all 8 matrices done; confidence/uncertainty convention
(029) formalized.

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

`025` mapped inventory/item/equipment concepts into `docs/reference/matrix-items.md`.
One dedicated class (`InventoryWidget`, client) placed in `client/ui/`; `Database`
cross-referenced as out of scope (same generic SQLite blob store already flagged in
`matrix-entity.md`); 9 "concept with no single class" rows gathered from server
`game_misc` item/equip/loot/currency functions and client `GameController`. Notable:
`attribution.tsv` attributes the actual inventory-grid rebuild/scroll/hover functions
(GAP-named `InventoryWidget_rebuildItemList` etc.) to `GameController`, not
`InventoryWidget` — `GameController` is a 620-function client class with no owning
matrix in 021–028, only its ~10 item-relevant functions were pulled in here, same
"concept with no single class" pattern as 021–024. Three open questions recorded
(matrix §4): Q1 `GameController` itself needs a home (a new matrix before 224/225, or
absorbed by 028); Q2 equipment slot count is contradictory across two server functions
(16 vs 12) with no VERIFIED offset to arbitrate, unlike combat's `cube_Creature_offsets`
— brick 164 must choose independently; Q3 the "rng affix" rolled by
`GameController_onItemPickup` was not read past its GAP one-liner, relevant before
brick 173 if affix mechanics matter for the loot roll service.

`026` mapped quest/NPC concepts into `docs/reference/matrix-quests.md`. Placed the two
classes deferred from `matrix-entity.md` (`QuestText`, `QuestTextNode` — a shared
templating/tree engine with `Speech`) and found no dedicated `NPC`/`Quest`/`Faction`/
`Shop` class in either binary: NPCs are plain `Creature` instances, and all quest/NPC
behavior is 7 "concept with no single class" rows pulled from client `GameController`
(`interactNpc`, `interactSpecialObject`, `computeQuestScore`, `questStateChanged`,
`build_quest_text`) and server `game_misc`/`EntityData` (quest strings stored inline on
the entity record, an opcode-tagged `check_quest_id_match`). Notable: quest progress in
the original is a **polled derived score** (`computeQuestScore` sums 11 unrecovered
counters), not a discrete objective list — the backlog's brick 207 "objective types"
design is judged an acceptable behavioral equivalent, not a reference deviation, since
the exact counters are decompiler data we would not ship anyway (matrix §4 Q1). Faction/
hostility/aggro was **not** re-placed — already fully mapped in `matrix-combat.md` §2,
cross-ref only. Two open questions recorded (matrix §4): Q1 the unrecovered 11-counter
quest score (likely resolvable by design decision alone, see above); Q2 whether
`check_quest_id_match`'s `event type 0x19` is the same opcode-tagged stream as
`matrix-combat.md` Q1's `readCombatActionFromStream`/`readHitFromStream` — re-opens that
question with new evidence, relevant before brick 251. Brick 200 ("NPC shop service")
already covers the `interactNpc` trade-UI branch found here, so no new question was
needed for it. `matrix-items.md` Q1 (`GameController` scoping) gained corroborating
evidence rather than a duplicate question.

`027` mapped `cube/ui/` (24 files, 22 `cube::` classes) into `docs/reference/matrix-ui.md`.
Every widget but one is stub-only (1–2 attributed functions — ctor plus a render/input
vfunc); the exception, `AdaptionWidget` (28 attributed functions), is the shared layout/
scroll/bounds/animation engine every other widget inherits from, same "one real class,
rest are thin leaves" shape as `matrix-ai.md`'s behavior tree. Two files in the directory
(`Button`, `ScrollSlider`) declare only `plasma::` methods — misfiled engine-layer
widgets, moved to §3 out-of-scope, same pattern as the combat functions cross-referenced
out of `matrix-world.md`. `cube::WorldPreviewWidget` (deferred from `matrix-world.md`,
021) was placed here; `cube::InventoryWidget` (already placed in `matrix-items.md`, 025)
was cross-referenced, not re-placed. Notable: `GameController` GAP rows for mouse
routing, hover/focus, widget-tree file deserialization (`.CUB` format), and the
character-select/world-select screen builders (`buildCharacterList`/`buildWorldList`)
confirm — a third and fourth time, after `matrix-items.md` and `matrix-quests.md` — that
the actual client UI framework lives on `GameController`, not on any `Widget` subclass;
folded into `matrix-items.md` Q1 as corroborating evidence rather than a new question.
Two open questions recorded (matrix §4): Q1 several reference UI screens (character
creation, main menu/title screen, merchant/trade dialog) have no corresponding backlog
brick yet; Q2 `GameController`'s widget-framework slice keeps growing across three
matrices with no owning matrix or brick — same underlying question as
`matrix-items.md` Q1, now with UI-framework evidence added.

`028` mapped the client/server split into `docs/reference/matrix-client-server.md` — the
last of the mapping bricks (021–028). Only 2 dedicated networking classes exist
(`cube::Server`, `cube::Connection`, both server-only, both stub-only on their own
attributed functions); the actual protocol logic is 9 "concept with no single class"
rows. Notable finding: the send-loop/recv-dispatch/serialize functions GAP-names after
`Server`/`Connection`/`World`/`EntityData` are physically filed under `Global` (no
owning class) inside `server/_library/crt_stl.cpp` — the automated attribution tool
treats them as library code because they're vtable-less free functions, but GAP naming
and a `std::function`-lambda call-graph read (each wrapped in its own thunk) confirm
send and receive run as two independent per-connection workers. The client binary has
**no networking class or `net/` directory at all** — its socket-facing functions
(`net::Connection::recv_delta_*`, `EntityState_deserializeFromBuffer`/
`recvFromSocket`) are entirely unattributed (`kind=lib,target=other`), invisible to a
class-based read; the one class-attributed touchpoint, `GameController_disconnect`,
continues the same "GameController is the real framework" pattern already seen in
`matrix-items.md`/`matrix-quests.md`/`matrix-ui.md`. Two prior open questions were
**closed** this brick, not just cross-referenced: `matrix-combat.md` Q1 — a wider read
of the `World.cpp` call site (blob key built from `"mission"`/`"monster"` + int IDs)
confirms `readCombatActionFromStream`/`readHitFromStream` are quest-script trigger data,
not a network wire format, so bricks 249/251 must design combat-event replication fresh;
and `matrix-items.md` Q1 / `matrix-ui.md` Q2 (`GameController` scoping) — resolved by
decision, same god-object treatment as `World`/`Creature`/the `Behavior` tree, no new
matrix or brick. One new question recorded (matrix §4 Q3): no connect/login/handshake
function was found in either binary's attributed or GAP-named set — a genuine gap in the
source material (`docs/protocol.md`'s independently-designed `HANDSHAKE` kind has no
reference behaviour to corroborate, and does not need one per the clean-room policy).

`029` formalized the confidence/uncertainty convention sketched in `docs/reference/README.md`
§4 into `docs/reference/confidence.md`: a second axis (read depth — `FULL`/`PARTIAL`/
`GAP-ONLY`/`UNREAD`) alongside claim confidence, a ceiling rule that a `GAP_ANALYSIS.md`
-only claim cannot be recorded `HIGH` unless independently corroborated (with the
existing `matrix-client-server.md` dirty-bit row and `matrix-ai.md` ability-timing row
cited as the two correct patterns already in use), "overall confidence" defined as the
minimum over load-bearing claims rather than an average, and the open-question
resolution lifecycle (`(RESOLVED — brick NNN)` prefix, rewrite "Resolved by" in place,
never delete the row) formalizing the pattern brick 028 already used three times.
`README.md` §4 now points to it instead of restating a growing baseline; `_template.md`
and `_matrix_template.md` gained pointers and a read-depth column (template files only —
the 8 already-committed matrices from 021–028 are not retrofitted, per the brick's own
"decisions apply going forward" scope). No code changed; `check.ps1`/`test.ps1` untouched
and not re-run for this docs-only brick beyond the session-start check already recorded
above.

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

1. `030` traceability index from notes to bricks — mapping bricks 021–028 are all `DONE`,
   confidence convention (029) is done, this is what stitches them together.
2. `031`–`038` block definition schema, registry, block set — first use of `DefinitionRegistry`.
3. `039`–`042` `VoxelTerrain` + `VoxelMesherBlocky` + viewer baseline.
4. `052`–`055` mesh block size benchmarks; record the measured choice.
5. Before `056`: resolve Q2 from `matrix-world.md` (client-side world generation — singleplayer-only pattern?) — `matrix-ai.md`'s observation that both binaries carry near-identical AI-tick bodies is corroborating evidence, still unresolved.
6. Before `112`/`116`/`128`/`243`: resolve Q1 from `matrix-entity.md` (cite the matrix for creature/player locomotion, or add a dedicated brick) — `matrix-ai.md`'s nav/locomotion-primitives row cross-refs the same question.
7. Before `164`/`165`: resolve Q2 from `matrix-items.md` (contradictory equipment slot count, 16 vs 12, neither VERIFIED). Before `172`/`173`: Q3 (unread "rng affix" roll in `GameController_onItemPickup`). (`matrix-items.md` Q1 / `matrix-ui.md` Q2 — `GameController` scoping — is now **resolved**, see brick 028 above: no new matrix or brick.)
8. Before `177`/`178`: resolve Q1 from `matrix-ai.md` (does the `BehaviorNode` tree need both a true Sequence and a first-success Selector, given `SequentialBehavior` observably behaves as the latter?). Before `190`/`216`: resolve Q2 from `matrix-ai.md` (unconfirmed world-clock field gating `SpawnLocationBehavior`'s location switch).
9. Before `141`–`144`: resolve `matrix-combat.md` Q2 (unexplained `2^a*2^b` formula shape — may not need resolving under clean-room policy). Before `138`/`139`/`192`: Q3 (attack-selection decision-tree bodies unread). (`matrix-combat.md` Q1 is now **resolved** by brick 028 — quest-script trigger data, not a network format; bricks 249/251 design combat-event replication fresh, with no reference wire format to draw on.)
10. Before `206`–`209`: resolve Q1 from `matrix-quests.md` (the unrecovered 11-counter quest-progress score behind `computeQuestScore` — likely resolvable by design decision alone). Q2 (`check_quest_id_match`'s `event type 0x19`) is unaffected by brick 028's Q1 resolution — still open, still relevant before `251`.
11. Before phase J/K UI bricks (224–231) start: resolve Q1 from `matrix-ui.md` (character creation, main menu/title screen, and merchant/trade dialog have no owning backlog brick yet — a scoping pass may need to insert new bricks).
12. Before `235`/`236`: optionally resolve Q3 from `matrix-client-server.md` (no connect/login/handshake function was found in either binary — a targeted raw read of `server/net/Server.cpp`, only if reference corroboration is wanted; not required by clean-room policy).
13. Update this file after every brick.

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
