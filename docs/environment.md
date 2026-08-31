# Environment — verified toolchain

> Regenerate the "Verified" block with `tools/check_env.ps1` (brick 007) after any engine change.
> Fingerprints are machine-local facts, not portable guarantees.

## 1. Required baseline (immutable, `CLAUDE.md` §1)

| Item | Required |
|---|---|
| Engine | `Godot 4.7.2.stable.custom_build [ed1daf0bf]` |
| Voxel Tools | `1.7` (engine module, not an addon) |
| Precision | `double` build preferred for large-world testing |
| Renderer | Forward+ |
| 3D physics | Jolt |

## 2. Verified — brick 002

| Field | Value |
|---|---|
| Verified on | 2026-08-31 |
| Host | Windows 11 Pro 10.0.26200 (x86_64) |
| Executable | `C:\Users\Admin\Desktop\godot.windows.editor.double.x86_64.exe` |
| `--version` output | `4.7.2.stable.double.custom_build.ed1daf0bf` |
| SHA-256 | `0E6046F6D8D3B3D5808F84A361594323351AA9EC8F7524A2F0C4A2D1C3158AB7` |
| Size (bytes) | `190416384` |
| Modified (UTC) | `2026-08-20T16:41:08Z` |
| Build type | editor, double precision |

### Version-string mapping

The contract writes the build as `4.7.2.stable.custom_build [ed1daf0bf]`; Godot's own
`--version` prints `<version>.<status>.<precision>.<build>.<commit>`, hence
`4.7.2.stable.double.custom_build.ed1daf0bf`. Same build; the `double` token is the
precision variant `CLAUDE.md` §1 asks us to prefer. **MATCH — verified.**

### Headless load check

`--headless --quit` loads `project.godot` and exits with
`Error: Can't run project: no main scene defined in the project.`
That is the expected state before brick 004 (main scene). It proves the engine
parses the project; it is not an engine fault.

## 3. Fingerprint policy

- The engine lives **outside** the repository; only its fingerprint is committed.
- The absolute path is machine-local. Tooling resolves the engine in this order:
  1. `$env:GODOT_BIN`
  2. `tools/local/godot_path.txt` (gitignored)
  3. the path recorded above
- If `--version` ever stops matching `4.7.2.stable*.custom_build.ed1daf0bf`, stop and
  report a blocker. Do not silently switch engine builds (`CLAUDE.md` §1).
- A SHA-256 change with an unchanged version string means the binary was rebuilt or
  replaced: re-verify the Voxel Tools module (brick 003) before continuing.

## 4. Second engine present on this host

`C:\Users\Admin\AppData\Local\Temp\claude\godot\Godot_v4.7.2-stable_win64.exe` is a stock
single-precision 4.7.2 download in a temp directory. It has **no Voxel Tools module** and is
**not** the project engine. Never use it for this project.

## 5. Voxel Tools

See §"Voxel Tools 1.7" in `docs/voxel-tools.md` (brick 003).
