# 0001 — Baseline technical stack and architecture

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-08-31 |
| Backlog bricks | 001–010 |
| Supersedes | — |

## Context

The project reimplements the *behavior* of a 2013 blocky-voxel action-RPG in Godot,
from a reverse-engineering reference rather than from source. Phase A had to fix the
foundations that every later brick depends on: which engine binary, which voxel stack,
what a unit means, who owns gameplay truth, and what has to be reproducible.

Three properties drive everything below:

1. **A large streamed voxel world.** Terrain is generated, meshed, streamed and edited
   continuously; it is the dominant cost and the dominant source of complexity.
2. **Multiplayer is not optional.** Retrofitting authority onto a single-player build
   means rewriting combat, inventory, quests and world edits, so the authority boundary
   has to exist before those systems do.
3. **The reference is a hypothesis, not a specification.** Decompiled logic is
   ambiguous; every subsystem needs room to be re-derived without collapsing the
   architecture.

## Decision

### Engine and voxel stack

Godot `4.7.2.stable.custom_build [ed1daf0bf]`, the **double-precision editor build**,
with **Voxel Tools 1.7 compiled in as an engine module** (verified: `1.7.0`, edition
`Module`). Fingerprint and verification procedure: `docs/environment.md`. Capability
surface: `docs/voxel-tools.md`.

Both are pinned. A build whose `--version` does not match is a hard stop, not a
fallback — `tools/scripts/check.ps1` asserts this before anything else runs.

Renderer Forward+, 3D physics Jolt, physics tick 60 Hz.

Voxel architecture: `VoxelTerrain` + `VoxelMesherBlocky` + a blocky model library,
`VoxelInstancer` for vegetation and props, `VoxelViewer` for streaming interest,
`VoxelStreamSQLite` for voxel persistence, `VoxelBoxMover` only where its blocky
collision model actually fits.

### World scale

`1 voxel = 0.5 m`; `1 m = 2 world units`; Y-up. The conversion lives in one shared
utility (`core/math`, brick 013) and nowhere else — no bare `0.5` or `2.0` in gameplay
code.

Double precision is what makes a large world coordinate space safe at this scale
without a floating-origin scheme, which is why the double build is the target rather
than a convenience.

### Authority

Server-authoritative. Clients send intent; the server validates and resolves. Damage,
inventory results, quest completion, drops, world edits and final movement state are
never taken from a client. Client presentation must be reconstructable from replicated
state.

Consequence enforced from day one: untrusted input is rejected with `Log.check()`,
which logs and returns; only genuine programmer errors use `Log.invariant()`, which
asserts. A malicious client must never be able to halt the server.

### Determinism

World generation is a pure function of `(seed, world coordinates, generation version)`.
Gameplay RNG that affects network-visible outcomes is server-owned and reproducible.
Worlds record seed, generation version, world format version and data version.

### Layering

```text
Definition -> State -> System -> Presentation
                    \-> Replication
                    \-> Persistence
```

Definitions and state are data; systems own the rules; presentation only renders. The
directory tree (brick 005) is the physical expression of this, and brick 011 makes the
import rules explicit.

### Language

GDScript first. The performance policy (`CLAUDE.md` §8) is measure-then-optimize;
heavy generation and meshing work belongs in Voxel Tools' own C++ paths
(`VoxelGeneratorGraph`, `VoxelGeneratorMultipassCB`, the mesher) rather than in large
GDScript loops. Moving a hot path to a module or GDExtension is a later, measured
decision — not an upfront one.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Stock single-precision Godot 4.7.2 | No Voxel Tools module, and single precision limits usable world size. The stock binary present on this machine is explicitly not the project engine. |
| Voxel Tools as a GDExtension | The available build has it as a module; mixing would change class availability and threading behavior for no benefit. |
| `VoxelLodTerrain` + Transvoxel (smooth SDF terrain) | The target look and edit model are blocky. Blocky meshing keeps block identity, per-block gameplay tags and cheap edit semantics; SDF modifiers are irrelevant to a blocky world. LOD terrain stays available if view distance later demands it. |
| `1 voxel = 1 m` | Coarser than the reference look and gives less shaping resolution for terraces and structures. 0.5 m doubles the coordinate range needed, which the double build absorbs. |
| Client-authoritative or peer-to-peer | Cheaper to build, impossible to secure later without rewriting every gameplay system. |
| Single-player first, multiplayer later | Same rewrite risk. The authority boundary is cheap to keep and expensive to add. |
| `VoxelStreamRegionFiles` for persistence | SQLite is available, transactional, and one file per world; region files buy nothing here. |
| Porting decompiled C++ directly | Forbidden by the clean-room discipline (`CLAUDE.md` §16), and the decompiled bodies are pseudo-C that does not build. Behavior is extracted, then reimplemented. |
| A third-party test framework (GUT) | An in-repo runner (brick 008) is ~300 lines, has no version coupling to the custom engine build, and runs headless from one command. |

## Consequences

**Good**

- The environment is verifiable in one command, so "works on my machine" cannot silently
  become the baseline.
- Determinism and authority are constraints the code is written against from the first
  system, not retrofitted.
- Blocky meshing gives block identity for free, which world generation, edits,
  footsteps, mining and structures all need.

**Costs and risks accepted**

- The engine binary is machine-local and unversioned; only its fingerprint is committed.
  A rebuilt binary requires re-verifying the voxel module.
- Double precision costs memory and some throughput. Accepted for world size.
- Server authority adds latency to player-visible actions; prediction and reconciliation
  are real work in Phase K, budgeted rather than avoided.
- Pinning an exact custom build means no engine bug fixes without a deliberate,
  re-verified upgrade.
- GDScript-first accepts a later, measured migration of hot paths rather than an upfront
  language split.

## Revisit if

- Measured meshing or generation throughput at the chosen mesh block size (bricks 052–055)
  cannot hold the frame budget with Voxel Tools' C++ paths — then reconsider the
  GDScript-first decision for that specific path.
- View distance requirements force LOD terrain — then reconsider `VoxelTerrain` versus
  `VoxelLodTerrain`, which changes the mesher and edit model.
- The world size actually shipped fits comfortably in single precision — then the double
  build stops paying for itself.
- Voxel Tools 1.7 proves to have a blocking defect for a required feature — then evaluate
  an upgrade, with `docs/voxel-tools.md` re-verified and this ADR superseded.
