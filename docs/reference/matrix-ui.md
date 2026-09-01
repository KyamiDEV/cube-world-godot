# Reference matrix — `ui`

| Field | Value |
|---|---|
| Group | `UI / Widget classes` |
| Backlog brick | `027` |
| Mapped on | `2026-09-01` |
| Sources read | `cube/ui/*.h` full (24 files, 290 lines — every declaration in the directory); `cube/attribution.tsv` grepped for each of the 23 class names in this directory (function-count survey, no full-file read); `cube/GAP_ANALYSIS.md` full-text grepped for `Widget`/`Interface`/`ScrollSlider`/`Button` plus its dedicated `## AdaptionWidget (28)`, `## ChatWidget (8)`, `## CharacterStyleWidget (6)`, `## Interface (6)`, `## InventoryWidget (2)`, `## OptionsWidget (2)`, `## SpeechWidget (3)`, `## PreviewWidget (1)` sections read in full; `GameController` GAP rows re-grepped for `widget`/`Character List`/`World List`/`tab`/`mouse`/`hover`/`layout` (the UI-input/construction slice, not the whole 620-function class — already partially read in `matrix-items.md`) |
| Coverage | 22 of 24 files placed as `cube::` classes; 2 (`Button`, `ScrollSlider`) are `plasma::` engine classes misfiled into this directory — reclassified to out-of-scope (§3); `cube::WorldPreviewWidget` (deferred from `matrix-world.md`, 021) placed here; `cube::InventoryWidget` (already fully placed in `matrix-items.md`, 025) cross-referenced, not re-placed |

## 1. Class map

Every file in `cube/ui/` is a leaf UI widget with almost no attributed behavior of its
own (most have 1–2 functions: a constructor and one render/input vfunc). The one
exception, `AdaptionWidget` (28 attributed functions), is the shared layout/scroll/
bounds engine every other widget in this directory inherits from — its function count
and every other class's near-empty one are the same observation, not two.

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::AdaptionWidget` | client | shared container/layout base: recursive layout pass, scroll-to-content clamping, content-bounds union, attribute-driven (keyframe) animation, hover/dirty tracking | `client/ui/` (as a design reference for our own Control/Container layer — see §3, Godot's own `Container`/`Control` replace it, we do not port it) | — | MEDIUM (individual functions are GAP `high`/`med`; that this is *the* common base every other widget in the directory inherits is inferred from the function-count skew, not a read class declaration) | — |
| `cube::ChatWidget` | client | chat log panel: clears/appends text, measures and word-wraps chat lines against panel width, binds its transform into the layout tree | `client/ui/` | 230 | MEDIUM–HIGH (3 of 8 attributed functions are GAP `high`, rest `med`) | — |
| `cube::CharacterStyleWidget` | client | character-creation appearance editor: rebuilds/LODs the live preview mesh as style params change, builds its render edge/topology graph | `client/ui/` (creation-screen control) + `client/rendering/` (mesh rebuild) | — | MEDIUM | no backlog brick currently covers a character-creation screen — see §4 Q1 |
| `cube::CharacterWidget` | client | undetermined — only a 3-argument constructor is attributed, no distinguishing behavior recovered | `client/ui/` | — | LOW | same stub pattern as `Sprite`/`SpriteManager` in `matrix-entity.md` §4 Q3 |
| `cube::CharacterPreviewWidget` | client | one grid cell in the character-select screen: renders a saved character's 3-D preview (grid built by `GameController_buildCharacterList`) | `client/ui/` | — | MEDIUM (the class's own 2 functions are unattributed detail; the role comes from the `GameController` builder, GAP `high`) | corroborates `matrix-items.md` §4 Q1 (`GameController` scoping) |
| `cube::EnchantWidget` | client | enchanting panel — stub-only (ctor + 1 vfunc), role by name inference only | `client/ui/` | — | LOW | — |
| `cube::Interface` | client | top-level screen router: dispatches the character-creation, character-stats, merchant/trade, and options-menu screens (`drawCharacterCreation`, `drawCharacterStatsPanel`, `drawMerchantDialog`, `drawOptionsMenu` — named directly, bodies unread per README §2 rule 2) | `client/ui/` | — | MEDIUM (role is a direct name reading, not a body read) | also physically hosts `stat::calcArmor`/`calcManaRegen`/`calcSpirit`/`Equipment::sum_slot_values`/`Creature::compute_scale_factor` — misfiled combat/item formulas, already owned by `matrix-combat.md` §2 and `matrix-items.md`; cross-ref only, not re-placed (same misfiling pattern as `matrix-world.md` §3's combat functions) |
| `cube::MapOverlayWidget` | client | minimap/world-map overlay — stub-only (ctor only) | `client/ui/` | 229 | LOW | — |
| `cube::ObjectiveWidget` | client | quest-objective HUD tracker — stub-only (ctor + 1 vfunc) | `client/ui/` | 227 | LOW | presentation side of `matrix-quests.md`'s polled quest-progress score (§2 there) |
| `cube::OptionsWidget` | client | settings panel: initializes default option values, dispatches input events to child controls | `client/ui/` | 231 | MEDIUM–HIGH (both attributed functions are GAP `high`) | — |
| `cube::PreviewWidget` | client | generic base for a single-object 3-D preview panel (only the destructor is attributed) | `client/ui/` | — | LOW | shares the "preview" pattern with `CharacterPreviewWidget`, `BlueprintPreviewWidget`, `WorldPreviewWidget`, `VoxelWidget` — inferred common role, no base-class declaration read |
| `cube::BlueprintPreviewWidget` | client | preview panel for a blueprint/recipe item — stub-only (ctor + 2 vfuncs) | `client/ui/` | — | LOW | — |
| `cube::SkillWidget` | client | skill/ability panel — stub-only (ctor only) | `client/ui/` | 226 | LOW | — |
| `cube::SpeechWidget` | client | speech-bubble renderer: typewriter-reveal text draw over a `Speech`/`QuestText` node tree, owns its own bounds/anchor rect | `client/ui/` (presentation) — cross-ref `gameplay/dialogue/` (`matrix-entity.md`'s `cube::Speech` row, same underlying tree) | 228 | MEDIUM–HIGH (2 of 3 attributed functions are GAP `high`) | — |
| `cube::SpriteWidget` | client | UI presentation of a `Sprite` entity — stub-only (ctor + 1 vfunc) | `client/ui/` | — | LOW | corroborates, does not resolve, `matrix-entity.md` §4 Q3 (`Sprite`/`SpriteManager` role undetermined) |
| `cube::StartMenuWidget` | client | main-menu/title-screen widget — stub-only (ctor + 1 vfunc) | `client/ui/` | — | LOW | no backlog brick currently covers a main menu / title screen — see §4 Q1 |
| `cube::StatisticsWidget` | client | character-stats display panel — stub-only (ctor + 1 vfunc) | `client/ui/` | — | LOW | likely the widget `Interface::drawCharacterStatsPanel` populates; not confirmed by a read call site |
| `cube::SystemWidget` | client | system overlay (save/quit/settings shortcuts) — stub-only (ctor + 1 vfunc) | `client/ui/` | 231 | LOW | — |
| `cube::VoxelWidget` | client | generic embedded 3-D voxel-model viewport used by the preview widgets — stub-only (ctor + 1 vfunc) | `client/ui/` + `client/rendering/` | — | LOW | inferred from name and directory adjacency to the `*PreviewWidget` classes, not a read body |
| `cube::WorldPreviewWidget` | client | one grid cell in the world-select screen: renders a saved/online world's preview (grid built by `GameController_buildWorldList`) | `client/ui/` | — | MEDIUM (same evidence pattern as `CharacterPreviewWidget`) | deferred from `matrix-world.md` §3 (021); corroborates `matrix-items.md` §4 Q1 |

`cube::InventoryWidget` is not re-placed here — it already has a full row (`client/ui/`,
brick 224, MEDIUM) in `matrix-items.md` §1. That row also already flags that
`GameController`, not `InventoryWidget`, owns the item-grid rebuild/scroll/hover
functions; see §2 below for how that same split shows up across the rest of this
directory.

## 2. Concepts with no single class

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|---|
| Widget event dispatch / focus routing (per-widget-type callback wiring) | `InventoryWidget_dispatchEvent`, `OptionsWidget_dispatchEvent` (both GAP `high`: "recursively walks child widgets, matches focus, fires a `MemberFunctionConnection` callback"), `Widget_connectRecursive`, the repeated `plasma::Widget::MemberFunctionConnection<T>::ctor_0` pattern across `InventoryWidget`/`OptionsWidget`/`CharacterStyleWidget` headers | `client/ui/` (input routing) | 224, 231 | MEDIUM — same dispatch shape confirmed independently on two classes; Godot's own signal system replaces the mechanism outright, this is recorded for completeness only |
| The real UI framework (input hit-testing, focus/hover, widget-tree file deserialization) lives on `GameController`, not on any `Widget` class | `GameController::on_mouse_down`/`on_mouse_up`/`set_hover_widget`/`hittest_if_no_capture`/`get_tooltip_widget` (mouse routing), `GameController::notify_all_widgets`/`cycle_active_tab`/`toggle_widget_*` (widget-tree maintenance), `GameController::load_widget_file`/`deserialize_widget_tree` (loads a `.CUB` widget/scene file and builds the tree at runtime), `GameController_updateWidgetLayout`/`setWidgetBounds`/`getWidgetSize` (thin wrappers around the same `AdaptionWidget` layout primitives placed in §1) | `NONE` for the file-format deserializer (Godot's own `.tscn` replaces a runtime widget-file loader — see §3); `client/ui/` for the input-routing/focus behavior itself | — | MEDIUM (GAP rows are mostly `high`/`med`; role is clear, exact call graph unread) |
| `GameController`'s character-select and world-select screen builders | `GameController_buildCharacterList` (GAP `high`: builds the `CharacterPreviewWidget` grid from saved characters), `GameController_buildWorldList` (GAP `high`: builds the `WorldPreviewWidget` grid, filtering an `'online_'` prefix for multiplayer world entries) | `client/ui/` | — | MEDIUM |

This directory adds a third and fourth data point (after `matrix-items.md`'s inventory-
grid functions and `matrix-quests.md`'s NPC-interaction/quest-text functions) that the
*actual* client UI framework — dispatch, hit-testing, widget-tree construction, screen
building — lives on `cube::GameController`, not on the `Widget` subclasses whose names
the decompiler borrowed for its GAP labels. No new question is opened for this; it is
folded into `matrix-items.md` §4 Q1 as further corroborating evidence.

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) |
| `cube::Button`, `cube::ScrollSlider` (files in `cube/ui/`) | both declare only `plasma::Button::*`/`plasma::ScrollSlider::*` methods — misfiled engine-layer widgets, same "physically adjacent, not the same subsystem" pattern as the combat functions cross-referenced out of `matrix-world.md` §3. `plasma::PopUpButton`/`plasma::ScrollButton` (GAP-visible siblings, no header in this directory) are the same engine class family. Godot's native `Button`/`ScrollBar` replace all four outright. |
| `AdaptionWidget`'s attribute/keyframe animation system (`AnimMap_findValueByKey`, `Widget_updateAnimations`, the `apply_to_attributes`/`apply_attributes_v2` slot walkers) | a generic property-animation engine layer; Godot's `AnimationPlayer`/`Tween` replace it, no gameplay behavior to recover |
| `GameController::load_widget_file`/`deserialize_widget_tree` (`.CUB` widget-file runtime loader) | a custom binary UI-scene format; Godot's own `.tscn` scene format replaces the need for a runtime widget-tree deserializer entirely |
| `stat::calcArmor`/`calcManaRegen`/`calcSpirit`, `Equipment::sum_slot_values`, `Creature::compute_scale_factor` (physically inside `Interface.cpp`) | misfiled combat/item stat formulas — already owned by `matrix-combat.md` §2 / `matrix-items.md`; cross-ref only |
| `cube::InventoryWidget` | already fully placed in `matrix-items.md` §1 (brick 224); cross-ref only, not re-placed here |

## 4. Open questions

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 | Several reference UI screens have no corresponding backlog brick yet: character creation (`Interface::drawCharacterCreation`, `CharacterStyleWidget`, `CharacterPreviewWidget`), the main menu/title screen (`StartMenuWidget`), and the merchant/trade dialog (`Interface::drawMerchantDialog`, distinct from the already-planned brick 200 "NPC shop service" gameplay logic). Does phase J/K need new bricks for these, or are they folded into existing ones (e.g. character creation into whatever brick creates the player entity, 116–123)? | phase J/K planning | a scoping pass over phase J before UI bricks 224–231 start |
| Q2 (RESOLVED — brick 028) | `GameController`'s widget-framework slice (mouse routing, hover/focus, `notify_all_widgets`, widget-file deserialization) keeps growing across three matrices now (`matrix-items.md`, `matrix-quests.md`, here) with no owning matrix or brick. Should `matrix-client-server.md` (028) absorb a `GameController` scoping section, or does it need a dedicated brick inserted before 224? | 224–231, 028 | `matrix-client-server.md` §4 Q2 (028) — same resolution as `matrix-items.md` §4 Q1: no dedicated matrix or brick, functions split by behaviour across the matrices that already own them. |

## 5. Reading budget

| Path | Depth | Left unread |
|---|---|---|
| `cube/ui/*.h` | full, all 24 files (290 lines) | — |
| `cube/attribution.tsv` | grepped per class name (function-count survey only) | full per-function rows outside the counted classes |
| `cube/GAP_ANALYSIS.md` | full-text grepped `Widget`/`Interface`/`ScrollSlider`/`Button`; `## AdaptionWidget (28)`, `## ChatWidget (8)`, `## CharacterStyleWidget (6)`, `## Interface (6)`, `## InventoryWidget (2)`, `## OptionsWidget (2)`, `## SpeechWidget (3)`, `## PreviewWidget (1)` sections read in full | the `GameController` section's remaining ~600 rows outside the widget/mouse/tab/layout grep; no `.cpp` body was read for any class in this directory |
| `cube/GAP_ANALYSIS.md` `## GameController` section | grepped `widget`/`Character List`/`World List`/`tab`/`mouse`/`hover`/`layout` (~25 additional rows beyond what `matrix-items.md`/`matrix-quests.md` already pulled) | the remainder of the ~620-function class |
| `cube/include/cube_types.h` | not grepped this brick — no widget struct offsets were needed for a role-only survey | full struct-offset catalogue |
