# Reference matrix — `ai`

| Field | Value |
|---|---|
| Group | `ai` |
| Backlog brick | `023` |
| Mapped on | `2026-09-01` |
| Sources read | server+client `attribution.tsv` (grepped for the 8 `*Behavior` class names); server `GAP_ANALYSIS.md` sections `CombatBehavior`, `RandomInteractionBehavior`, `CompanionBehavior`; client `GAP_ANALYSIS.md` sections `CombatBehavior`, `RandomInteractionBehavior` (skimmed, for corroboration only); the reconstructed `.h` for all 8 server classes; full server `.cpp` bodies for `LookAtPlayerBehavior`, `RandomWalkBehavior`, `WalkPathBehavior`, `SpawnLocationBehavior`, `SequentialBehavior`, `CompanionBehavior` (each under 400 lines); `vfunc_0`/`vfunc_1` boundaries only (not the ~1400-line ability-selection body) for `CombatBehavior`; `.h` only for `RandomInteractionBehavior` (body behavior taken from `GAP_ANALYSIS.md`'s high-confidence summaries, per README §2.4) |
| Coverage | 8 of 8 classes in the group placed |

## 1. Class map

Every class in this group exposes the same two-slot pattern in its own words: a **tick**
method (`vfunc_0`, signature `(creature, world, dt[, extra])`) that runs one AI update,
and a **clone** method (`vfunc_1`, no args) that heap-allocates a copy of the instance
with its vtable and fields — see §2 for why this reads as a shared base interface rather
than eight unrelated classes.

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::SequentialBehavior` | both | composite node holding an ordered list of child behaviors (built by cloning each source child); tick walks the list and stops at the first child whose tick reports "handled", otherwise zeroes the creature's velocity and reports "not handled"; owns child-list cleanup on destroy | `ai/behavior/` | 177, 178 | MEDIUM | control flow is HIGH confidence; whether this is a *Sequence* or *Selector* in our terms is Q1 |
| `cube::CombatBehavior` | both | tick decides and drives one attack/ability action (target/threat pick, windup→commit→reset timing); the great majority of its *named* functions are ability cooldown/cast/recovery/resource-cost tables, hostility and alert-allies checks — resolution math, not AI decision shape | `ai/combat/` (tick shell only) | 191, 192, 194, 195 | MEDIUM (tick shell) | resolution helpers (`Combat_getAbility*`, `Combat_findTopThreatTarget`, `Combat_computeAttackSpeed`, `areHostile`, `alertNearbyAllies`) → `Placed = NONE` here, reserved for `matrix-combat.md` (024), same split `matrix-entity.md` §2 already made for the `Interface`-filed stat formulas |
| `cube::CompanionBehavior` | both | tick for a companion bound to a target entity id: leash/proximity check via a fixed-point vector transform, passive health regen while in range and creature is the companion type tag, else separation-aware steer-toward-target with nav-graph fallback when the direct path is blocked | `ai/behavior/`; locomotion calls cross-ref `gameplay/creature/` | 196, 197 | MEDIUM | shares its blocked-path/jitter/repath shape almost verbatim with `WalkPathBehavior` — see §2 |
| `cube::WalkPathBehavior` | both | patrol: owns a waypoint vector and a cycling index; on arrival probes the next hop for a clear path before committing, falls back to nav-graph pathfinding when blocked, retries on a 2–6 s timer | `ai/navigation/`, `ai/behavior/` | 185, 128 | MEDIUM | |
| `cube::SpawnLocationBehavior` | both | cycles a creature between pre-authored waypoint *groups* (e.g. a "home" set and a "work" set), selected by comparing each group's stored value against a world clock/counter field; drives nav-graph pathing to the active group's anchor with a ground-solidity probe | `ai/behavior/` or `gameplay/companions/`/NPC schedule | 190 | LOW–MEDIUM | the world-clock field is an offset comparison only, not a confirmed day/night hook — Q2 |
| `cube::RandomWalkBehavior` | both | idle wander: counts down an internal timer; on expiry, steers back toward a stored anchor position if displaced past a threshold, else picks a fully random horizontal heading; rearms the timer to 3–8 s | `ai/behavior/` | 186, 187 | MEDIUM | |
| `cube::LookAtPlayerBehavior` | both | tick scans nearby tracked entities for the closest one inside an 8-unit radius; if found, sets a status flag and stores a look-direction vector on the creature, otherwise clears the flag | `ai/behavior/`, `ai/perception/` | 183, 184, 188 | MEDIUM | |
| `cube::RandomInteractionBehavior` | both | idle prop-interaction: on init seeds an idle/cooldown state; tick (per `GAP_ANALYSIS.md`, body not read in full) scans a structure's voxel grid near a candidate position for a solid cell and builds a short candidate-position list, driving a walk-to-and-interact idle action | `ai/behavior/` | 189, 199 | LOW | `vfunc_0` body (500+ lines) not read; role taken from `GAP_ANALYSIS.md`'s HIGH-confidence `findObjectAtPos`/`RandomBehavior_init` summaries only, per the minimum-necessary-read rule |

## 2. Concepts with no single class

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|---|
| `Behavior` base tick/clone interface — no distinct base-class row survived attribution (only the 8 leaves are named types in `cube_types.h`); the interface itself is inferred from the identical `vfunc_0(creature, world, dt[, extra])` / `vfunc_1()` shape repeated across all 8 leaves, plus `SequentialBehavior`'s extra `vfunc_2(delete_flag)` (a scalar-deleting destructor slot, only visible because it owns heap state to release) | every leaf's `vfunc_0`/`vfunc_1` pair; `SequentialBehavior::vfunc_2`/`ctor_2` | `ai/behavior/` (`BehaviorNode` base) | 176, 179, 180, 181 | MEDIUM | 
| No leaf reads as a pure boolean *Condition* — all 8 both test state and mutate the creature (set flags, zero/aim velocity, advance timers) in the same tick call | every leaf `vfunc_0` body | `ai/behavior/` | 179, 180 | LOW — this is an absence-of-evidence claim, not a positive one |
| Shared locomotion/pathing primitives called by nearly every leaf tick, owned by none of them: `NavGraph_findPath`/`NavGraph_reconstructPath`/`NavGraph_expandNeighbors`, `World_getBlockFloat` (ground/solidity probe), the `Vec3i64_*` fixed-point vector helpers, `Creature_resolveSeparation` | present in `WalkPathBehavior`, `SpawnLocationBehavior`, `CompanionBehavior` tick bodies (all three) | `ai/navigation/` | 185 | MEDIUM | cross-ref `matrix-entity.md` §2's locomotion row and its open Q1 (112/128/243) — the same primitives back both "creature moves" and "AI decides to move" |
| Ability/combat timing and resolution math filed under `CombatBehavior` (`Combat_getAbilityCooldown`/`CastTime`/`Recovery`/`ResourceCost`, `Combat_findTopThreatTarget`, `Combat_computeAttackSpeed`, `Combat_sumEquipAttackBonus`, `CombatBehavior::areHostile`/`alertNearbyAllies`) | `server/GAP_ANALYSIS.md` `CombatBehavior (26)` section | `NONE` here — reserved for `matrix-combat.md` (024) | 024 | HIGH (per-function, from GAP) / not ours to place |

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) |
| STL list/map plumbing attributed to `SequentialBehavior` (`ctor_1`/`ctor_2`, `std_List_node_alloc_0xc`) and `CombatBehavior` (`Combat_mapLowerBound`) | hand-rolled `std::list`/`std::map` node allocation and tree-walk glue; a plain GDScript `Array` of `BehaviorNode` children (and a `Dictionary` for threat/cooldown maps) replaces it |
| Client-side copies of all 8 `*Behavior` classes | both binaries carry near-complete, structurally identical bodies (server's `CombatBehavior.cpp` is ~1.9× the client's by line count, everything else near-parity) — read as corroboration for the server-tree reading, not a second authoritative source (`docs/reference/README.md` §2.3). This also reinforces `matrix-world.md` Q2: the client apparently ran the same creature-AI tick locally rather than only presenting replicated state |
| `CombatBehavior`'s ability cooldown/cast/recovery/resource/threat/hostility/alert helpers | combat resolution and derived timing, not an AI decision shape — reserved for `matrix-combat.md` (024), see §1/§2 |

## 4. Open questions

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 | `SequentialBehavior`'s tick stops at the first child that reports "handled" (a priority pick), which reads as a *Selector* despite its decompiled name. Does the Godot `BehaviorNode` tree need both a true `Sequence` (all-must-succeed) and a `Selector` (first-success), or does the reference only ever need the one shape observed here? | 177, 178 | brick 177/178 design note |
| Q2 | `SpawnLocationBehavior` picks an active waypoint group by comparing a stored per-group value against a field read off `world` (`*(int*)(world + 0x80015c)`). No name survived to confirm whether this is a day/night clock, a world tick counter, or something else. | 190, 216 | read `*/world/` clock-bearing fields, or brick 216 (day/night clock) design |
| Q3 | `RandomInteractionBehavior::vfunc_0` (the tick) was not read in full — its role above rests on `GAP_ANALYSIS.md`'s helper-level summaries, not the control flow that calls them. If brick 189/199 needs the actual decision shape (not just "it interacts with something nearby"), the body needs a dedicated read first. | 189, 199 | brick 189 design, if the one-line role proves insufficient |

## 5. Reading budget

| Path | Depth | Left unread |
|---|---|---|
| `server/attribution.tsv` | full (grepped for the 8 class names) | rows for classes outside this group |
| `server/GAP_ANALYSIS.md` | sections `CombatBehavior`, `RandomInteractionBehavior`, `CompanionBehavior` | all other sections (reserved for other matrices) |
| `server/ai/LookAtPlayerBehavior.cpp`, `RandomWalkBehavior.cpp`, `WalkPathBehavior.cpp`, `SpawnLocationBehavior.cpp`, `SequentialBehavior.cpp`, `CompanionBehavior.cpp` | full | — |
| `server/ai/CombatBehavior.cpp` | `vfunc_0` signature/locals header, `vfunc_1` (clone) in full; GAP summaries for the other 26 named functions | the ~1400-line `vfunc_0` body itself |
| `server/ai/RandomInteractionBehavior.h` | full (header only) | `RandomInteractionBehavior.cpp` (773 lines) — role taken from GAP summaries only |
| `server/include/cube_types.h` | grepped for `Behavior` struct placeholders | full file |
| `cube/attribution.tsv`, `cube/GAP_ANALYSIS.md` (`CombatBehavior`, `RandomInteractionBehavior` sections) | skimmed for corroboration + line-count comparison | full client `.cpp` bodies for all 8 classes — not needed, server tree is authoritative for gameplay rules (README §2.3) |
