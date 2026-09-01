# Persistence and save compatibility

Brick 017. Implementation: `core/serialization/save_version.gd`.
Storage layout for voxel data lands with the voxel stream (bricks 048, 102–103). The
per-voxel delta unit §5 describes is `world/terrain/block_edit_delta.gd`
(`BlockEditDelta`, brick 047) — `BlockEditApplicator.apply_capturing_delta()` (046/047)
is the one call site that produces one, right where a voxel write actually happens.
The stream object itself — `world/persistence/voxel_stream_builder.gd`
(`VoxelStreamBuilder`, brick 048, `docs/voxel-tools.md` §13) — is wired for exactly this
"deltas, not full snapshots" shape (`save_generator_output = false`); the on-disk
save-directory layout it plugs into is still open, deferred to bricks 102–103.
`tests/integration/test_voxel_load_save.gd` (brick 049, `docs/voxel-tools.md` §14)
confirms end-to-end that an edit survives a real save/reload round trip through that
stream, while an untouched voxel still comes from the generator, not a stale save.

## 1. Four versions, not one

Every world carries four numbers, and they answer four different questions.

| Number | Question | Bumped when |
|---|---|---|
| `world_format_version` | can this build parse the file at all? | the container layout, field names or encoding change |
| `generation_version` | would newly generated terrain match what is already stored? | any generator, noise constant, or the RNG algorithm changes |
| `data_version` | do the content catalogues still line up? | definitions are added, removed or renamed |
| `seed` | which world is this? | never, for a given world |

Collapsing them into a single "save version" is the mistake this design prevents:
adding one block would then invalidate every save, while a change to the terrain
generator — which genuinely does change what the world looks like — would be
indistinguishable from it.

`engine_version` and `saved_at_unix` also travel in the header. They are **diagnostics
only**: they help a bug report, and nothing may branch on them. A load path that depends
on the wall clock is not reproducible.

## 2. Load verdicts

`SaveVersion.classify()` returns exactly one of:

| Verdict | Meaning | Action |
|---|---|---|
| `CURRENT` | versions match | load |
| `NEEDS_MIGRATION` | older but supported container | run `migration_steps()` in order, then load |
| `TOO_NEW` | written by a newer build | **refuse** |
| `TOO_OLD` | older than this build supports | refuse |
| `GENERATOR_UNAVAILABLE` | container is fine, but that generation algorithm is gone | refuse |
| `MALFORMED` | missing fields or wrong types | refuse |

**A newer save is always refused.** This build cannot know what a future build added;
loading it and writing it back would drop whatever it did not understand. Refusing costs
the player one session — guessing costs them the world.

Every verdict comes with `explain()` text. A player told only "cannot load" deletes the
save.

## 3. Generation version: worlds are never re-generated

A world records the generation version it was created with and **keeps generating with
that version**. It is never silently re-generated under a newer algorithm.

The reason is that a world is only partly generated. If the algorithm changed, terrain
generated tomorrow would not line up with terrain generated today — cliffs cut off
mid-face at the boundary of where the player had already explored, rivers ending at
nothing. A "world" would be two worlds stitched together.

So a build supports a *set* of generation versions. When a version is finally dropped,
worlds that used it stop loading and say so plainly, rather than corrupting themselves.
`classify()` takes the available versions so a build can declare exactly what it still
implements.

## 4. Data version: content drift is normal

Content grows. `data_version` differing is **not** an error and does not block loading;
it tells the loader to validate the IDs it actually finds, resolving anything renamed
through registry aliases (`docs/ids-and-registries.md` §3).

An ID that resolves to nothing is a content problem to report per-entry — one missing
item, not a failed load.

## 5. What gets saved, and what does not

`CLAUDE.md` §11 separates four kinds of state, and they are stored differently:

| Kind | Stored | Why |
|---|---|---|
| Deterministic generated world | **not stored** | it is a pure function of `(seed, coords, generation version)`; storing it would duplicate gigabytes that can be recomputed |
| World modifications | stored as **deltas** | only what a player changed differs from the generator's output |
| Player progression | stored in full | it is not derivable from anything |
| Persistent entities | stored in full | same |

This is why the generation version matters so much: it is not metadata, it is *half the
save*. The deltas are meaningless without the exact terrain they were diffed against.

## 6. Migrations

`migration_steps(from)` returns the ordered list of versions to apply: `[2, 3]` means
run the 1→2 migration, then the 2→3. Each migration is a separate, testable step that
converts one format version to the next — never a single function that tries to
understand every historical layout at once.

Rules:

- A migration only moves **forward**. There is no downgrade path.
- A migration never loses data it does not understand: unknown fields are carried
  through.
- Every migration ships with a fixture of the old format in `tests/fixtures/` and a test
  that migrates it (from brick 102 onward, where real save data exists).
- Back up before migrating in place. A failed migration must leave the original save
  intact.
