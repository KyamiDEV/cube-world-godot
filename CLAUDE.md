# CLAUDE.md — CubeWorld Alpha 2013 Reimplementation

## 0. Mission

Build a faithful **behavioral/structural reimplementation** inspired by Cube World Alpha 2013, using:

- Godot `4.7.2.stable.custom_build [ed1daf0bf]`
- Voxel Tools `1.7`
- Godot AI MCP by dlight
- Blender MCP / `bpy` for batch asset generation
- `https://github.com/qad3n/CubeWorld-Reversal` as a reverse-engineering reference

Do **not** port decompiled C++ line-by-line. Treat the reversal repo as a source of behavioral hypotheses, recovered structure, class/function relationships, and subsystem coverage.

## 1. Immutable technical constraints

### Engine
- Exact target: Godot `4.7.2.stable.custom_build [ed1daf0bf]`.
- Exact voxel stack: Voxel Tools `1.7`.
- Prefer the supplied `double` build for large-world testing if the project target requires it.
- Do not silently switch engine versions or Voxel Tools versions.

### World scale
- `1 voxel = 0.5 m`.
- `1 meter = 2 world/voxel units`.
- Y-up.
- All scale conversion belongs in one shared utility. Never scatter `0.5` / `2.0` constants through gameplay code.
- Initial target: LOD0 is 1 voxel per Voxel Tools world unit.

### Authoritative simulation
- Server authoritative for gameplay truth.
- Client sends intent/commands; server validates and resolves.
- Client presentation must be reconstructable from replicated state.
- Never trust client-provided damage, inventory results, quest completion, drops, world edits, or final movement state.

### Determinism
- World generation must be deterministic from `(seed, world coordinates, generation version)`.
- Gameplay RNG that affects network-visible outcomes must be server-owned and reproducible enough for debugging.
- Never use uncontrolled global randomness in world generation.
- Record a generation algorithm version in world metadata.

### Voxel architecture
Default target:
- `VoxelTerrain`
- `VoxelMesherBlocky`
- blocky voxel library/models
- `VoxelInstancer` for vegetation / small props
- `VoxelStreamSQLite` for voxel persistence
- `VoxelViewer` for client streaming/interest
- `VoxelBoxMover` only where its blocky collision model is appropriate

Do not make Voxel Tools responsible for quests, combat, inventory, networking, persistence of player progression, or NPC business logic.

## 2. Architecture rules

Separate:
1. Definitions / data
2. State
3. Systems / simulation
4. Presentation
5. Networking
6. Persistence

Preferred:
```text
Definition -> State -> System -> Presentation
                    \-> Replication
                    \-> Persistence
```

Never put large unrelated subsystems into `Game.gd`, `World.gd`, or a single player script.

## 3. Project structure

```text
res://
├── autoload/
├── core/
│   ├── math/
│   ├── serialization/
│   ├── random/
│   ├── time/
│   └── ids/
├── world/
│   ├── terrain/
│   ├── generation/
│   ├── biomes/
│   ├── regions/
│   ├── zones/
│   ├── structures/
│   ├── dungeons/
│   ├── villages/
│   ├── spawns/
│   ├── persistence/
│   └── streaming/
├── gameplay/
│   ├── entity/
│   ├── player/
│   ├── creature/
│   ├── combat/
│   ├── stats/
│   ├── inventory/
│   ├── equipment/
│   ├── skills/
│   ├── loot/
│   ├── quests/
│   ├── dialogue/
│   ├── factions/
│   ├── companions/
│   └── progression/
├── ai/
│   ├── behavior/
│   ├── navigation/
│   ├── perception/
│   └── combat/
├── network/
│   ├── protocol/
│   ├── packets/
│   ├── replication/
│   ├── authority/
│   ├── client/
│   └── server/
├── client/
│   ├── player/
│   ├── camera/
│   ├── animation/
│   ├── rendering/
│   ├── effects/
│   └── ui/
├── server/
│   ├── main/
│   ├── world/
│   ├── entity/
│   ├── simulation/
│   └── persistence/
├── assets/
├── data/
└── tests/
```

## 4. Reverse-engineering workflow

For every reverse-engineering driven subsystem:
1. Identify relevant class/function cluster.
2. Read only the minimum necessary files.
3. Extract observable behavior, inputs, outputs, state transitions, invariants.
4. Record uncertainties in `docs/reference/*.md`.
5. Assign `HIGH`, `MEDIUM`, or `LOW` confidence.
6. Define a clean Godot contract.
7. Implement an idiomatic equivalent, not a mechanical port.
8. Write targeted tests.
9. Update `nextsteps.md`.

Never treat a decompiler artifact, guessed type, or ambiguous control flow as ground truth.

## 5. Token-efficiency rules

Default to local filesystem, shell, scripts, and direct file edits.

### Godot AI MCP
Use only when editor/runtime/editor-state access is genuinely required:
- editor-only state inspection
- node/property inspection not safely inferable from files
- launching/controlling a specific editor/runtime workflow
- validating scene state after generated changes

Do not use MCP for ordinary `.gd`, `.tscn`, `.tres`, JSON/CSV/YAML generation, refactors, or CLI tests.

### Blender MCP
Prefer one batch `bpy` script over many small MCP calls. Generate asset families in one script and export them as a batch.

### Context management
Start:
1. Read `CLAUDE.md`.
2. Read `nextsteps.md`.
3. Read only active-task files and direct dependencies.
4. Read additional sources only when required.

End:
1. Run targeted tests.
2. Review `git diff`.
3. Update `nextsteps.md`.
4. Commit when appropriate.
5. `/clear`.

Do not create giant chat summaries. Persist durable state in files.

## 6. Task scope

Default: one backlog brick.

Every implementation task should state:
- Goal
- Scope
- Dependencies
- Files likely to change
- Acceptance criteria
- Tests
- MCP requirement
- Human-test requirement

Avoid silently expanding scope.

## 7. Test policy

### A — automated unit/invariant tests
Claude executes.

### B — automated integration/network tests
Claude executes.

### C — human in-game playtest
User executes. No screenshot requirement.

Never claim visual/gameplay parity from logs alone.

## 8. Performance policy

Optimize in this order:
1. world generation
2. voxel meshing
3. streaming
4. entity simulation
5. AI
6. network replication
7. rendering
8. UI

Profile before optimizing. Benchmark at least:
- mesh block size 16
- mesh block size 32
- view distance
- entity counts
- AI update frequency
- network snapshot rates

## 9. Data-driven policy

Prefer data assets/resources/JSON/CSV/YAML where appropriate.

Stable IDs:
- `item.sword.iron`
- `creature.goblin`
- `skill.dash`
- `quest.village_bandits_01`
- `biome.grassland`

Never use unstable display names as primary IDs.

## 10. Asset pipeline

Use reusable `bpy` scripts, normalize origin/scale, keep low-poly/blocky topology deliberate, and batch export.

For VoxelBlocky mesh models:
- origin aligned to lower corner when required
- voxel-cell-compatible dimensions
- preserve exact boundary alignment when culling depends on it

## 11. Persistence

Separate:
- deterministic generated world
- world modifications
- player progression
- persistent entities

Prefer saving modification deltas over duplicating deterministic generated data.

Persist at least:
- seed
- generation version
- world format version
- block-library/data version

## 12. Multiplayer

Protocol separates:
- commands/intent
- authoritative state
- events
- deltas
- snapshots

Examples:
```text
MoveCommand
AttackCommand
InteractCommand
UseItemCommand
CastSkillCommand
```

Server validates commands before applying them. Replicate only what clients need for their interest area.

## 13. Documentation

Durable knowledge:
- `docs/reference/*.md`
- `docs/architecture.md`
- `docs/protocol.md`
- `docs/world-generation.md`
- `nextsteps.md`

`CLAUDE.md` is policy, not a diary.

## 14. Definition of done

A brick is DONE only when:
- implementation exists
- targeted tests pass
- no known regression was introduced
- relevant docs/state are updated
- `nextsteps.md` is updated
- visual playtest is explicitly marked `HUMAN_REQUIRED` when applicable

## 15. Sources

- CubeWorld reverse engineering: https://github.com/qad3n/CubeWorld-Reversal
- Voxel Tools: https://github.com/Zylann/godot_voxel
- Voxel Tools v1.7: https://github.com/Zylann/godot_voxel/releases/tag/v1.7
- Godot AI: https://github.com/hi-godot/godot-ai

## 16. IP / clean-room discipline

Use the reversal repository as a technical/reference source only. Do not assume original proprietary assets, trademarks, or data are licensed for redistribution.

Prefer:
- newly authored assets
- newly authored data
- independently implemented Godot systems
- documented behavioral equivalence

When uncertain, choose the clean-room implementation path.
