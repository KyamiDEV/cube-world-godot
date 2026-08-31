# `core/`

Engine-agnostic foundations with no gameplay knowledge.

| Dir | Owns |
|---|---|
| `math/` | `WorldScale` (1 voxel = 0.5 m), coordinate conversions, geometry helpers |
| `serialization/` | versioned encode/decode primitives |
| `random/` | deterministic RNG service (seeded, reproducible) |
| `time/` | fixed-step simulation clock and tick contract |
| `ids/` | stable string IDs and registry primitives |

`core/` must never import from `gameplay/`, `world/`, `client/`, `server/` or `network/`.
