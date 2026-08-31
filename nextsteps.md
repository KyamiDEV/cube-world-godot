# nextsteps.md — Master session handoff

> Compact durable state for Claude Code. Update after every brick.
> After update: commit when appropriate, then `/clear`.

## Current project state

- Project: CubeWorld-style Alpha 2013 reimplementation
- Engine: `Godot 4.7.2.stable.custom_build [ed1daf0bf]`
- Voxel Tools: `1.7`
- Voxel scale: `1 voxel = 0.5 m`
- Reference repo: `qad3n/CubeWorld-Reversal`
- Editor/runtime MCP: Godot AI by dlight
- Asset MCP: Blender MCP / `bpy`
- Human visual in-game testing: required where marked; screenshots are not required

## Current phase

`A — Bootstrap & repository`

## Current milestone

`M001 — Repository and development contract`

## Current task

`001 — Initialize repository, git, .gitignore, and project metadata`

## Current status

- [ ] Exact custom Godot build verified
- [ ] Voxel Tools 1.7 verified
- [ ] Baseline directory tree created
- [ ] Project opens
- [ ] Test harness runs
- [ ] `CLAUDE.md` installed
- [ ] `nextsteps.md` installed
- [ ] `backlog.md` installed
- [ ] Reverse-engineering reference templates initialized

## Next 10 actions

1. Initialize project metadata and git.
2. Verify exact Godot executable fingerprint.
3. Verify Voxel Tools 1.7 is active.
4. Create directory tree.
5. Implement `WorldScale`.
6. Add CLI validation/test helpers.
7. Add reference-document templates.
8. Run baseline project smoke test.
9. Complete tasks `001–010`.
10. Update this file after every task.

## Working set

At session start read:
- `CLAUDE.md`
- `nextsteps.md`
- only the active backlog row and direct dependency rows
- only files named by the active task
- the corresponding `docs/reference/*.md` when applicable

## Human test state

- Last human playtest: `NOT STARTED`
- Last reported visual issues: `NONE`
- Last reported gameplay issues: `NONE`

## Known risks

- Decompiled behavior can be ambiguous.
- Generation determinism can regress accidentally.
- Networking must be designed before late-stage multiplayer integration.
- Heavy voxel generation should not become a large thread-unsafe GDScript loop.
- Visual similarity is not proof of behavioral parity.

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
