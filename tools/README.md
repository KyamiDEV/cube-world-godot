# `tools/`

Developer tooling that is not shipped game code.

| Dir | Contents |
|---|---|
| `probe/` | headless GDScript probes run via `--script` |
| `scripts/` | PowerShell entry points |
| `local/` | machine-local overrides (gitignored) |

## Commands

| Command | Does |
|---|---|
| `tools\scripts\check.ps1` | engine build + Voxel Tools + full GDScript compile + headless boot. **Run before every commit.** |
| `tools\scripts\run.ps1 [-Headless] [game args…]` | verifies the engine build, then runs the main scene |
| `tools\scripts\godot.ps1 <args…>` | raw pass-through to the contracted engine (`-e` opens the editor) |

Game arguments after `run.ps1` are forwarded past `--`, so logging flags work:

```powershell
tools\scripts\run.ps1 --log-level=debug --log=gen:trace
tools\scripts\run.ps1 -Headless
```

## Engine resolution

`$env:GODOT_BIN` → `tools/local/godot_path.txt` → the path recorded in
`docs/environment.md`. The build fingerprint is asserted before anything runs;
a mismatch is a hard stop, never a silent fallback (`CLAUDE.md` §1).

To point the tools at a different copy of the same build:

```powershell
"D:\godot\godot.windows.editor.double.x86_64.exe" | Set-Content tools\local\godot_path.txt
```

## Probes

| Probe | Asserts |
|---|---|
| `probe/probe_voxel.gd` | Voxel Tools version 1.7, `Module` edition, 16 required classes |
| `probe/check_scripts.gd` | every project `.gd` compiles, warnings-as-errors included |

`check_scripts.gd` compiles each file as a detached `GDScript` object rather than
reloading it in place: reloading a script that already has live instances (the
`Log` autoload) fails for reasons unrelated to whether the file is valid. The
trade-off is that it validates files individually — it does not catch a duplicate
`class_name` registration across two files. The editor and `check.ps1`'s headless
boot step catch that.
