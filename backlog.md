# backlog.md — Master backlog (266 bricks)

> Requested target was ~260 bricks. This backlog intentionally contains **266** auditable bricks; the extra six preserve dedicated-server/reconnect/cleanup work as separate deliverables instead of hiding them in compound tasks.

## Usage
- Work one brick at a time unless the brick itself is a tightly coupled operation.
- Dependencies are prerequisites unless a safe alternative is proven.
- `HUMAN_REQUIRED` means the user must run the game and report behavior; screenshots are not required.
- Reverse-engineering tasks must record evidence + confidence in `docs/reference/*.md`.
- Prefer filesystem/CLI over MCP; use MCP only when editor/runtime state is genuinely required.
- `FOLDED` status: the brick's premise no longer names real, ownable work under the
  architecture the dependencies it waited on actually produced — the fields it would add all
  belong to a later brick that does not exist yet. Rather than implement a hollow version to
  close it, its content is folded into whichever later brick genuinely needs the field, once
  that brick exists (`CLAUDE.md` §6's "avoid silently expanding scope" cuts both ways: adding
  a field nothing reads is scope expansion too). The brick row states where its content went.
  Bricks 068–073 are the first case, `docs/world-generation.md` §13.1.

## Phase map

| Phase | Range | Name |
|---|---:|---|
| A | 001–010 | Bootstrap & repository |
| B | 011–030 | Architecture & reference extraction |
| C | 031–055 | Voxel infrastructure |
| D | 056–090 | World generation |
| E | 091–105 | World streaming & persistence |
| F | 106–130 | Entities & player |
| G | 131–155 | Combat, stats & progression |
| H | 156–175 | Inventory, items, equipment & loot |
| I | 176–210 | AI, NPCs, companions & quests |
| J | 211–230 | Client presentation, UI & audio |
| K | 231–256 | Networking & dedicated server |
| L | 257–266 | Optimization, validation & release |

## Backlog

| ID | Phase | Brick | Dependencies | MCP guidance | Human test | Status |
|---:|:---:|---|---|---|:---:|:---:|
| 001 | A | Initialize repository, git, .gitignore, and project metadata | — | Not needed by default | NO | DONE |
| 002 | A | Verify exact Godot 4.7.2 custom build and record executable fingerprint | 001 | CLI/files only | NO | DONE |
| 003 | A | Verify Voxel Tools 1.7 module is active | 002 | CLI/files only | NO | DONE |
| 004 | A | Create baseline project.godot and main scene | 003 | MCP optional | NO | DONE |
| 005 | A | Create baseline directory tree | 004 | Not needed by default | NO | DONE |
| 006 | A | Install compact development logging and error conventions | 005 | Not needed by default | NO | DONE |
| 007 | A | Create CLI run/check helper scripts | 006 | CLI/files only | NO | DONE |
| 008 | A | Create test harness and first smoke test | 007 | CLI/files only | NO | DONE |
| 009 | A | Create clean-room/reference documentation skeleton | 008 | Not needed by default | NO | DONE |
| 010 | A | Create initial architecture decision record | 009 | Not needed by default | NO | DONE |
| 011 | B | Define domain/state/system/presentation layering rules | 010 | Not needed by default | NO | DONE |
| 012 | B | Define naming, file, class, and ID conventions | 011 | Not needed by default | NO | DONE |
| 013 | B | Define WorldScale and coordinate conversion API | 004 | Not needed by default | NO | DONE |
| 014 | B | Define fixed-step simulation/time contract | 013 | Not needed by default | NO | DONE |
| 015 | B | Define deterministic RNG service contract | 014 | Not needed by default | NO | DONE |
| 016 | B | Define stable ID and registry contract | 015 | Not needed by default | NO | DONE |
| 017 | B | Define save/version compatibility contract | 016 | Not needed by default | NO | DONE |
| 018 | B | Define network command/state/event taxonomy | 017 | Not needed by default | NO | DONE |
| 019 | B | Define server-authority invariants | 018 | Not needed by default | NO | DONE |
| 020 | B | Create reference matrix template for reverse engineering | 011, 018 | Not needed by default | NO | DONE |
| 021 | B | Map CubeWorld world-related classes into conceptual subsystems | 020 | CLI/files only | NO | DONE |
| 022 | B | Map CubeWorld entity/creature-related classes | 021 | Not needed by default | NO | DONE |
| 023 | B | Map CubeWorld AI-related classes | 022 | Not needed by default | NO | DONE |
| 024 | B | Map CubeWorld combat-related classes | 023 | Not needed by default | NO | DONE |
| 025 | B | Map CubeWorld inventory/item/equipment concepts | 024 | Not needed by default | NO | DONE |
| 026 | B | Map CubeWorld quest/NPC concepts | 025 | Not needed by default | NO | DONE |
| 027 | B | Map CubeWorld UI concepts | 026 | Not needed by default | NO | DONE |
| 028 | B | Map CubeWorld client/server split | 027 | Not needed by default | NO | DONE |
| 029 | B | Create confidence/uncertainty recording convention | 028 | Not needed by default | NO | DONE |
| 030 | B | Create traceability index from reference notes to backlog | 029 | Not needed by default | NO | DONE |
| 031 | C | Create voxel block definition schema | 016 | CLI/files only | NO | DONE |
| 032 | C | Create voxel/block registry | 031 | Not needed by default | NO | DONE |
| 033 | C | Create block material property schema | 032 | Not needed by default | NO | DONE |
| 034 | C | Create block collision property schema | 033 | Not needed by default | NO | DONE |
| 035 | C | Create block interaction/destruction property schema | 034 | Not needed by default | NO | DONE |
| 036 | C | Create block footstep/surface tags | 035 | Not needed by default | NO | DONE |
| 037 | C | Create VoxelBlockyLibrary bootstrap | 031 | Not needed by default | NO | DONE |
| 038 | C | Create first grass/dirt/stone block set | 037 | Not needed by default | NO | DONE |
| 039 | C | Configure VoxelTerrain baseline | 009, 038 | Not needed by default | NO | DONE |
| 040 | C | Configure VoxelMesherBlocky baseline | 039 | Not needed by default | NO | DONE |
| 041 | C | Create terrain material/shader baseline | 040 | Not needed by default | NO | DONE |
| 042 | C | Create voxel viewer/interest baseline | 041 | Not needed by default | NO | DONE |
| 043 | C | Create basic block raycast interaction service | 042 | Not needed by default | NO | DONE |
| 044 | C | Create block edit command model | 043 | Not needed by default | NO | DONE |
| 045 | C | Create block edit validation layer | 044 | Not needed by default | NO | DONE |
| 046 | C | Create block edit application layer | 045 | Not needed by default | NO | DONE |
| 047 | C | Create edit undo/delta representation | 046 | Not needed by default | NO | DONE |
| 048 | C | Create initial voxel save stream wiring | 047 | Not needed by default | NO | DONE |
| 049 | C | Create basic voxel load/save integration test | 048 | Not needed by default | NO | DONE |
| 050 | C | Create voxel world bounds/authority policy | 049 | Not needed by default | NO | DONE |
| 051 | C | Create voxel chunk metrics/profiling hooks | 050 | Not needed by default | NO | DONE |
| 052 | C | Benchmark mesh block size 16 | 010, 029 | Not needed by default | NO | DONE |
| 053 | C | Benchmark mesh block size 32 | 052 | Not needed by default | NO | DONE |
| 054 | C | Choose initial mesh block size from measured data | 053 | Not needed by default | NO | DONE |
| 055 | C | Document baseline voxel performance budget | 054 | Not needed by default | NO | DONE |
| 056 | D | Create world seed configuration | 015, 017 | Not needed by default | NO | DONE |
| 057 | D | Create generation versioning | 056 | Not needed by default | NO | DONE |
| 058 | D | Create world coordinate hashing | 057 | Not needed by default | NO | DONE |
| 059 | D | Create deterministic generation test fixtures | 056 | Not needed by default | NO | DONE |
| 060 | D | Create continentalness/noise layer | 059 | Not needed by default | NO | DONE |
| 061 | D | Create elevation field | 058, 060 | Not needed by default | NO | DONE |
| 062 | D | Create erosion/shape pass | 061 | Not needed by default | NO | DONE |
| 063 | D | Create terrace/block-world shaping pass | 061 (in practice 062) | Not needed by default | NO | DONE |
| 064 | D | Create temperature field | 062 | Not needed by default | NO | DONE |
| 065 | D | Create humidity field | 061 | Not needed by default | NO | DONE |
| 066 | D | Create biome classifier | 061 | Not needed by default | NO | DONE |
| 067 | D | Define baseline biome catalog | 065, 066 | Not needed by default | NO | DONE |
| 068 | D | Implement grassland biome — FOLDED into 075 (surface material); owns no field today, `docs/world-generation.md` §13.1 | 064, 067 | Not needed by default | NO | FOLDED |
| 069 | D | Implement forest biome — FOLDED into 075/086-088 (material/vegetation); owns no field today, §13.1 | 068 | Not needed by default | NO | FOLDED |
| 070 | D | Implement desert biome — FOLDED into 075/086-088; owns no field today, §13.1 | 069 | Not needed by default | NO | FOLDED |
| 071 | D | Implement snow biome — FOLDED into 075/085 (snowline); owns no field today, §13.1 | 069 | Not needed by default | NO | FOLDED |
| 072 | D | Implement mountain biome — FOLDED into 075/085; owns no field today, §13.1 | 070 | Not needed by default | NO | FOLDED |
| 073 | D | Implement aquatic/wet biome — FOLDED into 080/083 (waterline/ocean); owns no field today, §13.1 | 071 | Not needed by default | NO | FOLDED |
| 074 | D | Implement biome transition blending | 067 (see §13.1: 068–073 folded, no longer a real dependency chain) | Not needed by default | NO | DONE |
| 075 | D | Implement surface material selection | 073 | Not needed by default | NO | DONE |
| 076 | D | Implement subsurface material rules | 074 | Not needed by default | NO | DONE |
| 077 | D | Implement cave mask | 075 | Not needed by default | NO | DONE |
| 078 | D | Implement cave carving | 076 | Not needed by default | NO | TODO |
| 079 | D | Implement underground material rules | 075, 078 | Not needed by default | NO | TODO |
| 080 | D | Implement water level model | 079 | Not needed by default | NO | TODO |
| 081 | D | Implement rivers | 080 | Not needed by default | NO | TODO |
| 082 | D | Implement lakes | 081 | Not needed by default | NO | TODO |
| 083 | D | Implement ocean/large-water areas | 081, 082 | Not needed by default | NO | TODO |
| 084 | D | Implement shoreline rules | 083 | Not needed by default | NO | TODO |
| 085 | D | Implement snowline rules | 084 | Not needed by default | NO | TODO |
| 086 | D | Implement natural decoration masks | 085 | Not needed by default | NO | TODO |
| 087 | D | Implement tree/vegetation spawn masks | 086 | Not needed by default | NO | TODO |
| 088 | D | Implement rock/prop spawn masks | 087 | Not needed by default | NO | TODO |
| 089 | D | Implement deterministic structure seed selection | 088 | Not needed by default | NO | TODO |
| 090 | D | Implement structure placement constraints | 089 | Not needed by default | NO | TODO |
| 091 | E | Implement initial structure generator | 090 | Not needed by default | YES | TODO |
| 092 | E | Implement initial house generator | 091 | Not needed by default | YES | TODO |
| 093 | E | Implement initial village generator | 092 | Not needed by default | YES | TODO |
| 094 | E | Implement initial dungeon generator | 091 | Not needed by default | YES | TODO |
| 095 | E | Implement spawn-point generation | 094 | Not needed by default | YES | TODO |
| 096 | E | Implement world streaming state machine | 095 | Not needed by default | YES | TODO |
| 097 | E | Implement terrain load priority | 096 | Not needed by default | YES | TODO |
| 098 | E | Implement terrain unload policy | 097 | Not needed by default | YES | TODO |
| 099 | E | Implement visual/collision interest separation | 098 | Not needed by default | YES | TODO |
| 100 | E | Implement player-centered streaming controller | 096, 099 | Not needed by default | YES | TODO |
| 101 | E | Implement server logical interest controller | 100 | Not needed by default | YES | TODO |
| 102 | E | Implement modified-voxel delta persistence | 097, 101 | Not needed by default | YES | TODO |
| 103 | E | Implement world-save metadata | 102 | Not needed by default | YES | TODO |
| 104 | E | Implement persistent world entity store | 103 | Not needed by default | YES | TODO |
| 105 | E | Create world load/reload integration test | 104 | Not needed by default | YES | TODO |
| 106 | F | Create base EntityState | 016 | Not needed by default | YES | TODO |
| 107 | F | Create base EntityDefinition | 016 | Not needed by default | YES | TODO |
| 108 | F | Create server entity registry | 106, 107 | Not needed by default | YES | TODO |
| 109 | F | Create client entity presentation registry | 106, 108 | Not needed by default | YES | TODO |
| 110 | F | Create entity spawn/despawn lifecycle | 109 | Not needed by default | YES | TODO |
| 111 | F | Create transform replication-friendly state | 108 | Not needed by default | YES | TODO |
| 112 | F | Create movement state model | 111 | Not needed by default | YES | TODO |
| 113 | F | Create PlayerState | 111 | Not needed by default | YES | TODO |
| 114 | F | Create PlayerDefinition | 112 | Not needed by default | YES | TODO |
| 115 | F | Create player spawn service | 113, 114 | Not needed by default | YES | TODO |
| 116 | F | Create player controller | 115 | Not needed by default | YES | TODO |
| 117 | F | Create player gravity/jump rules | 115 | Godot MCP optional for editor-side camera inspection | YES | TODO |
| 118 | F | Create player collision integration | 116 | Not needed by default | YES | TODO |
| 119 | F | Create player acceleration/deceleration | 117, 118 | Not needed by default | YES | TODO |
| 120 | F | Create player ground/slope handling | 106, 109 | Not needed by default | YES | TODO |
| 121 | F | Create camera controller | 107, 109 | Not needed by default | YES | TODO |
| 122 | F | Create camera collision/obstruction handling | 120, 121 | Not needed by default | YES | TODO |
| 123 | F | Create interaction target service | 122 | Not needed by default | YES | TODO |
| 124 | F | Create interaction prompt model | 122 | Not needed by default | YES | TODO |
| 125 | F | Create CreatureState | 122 | Not needed by default | YES | TODO |
| 126 | F | Create CreatureDefinition | 125 | Godot MCP optional | YES | TODO |
| 127 | F | Create creature spawn service | 126 | Godot MCP optional | YES | TODO |
| 128 | F | Create creature controller | 115, 127 | Not needed by default | YES | TODO |
| 129 | F | Create NPC state subtype | 119, 128 | Not needed by default | YES | TODO |
| 130 | F | Create companion state subtype | 129 | Not needed by default | YES | TODO |
| 131 | G | Create Stats model | 016 | Not needed by default | NO | TODO |
| 132 | G | Create derived-stat calculator | 131 | Not needed by default | NO | TODO |
| 133 | G | Create health resource | 131 | Not needed by default | NO | TODO |
| 134 | G | Create stamina resource | 131 | Not needed by default | NO | TODO |
| 135 | G | Create mana/resource model | 131 | Not needed by default | NO | TODO |
| 136 | G | Create damage event schema | 131 | Not needed by default | NO | TODO |
| 137 | G | Create hit validation schema | 131 | Not needed by default | NO | TODO |
| 138 | G | Create melee attack command | 136 | Not needed by default | NO | TODO |
| 139 | G | Create attack timing/state machine | 136 | Not needed by default | NO | TODO |
| 140 | G | Create hit detection abstraction | 138 | Not needed by default | NO | TODO |
| 141 | G | Create base damage formula | 139 | Not needed by default | NO | TODO |
| 142 | G | Create armor mitigation | 140 | Not needed by default | NO | TODO |
| 143 | G | Create resistance/element model | 142 | Not needed by default | NO | TODO |
| 144 | G | Create critical-hit model | 143 | Not needed by default | NO | TODO |
| 145 | G | Create knockback model | 144 | Not needed by default | NO | TODO |
| 146 | G | Create status-effect base model | 145 | Not needed by default | NO | TODO |
| 147 | G | Create death state and death event | 146 | Not needed by default | NO | TODO |
| 148 | G | Create respawn state | 144 | Not needed by default | NO | TODO |
| 149 | G | Create server combat resolver | 147 | Not needed by default | NO | TODO |
| 150 | G | Create combat integration tests | 149 | Not needed by default | NO | TODO |
| 151 | G | Create XP event model | 150 | Not needed by default | NO | TODO |
| 152 | G | Create XP progression curve | 151 | Not needed by default | NO | TODO |
| 153 | G | Create level-up pipeline | 152 | Not needed by default | NO | TODO |
| 154 | G | Create stat recalculation on level-up | 153 | Not needed by default | NO | TODO |
| 155 | G | Create gameplay balance data validation | 154 | Not needed by default | NO | TODO |
| 156 | H | Create ItemDefinition | 016 | Not needed by default | NO | TODO |
| 157 | H | Create item registry | 156 | Not needed by default | NO | TODO |
| 158 | H | Create inventory slot schema | 157 | Not needed by default | NO | TODO |
| 159 | H | Create inventory state | 158 | Not needed by default | NO | TODO |
| 160 | H | Create inventory add/remove operations | 159 | Not needed by default | NO | TODO |
| 161 | H | Create inventory stack/merge operations | 160 | Not needed by default | NO | TODO |
| 162 | H | Create inventory split operation | 160 | Not needed by default | NO | TODO |
| 163 | H | Create inventory constraints/validation | 159 | Not needed by default | NO | TODO |
| 164 | H | Create equipment slot schema | 163 | Not needed by default | NO | TODO |
| 165 | H | Create equipment state | 164 | Not needed by default | NO | TODO |
| 166 | H | Create equip/unequip system | 165 | Not needed by default | NO | TODO |
| 167 | H | Create item stat modifiers | 166 | Not needed by default | NO | TODO |
| 168 | H | Create weapon definition | 156 | Not needed by default | NO | TODO |
| 169 | H | Create armor definition | 156 | Not needed by default | NO | TODO |
| 170 | H | Create consumable definition | 169 | Not needed by default | NO | TODO |
| 171 | H | Create item use system | 169 | Not needed by default | NO | TODO |
| 172 | H | Create loot table schema | 156 | Not needed by default | NO | TODO |
| 173 | H | Create loot roll service | 172 | Not needed by default | NO | TODO |
| 174 | H | Create death-drop policy | 173 | Not needed by default | NO | TODO |
| 175 | H | Create inventory/equipment integration tests | 174 | Not needed by default | NO | TODO |
| 176 | I | Create BehaviorNode base | 011 | Not needed by default | NO | TODO |
| 177 | I | Create Sequence node | 176 | Not needed by default | NO | TODO |
| 178 | I | Create Selector node | 176 | Not needed by default | NO | TODO |
| 179 | I | Create Condition node | 176 | Not needed by default | NO | TODO |
| 180 | I | Create Action node | 177 | Not needed by default | NO | TODO |
| 181 | I | Create Decorator node | 177 | Not needed by default | NO | TODO |
| 182 | I | Create AI blackboard/state | 178 | Not needed by default | NO | TODO |
| 183 | I | Create perception target query | 179 | Not needed by default | NO | TODO |
| 184 | I | Create target selection rules | 180 | Not needed by default | NO | TODO |
| 185 | I | Create navigation abstraction | 181 | Not needed by default | NO | TODO |
| 186 | I | Create basic idle behavior | 182 | Not needed by default | NO | TODO |
| 187 | I | Create random-walk behavior | 183 | Not needed by default | NO | TODO |
| 188 | I | Create look-at-player behavior | 184, 186 | Not needed by default | NO | TODO |
| 189 | I | Create random-interaction behavior | 185 | Not needed by default | NO | TODO |
| 190 | I | Create return-home behavior | 187 | Not needed by default | NO | TODO |
| 191 | I | Create combat approach behavior | 190 | Not needed by default | NO | TODO |
| 192 | I | Create attack behavior | 186, 191 | Not needed by default | NO | TODO |
| 193 | I | Create retreat/recovery behavior | 186, 192 | Not needed by default | NO | TODO |
| 194 | I | Create threat/aggro model | 193 | Not needed by default | NO | TODO |
| 195 | I | Create creature combat behavior | 193 | Not needed by default | NO | TODO |
| 196 | I | Create companion behavior | 186 | Not needed by default | NO | TODO |
| 197 | I | Create companion follow behavior | 195 | Not needed by default | NO | TODO |
| 198 | I | Create companion assist-combat behavior | 176, 186 | Not needed by default | NO | TODO |
| 199 | I | Create NPC interaction behavior | 176, 198 | Not needed by default | NO | TODO |
| 200 | I | Create NPC shop service | 199 | Not needed by default | NO | TODO |
| 201 | I | Create dialogue data schema | 016 | Not needed by default | NO | TODO |
| 202 | I | Create dialogue runtime state | 201 | Not needed by default | NO | TODO |
| 203 | I | Create faction definition | 202 | Not needed by default | NO | TODO |
| 204 | I | Create faction relationship rules | 203 | Not needed by default | NO | TODO |
| 205 | I | Create quest definition schema | 204 | Not needed by default | NO | TODO |
| 206 | I | Create quest state | 201, 205 | Not needed by default | NO | TODO |
| 207 | I | Create objective types | 206 | Not needed by default | NO | TODO |
| 208 | I | Create quest objective evaluator | 207 | Not needed by default | NO | TODO |
| 209 | I | Create quest progression service | 207 | Not needed by default | NO | TODO |
| 210 | I | Create quest reward pipeline | 208, 209 | Not needed by default | NO | TODO |
| 211 | J | Create NPC quest provider | 124, 127 | Godot MCP optional for scene inspection | YES | TODO |
| 212 | J | Create player presentation scene | 123 | Godot MCP optional for scene inspection | YES | TODO |
| 213 | J | Create creature presentation scene | 130 | Godot MCP optional for scene inspection | YES | TODO |
| 214 | J | Create block interaction feedback | 129 | Godot MCP optional for scene inspection | YES | TODO |
| 215 | J | Create world ambient presentation hooks | 059, 130 | Godot MCP optional for runtime inspection | YES | TODO |
| 216 | J | Create day/night clock | 215 | Godot MCP optional for runtime inspection | YES | TODO |
| 217 | J | Create time-of-day lighting | 216 | Godot MCP optional for runtime inspection | YES | TODO |
| 218 | J | Create weather state model | 217 | Godot MCP optional for runtime inspection | YES | TODO |
| 219 | J | Create weather presentation | 214 | Godot MCP optional for UI inspection | YES | TODO |
| 220 | J | Create footstep/audio surface mapping | 219 | Godot MCP optional for UI inspection | YES | TODO |
| 221 | J | Create audio event bus | 214 | Not needed by default | YES | TODO |
| 222 | J | Create combat hit effects | 221 | Not needed by default | YES | TODO |
| 223 | J | Create death effects | 222 | Not needed by default | YES | TODO |
| 224 | J | Create inventory UI | 220 | Not needed by default | YES | TODO |
| 225 | J | Create equipment/character UI | 223 | Not needed by default | YES | TODO |
| 226 | J | Create skill UI shell | 211, 219 | Not needed by default | YES | TODO |
| 227 | J | Create quest log UI | 212, 225 | Not needed by default | YES | TODO |
| 228 | J | Create dialogue UI | 219 | Not needed by default | YES | TODO |
| 229 | J | Create map UI shell | 228 | Not needed by default | YES | TODO |
| 230 | J | Create chat UI shell | 229 | Not needed by default | YES | TODO |
| 231 | K | Create settings UI shell | 017 | CLI/files first; MCP not inherently required | NO | TODO |
| 232 | K | Create network transport abstraction | 230 | Not needed by default | NO | TODO |
| 233 | K | Create server bootstrap | 232 | Not needed by default | NO | TODO |
| 234 | K | Create client bootstrap | 233 | Not needed by default | NO | TODO |
| 235 | K | Create connection/session state machine | 234 | Not needed by default | NO | TODO |
| 236 | K | Create authentication/session identity model | 235 | Not needed by default | NO | TODO |
| 237 | K | Create PlayerInput command protocol | 236 | Not needed by default | NO | TODO |
| 238 | K | Create MoveCommand protocol | 237 | Not needed by default | NO | TODO |
| 239 | K | Create AttackCommand protocol | 238 | Not needed by default | NO | TODO |
| 240 | K | Create InteractCommand protocol | 239 | Not needed by default | NO | TODO |
| 241 | K | Create UseItemCommand protocol | 240 | Not needed by default | NO | TODO |
| 242 | K | Create CastSkillCommand protocol | 241 | Not needed by default | NO | TODO |
| 243 | K | Create authoritative movement validation | 242 | Not needed by default | YES | TODO |
| 244 | K | Create entity snapshot schema | 243 | Not needed by default | YES | TODO |
| 245 | K | Create entity interpolation/extrapolation policy | 244 | Not needed by default | YES | TODO |
| 246 | K | Create spawn/despawn replication | 245 | Not needed by default | YES | TODO |
| 247 | K | Create interest management | 246 | Not needed by default | YES | TODO |
| 248 | K | Create world edit replication | 247 | Not needed by default | YES | TODO |
| 249 | K | Create combat event replication | 248 | Not needed by default | YES | TODO |
| 250 | K | Create inventory delta replication | 249 | Not needed by default | YES | TODO |
| 251 | K | Create quest/chat replication | 250 | Not needed by default | YES | TODO |
| 252 | K | Create dedicated-server scene | 251 | Not needed by default | YES | TODO |
| 253 | K | Create headless server configuration | 252 | Not needed by default | YES | TODO |
| 254 | K | Create two-client connection test | 253 | Not needed by default | YES | TODO |
| 255 | K | Create reconnect flow | 254 | Not needed by default | YES | TODO |
| 256 | K | Create disconnect/cleanup flow | 255 | Not needed by default | YES | TODO |
| 257 | L | Profile terrain generation | 251, 256 | Not needed by default | NO | TODO |
| 258 | L | Profile voxel meshing and streaming | 257 | Not needed by default | NO | TODO |
| 259 | L | Profile entity simulation | 258 | Not needed by default | NO | TODO |
| 260 | L | Profile AI update cost | 259 | Not needed by default | NO | TODO |
| 261 | L | Profile network bandwidth and snapshot cadence | 260 | Not needed by default | NO | TODO |
| 262 | L | Optimize hottest measured generation path | 261 | Not needed by default | NO | TODO |
| 263 | L | Optimize hottest measured runtime path | 262 | Not needed by default | NO | TODO |
| 264 | L | Run multiplayer soak test | 263 | Not needed by default | YES | TODO |
| 265 | L | Run persistence/upgrade compatibility test | 264 | Not needed by default | YES | TODO |
| 266 | L | Create release checklist and baseline performance report | 265 | Not needed by default | YES | TODO |

## Milestones

### M001 — Bootstrap complete
Exit: exact engine verified; Voxel Tools active; project opens; baseline tests pass; workflow files installed.

### M002 — Voxel sandbox complete
Exit: block registry; blocky terrain; deterministic edits; load/save smoke test; measured mesh block size.

### M003 — Procedural world baseline
Exit: seed/versioned generation; multiple biomes; caves; water; structures; deterministic fixtures.

### M004 — Playable single-player core
Exit: player movement; entity lifecycle; combat; inventory; equipment; XP/levels.

### M005 — Content systems
Exit: AI; NPCs; dialogue; factions; quests; companions; world structures/dungeons.

### M006 — Client experience
Exit: presentation; day/night; weather; audio; core UI.

### M007 — Multiplayer vertical slice
Exit: dedicated server; two clients; authoritative movement; entity replication; combat/inventory/world-edit replication; reconnect.

### M008 — Release candidate
Exit: profiling; multiplayer soak; persistence compatibility; performance baseline; release checklist.

## Task template

```text
TASK: <ID>

Goal:
Scope:
Dependencies:
Files likely to change:
Tests:
MCP:
Human test:
Acceptance:
Out of scope:

At completion:
- run tests
- inspect git diff
- update nextsteps.md
- update docs/reference if relevant
- mark status
```

## Dependency policy

Do not implement against guessed APIs when a dependency is not complete. If blocked, record the blocker in `nextsteps.md` and keep the active scope narrow.