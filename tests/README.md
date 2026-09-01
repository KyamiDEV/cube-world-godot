# `tests/`

| Dir | Contents |
|---|---|
| `unit/` | pure logic and invariant tests |
| `integration/` | multi-system and network tests |
| `fixtures/` | deterministic inputs and golden outputs |

Files in `fixtures/` are **not** test files: the runner only collects `test_*.gd`, so a
fixture is named for its subject (`generation_fixtures.gd`) and declares no `test_*`
method. `tests/unit/test_conventions.gd` enforces both halves.

`generation_fixtures.gd` (brick 059) is the one every Phase D test uses — the named
worlds, the coordinate samples and the determinism checks. Its contract is
`docs/world-generation.md` §4.

Human in-game playtests are policy category C (`CLAUDE.md` §7) and are tracked in
`nextsteps.md`, not here.

## Running

```powershell
tools\scripts\test.ps1                  # everything
tools\scripts\test.ps1 -File log        # only files whose path contains "log"
tools\scripts\test.ps1 -Filter capture  # only test methods containing "capture"
tools\scripts\test.ps1 -Verbose_        # list passing tests too
tools\scripts\test.ps1 -NoImport        # skip the class-cache refresh
```

Exit code 0 means every test passed **and at least one test ran** — a filter that
matches nothing is a failure, not a silent pass.

## Writing a test

A test file is `tests/**/test_*.gd`, extends `TestCase`, and exposes `test_*` methods.

```gdscript
extends TestCase

var _subject: Node

func before_each() -> void:
    _subject = track_node(Node.new())   # freed automatically after the method

func test_something() -> void:
    assert_eq(_subject.get_child_count(), 0, "starts empty")

func test_async_something() -> void:
    await wait_frames(2)
    assert_true(true)
```

Hooks: `before_all`, `before_each`, `after_each`, `after_all`. The runner
instantiates the class **once per file**, so anything a test mutates on a shared
service must be restored in `after_each` or the suite becomes order-dependent.

## Assertions

`assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_almost_eq`,
`assert_null`, `assert_not_null`, `assert_in_range`, `assert_has`, `assert_size`,
`fail`.

Assertions **record** failures and return a bool rather than halting, so one test
reports every problem it finds. Use the return value to skip a follow-up that would
crash: `if not assert_not_null(x): return`.

`assert_eq` is **type-strict**: `1` and `1.0` are equal under GDScript `==`, which
would hide exactly the bug that matters in this project — a float leaking into an
integer voxel coordinate. Compare floats with `assert_almost_eq`.

## Harness notes

- The runner never halts on the first failure; it reports every test, then exits 1.
- **A test that records zero assertions fails.** A GDScript runtime error unwinds the
  method without stopping the runner, so an empty assertion count is the only available
  signal that the body aborted — for instance because a dependency did not compile.
  Reporting it as a pass is how a broken class turns a whole suite green.
- A test file that does not compile is reported as a failing file. `load()` returns a
  resource even for a broken script, so the runner checks `can_instantiate()`.
- Tests may `await`. The runner drives the real main loop, so `wait_frames()` works.
- `class_name` is resolved from `.godot/global_script_class_cache.cfg`, which only a
  project import refreshes. `test.ps1` and `check.ps1` do that automatically; a raw
  `godot --headless --script res://tests/run_tests.gd` after adding a new global class
  will not see it until `godot --headless --import` runs.
