# Reference matrix — `combat`

| Field | Value |
|---|---|
| Group | `combat` |
| Backlog brick | `024` |
| Mapped on | `2026-09-01` |
| Sources read | server `attribution.tsv` (grepped `Combat`/`Damage`/`Hit`/`Attack` rows in `game_misc` and `CombatBehavior`); server `GAP_ANALYSIS.md` sections `game_misc` (combat-prefixed rows only), `CombatBehavior` (26, full), `World` (34, `readCombatActionFromStream`/`readHitFromStream` rows only); server `include/cube_types.h` `cube_Creature_offsets`/`cube_BuffNode_offsets` enums (full, VERIFIED-tagged); a ~50-line window of `server/world/World.cpp` around each of the two stream-reader functions (not the surrounding file); client `GAP_ANALYSIS.md` sections `Interface` (6, full) and `CombatBehavior` (6, full) for corroboration; client `attribution.tsv` grepped for the four addresses named in `cube_types.h`'s offset comments (`444db0`, `43ed60`, `447700`, `447310`) |
| Coverage | 0 dedicated combat classes (none exist — see §2); 14 concepts placed |

## 1. Class map

No reference class is named `Combat`, `Damage`, or `Hit`. The only combat-adjacent
*class* is `cube::CombatBehavior`, already mapped in `matrix-ai.md` — its tick shell
(target/ability pick, windup→commit→reset) stays there. Everything in this matrix is
its resolution math plus stat-formula functions physically filed under the client's
`Interface` class and under server `game_misc`/`World` — i.e. concepts, not classes.

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::CombatBehavior` | both | AI decision shell (target pick, timing state machine) | `ai/combat/` | 191, 192, 194, 195 | MEDIUM | see `matrix-ai.md` — cross-ref only, not re-placed here |

## 2. Concepts with no single class

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|:---:|
| Ability timing table (cooldown / cast time / recovery / windup, resource-cost check) | server `Combat_getAbilityCooldown`, `Combat_getAbilityCastTime`, `Combat_getAbilityRecovery`, `Combat_getWindupAndRecovery`, `Combat_canCastAbility`, `Combat_getAbilityResourceCost` (each: `constant / (attackSpeed * this+0x17c)`, per-ability constant tables); `cube_types.h`'s VERIFIED `CUBE_CREATURE_cooldownMap` (`std::map<abilityId, remainingMs>`) | `gameplay/combat/` (attack timing/state machine) | 139 | HIGH (per-function reads) for shape; the per-ability constants are decompiler data, not ours to ship (README §5) |
| Attack-speed / haste computation | server `Combat_computeAttackSpeed` (class/subclass, health ratio, equipment bonus, a buff tag), `Combat_sumEquipAttackBonus`, `Combat_equipSpeedBonus`; client `combat::getEffectiveHaste` (`447700`, base + shield fraction + element buff + rage-form scaling) — corroborates server shape from the other binary | `gameplay/stats/` (derived-stat calculator) | 132, 141 | MEDIUM |
| Base damage formula | client `stat::calcAttackDamage` (`444db0`, MED conf: base `2^` terms, weapon-state multipliers, per-slot element bonuses); `cube_types.h` VERIFIED `CUBE_CREATURE_baseDamage` (f32) and `CUBE_CREATURE_stateFlag` (checked `!=0` by this function) | `gameplay/combat/` (base damage formula) | 141 | MEDIUM (that it's power-of-two multiplicative stacking is corroborated by 3 independent VERIFIED offsets; the exact bases/exponents are not) |
| Max-health formula | server `Combat_computeMaxHealth` (`2^a*2^b*base` with class/mode multipliers and per-equipment-slot bonuses), helpers `pow2Mul`/`pow2MulDiv` | `gameplay/stats/` (health resource) | 133 | HIGH (shape) |
| Armor / mitigation | client `stat::calcArmor` (`43cff0`, base `×2^rand` terms plus 4 per-slot element bonuses) | `gameplay/combat/` (armor mitigation) | 142 | MEDIUM |
| Resist / diminishing-returns factor | server `Combat_getResistFactor` (`1 - 1/(level*0.1+1)` from a resist/level slot, else 1.0) | `gameplay/combat/` (resistance/element model) | 143 | HIGH |
| Ability power/mana cost | client `ability::getManaCost` (per-ability id switch, scaled by a level factor), `ability::getPowerFactor` (`1 - 1/(rank*0.1+1)`, rank from the per-skill-rank table or level) | `gameplay/skills/` or `gameplay/combat/` (no dedicated ability-cast brick yet — see Q3) | — | MEDIUM |
| Resource regen (mana/spirit, stamina) | client `stat::calcManaRegen` (`43ea40`, base `2^` terms `/0.1` plus per-slot rune bonuses); server `Combat_getStaminaRegenRate` (`this+0x17c * factor`, factor chosen from spirit/flag state), `Combat_isSpecialSpiritActive` (gates a special regen state) | `gameplay/stats/` (mana/resource model) | 134, 135 | MEDIUM |
| Equipment-derived stat-bonus plumbing | client `Equipment::sum_slot_values` (sums float contributions per slot by type tag), `Creature::compute_scale_factor` (float scale from status-effect list); server `Combat_equipHealthBonus` (per-slot rarity+type bonus, `2^*5*factor`) | `gameplay/equipment/` (item stat modifiers) | 167 | LOW–MEDIUM (both client functions are `low`-confidence decompiler reads) |
| Threat / target selection | server `Combat_findTopThreatTarget` (walks a threat map, returns highest-score entry); client `combat::findTopThreat` (`444bf0`, corroborating RB-tree walk) and `CombatController::acquireNearbyTargets` (`5a0970`, inserts nearby entities within an 8-unit radius, marks aggro/interest) | `ai/combat/` (target selection rules) | 184, 194 | HIGH (control flow); the threat-score weighting itself is not read |
| Hostility / PvP-duel gate | server `CombatBehavior::areHostile` (faction + dueling/PvP flags); client `CombatBehavior::isHostileTo` (`596ca0`, corroborating: faction byte + a flag bit) | `gameplay/factions/` (faction relationship rules) | 194, 203, 204 | HIGH |
| Aggro alert propagation | server `CombatBehavior::alertNearbyAllies` (iterates nearby creatures, sets an alert flag and enqueues a message for hostile creatures in range), `pushAlertMsg` (capped list append); client `CombatBehavior::pushHitEntry` (`5957c0`, similarly capped list append of a positional record) | `ai/perception/` or `ai/combat/` | 194 | MEDIUM |
| Attack-opcode / animation-state classification | server `Combat_isRangedOrSpecialOpcode`, `Combat_isSpiritChanneling`, `Combat_isMeleeSwingOpcode`, `Combat_isBlockingState`, `Combat_getProjectileSpawnPos`; the two attack-*selection* decision trees `Combat_selectNextAttackAnim`/`Combat_selectSpiritAttackId` were **not** read past their one-line GAP summary (large branchy tables — see Q3) | `gameplay/combat/` (attack timing/state machine, hit detection abstraction) | 138, 139, 140 | MEDIUM for the predicates (HIGH-confidence per GAP); LOW for the two unread selection trees |
| Buff/status-effect list | server `Combat_upsertBuffEntry` (update-in-place or append, capped); `cube_types.h` VERIFIED `cube_BuffNode_offsets` (`type`, `magnitude` f32, `durationMs`) and `CUBE_CREATURE_buffListHead`/`buffCount` | `gameplay/combat/` (status-effect base model) | 146 | HIGH (offsets are VERIFIED, not inferred) |

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) |
| `Combat_mapLowerBound` (server) | hand-rolled `std::map::lower_bound` tree-walk glue backing the threat map; a plain GDScript `Dictionary` replaces the container, not the lookup algorithm |
| Exact numeric constants inside every `Combat_getAbility*`/`calcArmor`/`calcAttackDamage`/`calcManaRegen` table | decompiler-recovered tuning data, not behavior; per `docs/reference/README.md` §5 we record the *shape* (power-of-two multiplicative stacking, diminishing-returns curve) and choose our own numbers when brick 141–144 tune feel |
| `Combat_selectNextAttackAnim`/`Combat_selectSpiritAttackId` bodies | large (100+ line) per-class/per-weapon decision trees, read only via `GAP_ANALYSIS.md`'s one-line summary per the minimum-necessary-read rule (`CLAUDE.md` §4.2) — see Q3 if a later brick needs the actual branch shape |
| Client-side copies of `CombatBehavior`, `Interface`'s stat functions | both binaries carry structurally similar bodies; client `Interface`/`CombatBehavior` sections were read only for corroboration (6 rows each), not as a second authoritative source (`docs/reference/README.md` §2.3) |

## 4. Open questions

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 (RESOLVED — brick 028) | Server `World.cpp` defines `readCombatActionFromStream` (0x28-byte record: 5 ints, 2 bytes, 2 ints, int64) and `readHitFromStream` (0x14-byte record: 2 ints, int, byte, int64), both attributed to `Global` (no owning class) and both called adjacent to `SpeechDb_loadBlobToVector` — i.e. deserializing from a SQLite-loaded blob, not obviously a live network read despite the name. Is this a quest/dialogue-script-embedded combat trigger schema, or does it double as (or prefigure) the wire format for combat event replication? | 136, 137, 249 | `matrix-client-server.md` §2/§4 Q1 (028): a wider read of the call site (`World.cpp:6230-6370`) shows the blob lookup key is built from `"mission"`/`"monster"` string literals plus integer IDs — confirmed quest/mission-scripted trigger data, not a network wire format. Bricks 249/251 must design combat-event replication fresh, with no reference format to reuse. |
| Q2 | The damage/armor/mana formulas share a `2^a * 2^b [/ 2^c]` shape across independent functions in both binaries (`calcAttackDamage`, `calcArmor`, `calcManaRegen`, `Combat_computeMaxHealth`) — confirmed shape, unconfirmed meaning of `a`/`b`/`c` (rarity tier? rune slot? both?). Does brick 141–144's design need to recover that meaning, or is "power-of-two multiplicative stacking, values chosen fresh" sufficient per the clean-room policy? | 141, 142, 143, 144 | brick 141 design note |
| Q3 | `Combat_selectNextAttackAnim` and `Combat_selectSpiritAttackId` (per-class/per-weapon attack-selection decision trees) were not read past their `GAP_ANALYSIS.md` summary. If brick 138/139/192 need the actual selection shape (not just "a decision tree picks the next attack"), the bodies need a dedicated read first. | 138, 139, 192 | brick 138/139 design, if the one-line role proves insufficient |

## 5. Reading budget

| Path | Depth | Left unread |
|---|---|---|
| `server/attribution.tsv` | grepped for `Combat`/`Damage`/`Hit`/`Attack`/`armor`/`resist` | rows for classes outside this group |
| `server/GAP_ANALYSIS.md` | sections `CombatBehavior` (26, full), `World` (34, 2 rows), `game_misc` (105, ~10 combat-prefixed rows) | the ~1400-line `CombatBehavior::vfunc_0` body itself (already flagged unread in `matrix-ai.md`); the remaining ~95 non-combat `game_misc` rows (math/string/XML/nav plumbing, reserved for other matrices) |
| `server/include/cube_types.h` | `cube_Creature_offsets`, `cube_BuffNode_offsets` enums, full | the rest of the struct-offset catalogue (no other enum is combat-relevant) |
| `server/world/World.cpp` | ~50-line window around `readCombatActionFromStream`/`readHitFromStream` only | the surrounding ~6000-line file (a mixed dump of many unrelated functions; reading it in full is out of proportion to two flagged rows — see Q1) |
| `cube/GAP_ANALYSIS.md` | sections `Interface` (6, full), `CombatBehavior` (6, full) | full client `.cpp` bodies — not needed, server tree is authoritative for gameplay rules (README §2.3) |
| `cube/attribution.tsv` | grepped for 4 specific addresses named in `cube_types.h` comments | full file |
