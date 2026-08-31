# CubeWorld-Godot

A clean-room **behavioral/structural reimplementation** inspired by Cube World Alpha (2013),
built in Godot with a blocky voxel world and an authoritative client/server core.

This repository contains newly authored code, data and assets. It does **not** redistribute
original proprietary assets, data or trademarks. See `CLAUDE.md` §16.

## Technical baseline

| Item | Value |
|---|---|
| Engine | `Godot 4.7.2.stable.custom_build [ed1daf0bf]` (double-precision editor build) |
| Voxel stack | Voxel Tools `1.7` (engine module) |
| Renderer | Forward+ |
| Physics (3D) | Jolt |
| Scale | `1 voxel = 0.5 m`, `1 m = 2 world units`, Y-up |
| Authority | Server authoritative; clients send intent |
| Generation | Deterministic from `(seed, world coords, generation version)` |

## Repository layout

See `CLAUDE.md` §3 for the authoritative directory contract.

- `autoload/` — global singletons
- `core/` — math, serialization, RNG, time, IDs
- `world/` — terrain, generation, biomes, structures, streaming, persistence
- `gameplay/` — entities, combat, stats, inventory, skills, quests
- `ai/` — behavior, navigation, perception
- `network/` — protocol, packets, replication, authority
- `client/` — presentation, camera, UI, effects
- `server/` — dedicated server entry points and simulation
- `assets/`, `data/`, `tests/`, `docs/`, `tools/`

## Working documents

| File | Purpose |
|---|---|
| `CLAUDE.md` | Development contract / policy |
| `backlog.md` | 266 auditable implementation bricks |
| `nextsteps.md` | Compact session handoff state |
| `docs/` | Architecture, protocol, world generation, RE reference notes |

## Development loop

1. Read `CLAUDE.md`, then `nextsteps.md`.
2. Pick the next unblocked backlog brick.
3. Implement only that brick.
4. Run targeted tests (`tools/` helper scripts).
5. Update `nextsteps.md`, review the diff, commit.

## Reference sources

- Reverse-engineering reference: <https://github.com/qad3n/CubeWorld-Reversal> (behavioral hypotheses only, never a line-by-line port)
- Voxel Tools: <https://github.com/Zylann/godot_voxel>
