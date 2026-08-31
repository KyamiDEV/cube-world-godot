# nextsteps.md — Master session handoff

> Compact durable state for Claude Code. Update after every brick.
> After update: commit when appropriate, then `/clear`.

## Current project state

- Project: CubeWorld-style Alpha 2013 reimplementation
- Engine: `4.7.2.stable.double.custom_build.ed1daf0bf` — VERIFIED (`docs/environment.md`)
- Voxel Tools: `1.7.0`, edition `Module` — VERIFIED (`docs/voxel-tools.md`)
- Voxel scale: `1 voxel = 0.5 m` (utility not yet implemented — brick 013)
- Reference repo: `reference/CubeWorld-Reversal` (local, gitignored, `.gdignore`d)
- Git: initialized, `main`, one commit per brick
- Godot AI MCP: server failed to connect this session (`CONNECTION_CLOSED`); not needed so far

## Current phase

`B — Architecture & reference extraction`

## Current milestone

`M002 — Voxel sandbox` (M001 bootstrap: COMPLETE)

## Current task

`011 — Define domain/state/system/presentation layering rules`

## Completed bricks

`001` `002` `003` `004` `005` `006` `007` `008` `009` `010` — Phase A complete.

## Commands

```powershell
tools\scripts\check.ps1      # engine + voxel + full GDScript compile + headless boot
tools\scripts\test.ps1       # headless test suite  (-File / -Filter / -Verbose_ / -NoImport)
tools\scripts\run.ps1        # run the game        (-Headless, game args forwarded past --)
tools\scripts\godot.ps1 -e   # open the editor
```

Last run: `check.ps1` OK · `test.ps1` OK — 2 files, 17 tests, 60 assertions, 0 failed.

## Next 10 actions

1. `011` layering rules → `docs/architecture.md`.
2. `012` naming/file/class/ID conventions.
3. `013` `WorldScale` in `core/math/` + unit tests (the only place `0.5`/`2.0` may appear).
4. `014` fixed-step simulation/time contract.
5. `015` deterministic RNG service contract.
6. `016` stable ID + registry contract.
7. `017` save/version compatibility contract.
8. `018` network command/state/event taxonomy → `docs/protocol.md`.
9. `019` server-authority invariants.
10. `020` reference matrix template (then 021+ start reading the RE tree).

## Working set

At session start read:
- `CLAUDE.md`
- `nextsteps.md`
- only the active backlog row and direct dependency rows
- only files named by the active task
- the corresponding `docs/reference/*.md` when applicable

## Human test state

- Last human playtest: `NOT STARTED` — nothing visual exists yet; the main scene prints a
  boot report to a label. First `HUMAN_REQUIRED` brick is `091`.
- Last reported visual issues: `NONE`
- Last reported gameplay issues: `NONE`

## Technical notes worth keeping

- **Class cache.** Headless `--script` runs read `.godot/global_script_class_cache.cfg`
  but never refresh it, so a new `class_name` is invisible until `godot --headless
  --import` runs. `check.ps1` and `test.ps1` do this; a raw `godot --script` does not.
- **Parse checking.** `load()` returns a resource even for a broken script, so validity is
  decided by `can_instantiate()` (runner) or by parsing a detached `GDScript` copy
  (`check_scripts.gd`). That copy renames its `class_name`, since the real file is already
  registered globally.
- **PowerShell 5.1.** Native stderr becomes ErrorRecords and would abort a script under
  `ErrorActionPreference=Stop`; `Invoke-Godot` relaxes it around the call only.
- **Warnings are errors** for integer division, narrowing conversion and shadowed
  variables (`project.godot [debug]`). Intentional cases need `@warning_ignore_start`.
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

At the end of every task, keep this file to:
- current phase/milestone/task
- completed brick IDs
- next 3–10 actions
- blockers
- changed files
- test result
- human-test result
- only important technical notes

Do not paste large logs here.
