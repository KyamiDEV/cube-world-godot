# nextsteps.md — Master session handoff

> Compact durable state for Claude Code. Update after every brick.
> After update: commit when appropriate, then `/clear`.

## Current project state

- Project: CubeWorld-style Alpha 2013 reimplementation
- Engine: `4.7.2.stable.double.custom_build.ed1daf0bf` — VERIFIED (`docs/environment.md`)
- Voxel Tools: `1.7.0`, edition `Module` — VERIFIED (`docs/voxel-tools.md`)
- Voxel scale: `1 voxel = 0.5 m` — implemented in `core/math/world_scale.gd`
- Reference repo: `reference/CubeWorld-Reversal` (local, gitignored, `.gdignore`d). Read so
  far: the class-mapping pass of 021–028, plus targeted full reads for 058
  (`region-coordinate-hashing.md`), 060 (`terrain-value-noise.md`), 061
  (`terrain-base-height-field.md`), 064 (`terrain-climate-blend.md`, re-read by
  065 and unchanged in its claims) and 067 (a targeted read of
  `WorldInfo_generateBiomeContent` plus a `biome` sweep of the headers/GAP analysis —
  finding: the original has **no** biome catalog at all, only a continuous colour,
  `docs/world-generation.md` §12.5).
  `docs/reference/traceability.md` is the index.
- Git: `main`, one commit per brick, **intact from brick 001** — and the "history is
  gone" note carried by bricks 065–067 was **wrong**. The working copy had lost its
  `.git`, but the real per-brick history was on GitHub the whole time
  (`github.com/KyamiDEV/cube-world-godot`, at brick 064). Brick 067's push recovered it:
  the local single-commit baseline was discarded and bricks 065, 066 and 067 were
  replayed on top of the remote's brick-064 head, so the published history is one commit
  per brick with no gap. `origin` is now configured; `reference/` and `.godot/` are
  untracked by `.gitignore`, and the `reference/` exclusion is `CLAUDE.md` §16's IP
  discipline, so it stays untracked. **Before assuming history is missing again, fetch
  `origin` first.**
- Godot AI MCP: failed to connect this session (`CONNECTION_CLOSED`); not needed so far

## Current phase / milestone / task

- Phase `B — Architecture & reference extraction` — **COMPLETE** (011–030)
- Phase `C — Voxel infrastructure` — **COMPLETE** (031–055)
- Milestone `M002 — Voxel sandbox` — exit criteria met (block registry; blocky terrain;
  deterministic edits; load/save smoke test; measured mesh block size + budget)
- Phase `D — World generation` — **IN PROGRESS** (056–067, 074–090 done; 068–073 FOLDED
  (`backlog.md`, `docs/world-generation.md` §13.1)). **Phase D is complete** — 090 is the
  last Phase D row; 091 opens Phase E.
- Next task `091 — Implement initial structure generator`, dep `090` in `backlog.md`, now
  DONE. **This is the first `HUMAN_REQUIRED` brick** and the first `VoxelGenerator`/
  `VoxelBuffer` write in the project — the "first voxel written" boundary every Phase D
  brick since 062 has named. Reading it pins as generation inputs: `WorldSeed`/version
  handling aside, every constant and salt `SurfaceMaterial` (§14.4), `StructureSeedField`
  (§28.6) and `StructurePlacement` (§29.7) named — `SALT_STRUCTURES`, the 089 draw order,
  the 512 m region pitch, `PRESENCE_CHANCE`, `MIN_STRUCTURE_SPACING_VOXELS`, the slope
  thresholds, the `"structure.placement.presence"` fork key. 091 reads
  `StructurePlacement.for_world(hash, biomes, blocks).seed_at(region)` — non-null means a
  structure stands there; `.anchor_column` is where, `.rng()` is the owned stream for its
  kind/rotation/size. `VoxelGeneratorMultipassCB` (1.7) is the route for a structure
  spanning chunks. The `objectFalloffWeight` relief flattening under a placed structure is
  091's (`docs/world-generation.md` §29.3/§29.8), joining `ErosionPass`'s product as one
  more `[0, 1]` factor (§7.1).

## Completed bricks

`001`–`067`, `074`–`090`. `068`–`073` **FOLDED** (`backlog.md`, §13.1 below — each owned no
field under the architecture 067 built; content folded into 075–076/080/085–088, no field
invented to give any of the six something to do). Phase A complete; Phase B complete
(011–020 contracts; 021–028 reference
tree mapping, all 8 matrices; 029 confidence/uncertainty convention; 030 traceability
index); Phase C complete (031 block definition schema, 032 block registry, 033
material property schema, 034 collision property schema, 035 interaction/destruction
property schema, 036 footstep/surface tag, 037 `VoxelBlockyLibrary` bootstrap, 038 first
grass/dirt/stone block set, 039 `VoxelTerrain` baseline, 040 `VoxelMesherBlocky`
baseline, 041 terrain material/shader baseline, 042 `VoxelViewer`/interest baseline, 043
block raycast interaction service, 044 block edit command model, 045 block edit
validation layer, 046 block edit application layer, 047 edit undo/delta representation,
048 initial voxel save stream wiring, 049 voxel load/save integration test, 050 voxel
world bounds/authority policy, 051 voxel chunk metrics/profiling hooks, 052 mesh block
size 16 benchmark, 053 mesh block size 32 benchmark, 054 mesh block size decision, 055
baseline voxel performance budget). **Phase C complete — milestone M002 exit criteria met.**
Phase D open: 056 world seed configuration, 057 generation versioning, 058 world
coordinate hashing, 059 deterministic generation test fixtures, 060 continentalness/noise
layer, 061 elevation field, 062 erosion/shape pass, 063 terrace/block-world shaping pass,
064 temperature field, 065 humidity field, 066 biome classifier, 067 baseline biome catalog,
074 biome transition blending, 075 surface material selection, 076 subsurface material
rules, 077 cave mask, 078 cave carving, 079 underground material rules, 080 water level
model, 081 rivers, 082 lakes, 083 ocean/large-water areas, 084 shoreline rules, 085 snowline
rules, 086 natural decoration masks, 087 tree spawn masks, 088 rock/prop spawn masks,
089 deterministic structure seed selection, 090 structure placement constraints
(068–073 folded — see below). **Phase D complete.**

`090` is one new file, `world/structures/structure_placement.gd` (`StructurePlacement`),
composing `StructureSeedField` (089), `DecorationMask` (086) and `TerracePass` (063) into a
single `is_placed_at(region) -> bool` over four gates, plus `seed_at(region)` — the 089
record returned only where a structure is real. No new file for a value record (091 reads
089's `StructureSeed` directly), no `BiomeDefinition` field, no new salt, no `data/` change.

The four gates and the reference function each stands in for (`matrix-world.md` §2, MEDIUM,
no helper body opened):

1. **presence** (`World_featureCountRange`/`featureTier`) — 089's one candidate kept with
   `PRESENCE_CHANCE` (0.4), rolled from `StructureSeed.rng().derive_named(
   "structure.placement.presence")` — a fork of 089's owned sub-seed, so 089's region
   stream stays at exactly 3 draws (§28.4) and 091's `rng()` is byte-identical whether or
   not 090 rolled. `test_the_presence_roll_leaves_089_streams_untouched` pins it.
2. **eligible** — `DecorationMask.is_eligible_at(anchor)`: the identical wet/shoreline
   exclusion 087/088 reuse. Adds nothing.
3. **slope** — `TerracePass.surface_y()` at the anchor and 8 points 16 voxels out (a 16 m
   pad) must span ≤ one terrace (8 voxels). The *inverse* of `objectFalloffWeight` (which
   flattens near a structure — deferred to 091, §29.3). No footprint assumed (090 has none).
4. **spacing** (`findNearestFeatureCell`/`falloffSquared`) — refused when a higher-ranked
   candidate in one of the 8 Moore-neighbour regions clears gates 1–3 within
   `MIN_STRUCTURE_SPACING_VOXELS` (768 voxels = 384 m). Rank = `structure_seed` unsigned,
   region coords as tiebreak — a total order, no visit-order dependence. The neighbour test
   consults gates 1–3 only (never gate 4), so **no recursion**. Because 768 < `REGION_SIZE`
   (1024) and two anchors two regions apart are ≥ 1025 voxels apart, the guarantee is
   **world-wide**: no two placed structures are ever within 384 m. `self_check()` asserts
   the `< REGION_SIZE` bound.

**Biome suitability is deliberately not a biome-record read** — the same call 087 (§26.6)
and 088 (§27.3) made about ruggedness: a lake is refused by gate 2, a rugged mountainside by
gate 3, and a `BiomeDefinition.hosts_structures` flag nothing else reads would be the
"record grows, nothing reads it" shape 067 named five times and 068–073 were folded to
avoid. `docs/world-generation.md` §29.4.

Measured (1600-region sweep, `typed`): presence keeps 0.400, eligibility 0.541, the slope
gate 0.996 (the erosion pass makes flat the default, §7.2 — the gate is decisive only at the
~0.4% of anchors on a genuine step; kept for those and a future retune), gates 2+3 together
0.539, **placed 0.182** — one structure roughly every 1.35 km, a landmark density.

Not a generation version bump: no world has ever had a voxel written; no new salt, no new
`GenerationHash.Space`. `PRESENCE_CHANCE`, the probe/relief/spacing constants, the priority
order and the fork key all become pinned generation inputs the moment 091's `VoxelGenerator`
reads `is_placed_at()`. `docs/world-generation.md` §29.7.

Docs: `docs/world-generation.md` §29 (new, eight subsections); `docs/reference/
traceability.md` — the 089–090 row updated to "both halves done". Tests:
`tests/unit/test_structure_placement.gd` (new, 19 tests; golden `is_placed_at` signature
over `GenerationFixtures.regions()` on `typed`: `b9ad87009d76e75b`). A scratch measurement
file was used to pin the §29.6 fractions, then deleted (087/088 precedent). Full suite:
`files=64 tests=958 assertions=142073 failed=0`. Compile probe OK (134 scripts). Headless
boot OK.

`089` is the `DecorationMask` cell-and-hash mechanism one grid coarser: two new files under
`world/structures/` — `structure_seed.gd` (`StructureSeed`, a value record: `region`,
`anchor_column`, `structure_seed`, plus `rng()` and `validate()`) and
`structure_seed_field.gd` (`StructureSeedField.for_world(hash)` — takes only a
`GenerationHash`, no biome/block registry). `seed_at(region)` draws from
`GenerationHash.rng_region(region, WorldHash.SALT_STRUCTURES)` in a fixed order — anchor X
offset, anchor Z offset, then one `next_u64()` sub-seed — and returns one `StructureSeed`
per in-world region, `null` outside `GenerationGrid.is_region_in_world()` (the reference's
`INV-2`, the first *use* of that check). `seed_for_column()` / `seed_for_voxel()` resolve
the containing region.

Deliberately minimal: **exactly one seed per region, no rarity gate, no terrain/biome/climate
read.** Whether a structure actually stands at the anchor — presence, slope/water/biome
suitability, spacing, falloff — is 090's whole job; folding a presence roll in here would be
`DecorationMask` deciding snow cover (which it refused). The anchor *jitter* is here and not
in 090 because a corner-anchored structure tiles the world with a 512 m lattice and the
jitter must be fixed before 090 can ask "is this ground buildable".

Reference: `docs/reference/region-coordinate-hashing.md` — the "one reproducible seed per
region cell on a 1024×1024 grid" shape kept, the linear `srand(regX+regZ*0x400+...)` seed and
process-global `rand()` dropped (already resolved by `rng_region()`, 058, §9 of that note).

Not a generation version bump: `WorldHash.SALT_STRUCTURES` (7) reserved since brick 015 and
unread until now; `GenerationHash.Space.REGION` and `rng_region()` already existed (its
docstring already named bricks 089–090). The salt, the draw order and the region pitch become
pinned generation inputs when 091's `VoxelGenerator` reads a `StructureSeed`.
`docs/world-generation.md` §28.6.

Docs: `docs/world-generation.md` §28 (new, seven subsections); `docs/reference/traceability.md`
§2 region-site row annotated "089's half done". Tests: `tests/unit/test_structure_seed.gd`
(new, 8 tests) and `tests/unit/test_structure_seed_field.gd` (new, 14 tests — determinism,
seed sensitivity, anchor-in-region, jitter varies over a 256-region sweep, sub-seed
independent of the anchor draws and of east-neighbour regions, two golden signatures over
`GenerationFixtures.regions()`: anchor `3d68a17ff4f752f0`, sub-seed `16945661f5c05b64`).
No scratch sweep needed — all fixtures are region coordinates, not swept columns.

`088` is `TreeMask` (087) one pass over: one new file, `world/generation/rock_mask.gd`
(`RockMask`), composing `DecorationMask` (086) and `SurfaceMaterial` (075) into
`is_rock_at(column) -> bool`, plus one new field, `BiomeDefinition.prop_density` (shipped:
mountain `0.03`, desert `0.012`, grassland `0.005`, forest `0.004`, snow `0.003`, wetland
`0.0015` — every biome positive, mountain the densest). Salt `WorldHash.SALT_PROPS` (6,
reserved since brick 015, unread until now).

Two deliberate divergences from `TreeMask`, both recorded in `docs/world-generation.md`
§27.2–§27.3:

1. **No snow exclusion.** `TreeMask` reads `SnowlineMaterial` and refuses a snow-capped
   column (a treeline stops below a cold summit); a rock line does not — boulders sit on
   and above the snow. So `RockMask` never builds or reads `SnowlineMaterial`; it composes
   `DecorationMask` + `SurfaceMaterial` only. `DecorationMask`'s water/shoreline exclusion
   still applies. `test_snow_cover_does_not_exclude_a_rock` pins it: at a genuinely
   snow-covered column `RockMask`'s answer has no altitude term while `TreeMask`'s is
   `false` purely for the snow.
2. **Ruggedness turned up, not gated.** The `nextsteps` note flagged that a mountain biome
   plausibly wants *more* rocks. Answer: no `ErosionPass.ruggedness_at()` gate (§26.6's
   reasoning — a rugged column already classifies to `biome.mountain`), but `mountain`
   ships the *highest* `prop_density`, not `0.0` like its `vegetation_density`. The
   rockiness a ruggedness gate would add is expressed through the biome the ruggedness
   already produced.

Every biome positive means `is_rock_at()`'s `spacing > 0` cheap gate almost never fires
with the shipped catalog (unlike trees, where it short-circuits ~half of every column). It
is kept anyway — a future biome may ship `0.0`, and a test's hand-built registry does.

Not a generation version bump: no world has ever had a voxel written; `SALT_PROPS` was
already the salt `DecorationMask` named for this brick. `docs/world-generation.md` §27.6.

Docs: `docs/world-generation.md` §27 (new, seven subsections). Tests: `tests/unit/
test_rock_mask.gd` (new, 21 tests, 117 assertions — includes `test_a_rock_anchor_and_a_tree
_anchor_are_independent` verifying the two salts diverge, and
`test_mountain_reads_visibly_rockier_than_grassland` measuring the ordering over the wide
sweep); `tests/unit/test_biome_definition.gd` and `test_biome_catalog.gd` extended for the
new `prop_density` field, its `validate()` and its shipped ordering. Full suite:
`files=61 tests=917 assertions=127883 failed=0`. Compile probe OK (128 scripts). Headless
boot OK. Scratch sweep (`test_zzz_scratch_rock_mask.gd`) used to pin `KNOWN_ROCK_COLUMN` /
`KNOWN_NON_ROCK_COLUMN`, then deleted (087's precedent).

`087` is the biome-aware layer `086`'s own class comment left open: one new file,
`world/generation/tree_mask.gd` (`TreeMask`), composing `DecorationMask` (086),
`SurfaceMaterial` (075) and `SnowlineMaterial` (085) into `is_tree_at(column) -> bool`, plus
one new field, `BiomeDefinition.vegetation_density` (shipped: forest `0.04`, wetland `0.01`,
grassland `0.0025`, desert/mountain/snow `0.0`).

```text
spacing_at(column) = DecorationMask.spacing_for_density(
                          biome_registry.get_biome(SurfaceMaterial.biome_id_at(column))
                              .vegetation_density)

is_tree_at(column) = spacing_at(column) > 0
                      and not SnowlineMaterial.is_snow_covered_at(column)
                      and DecorationMask.is_decoration_anchor_at(
                              column, spacing_at(column), WorldHash.SALT_TREES)
```

Three things worth keeping:

1. **Density is read through `SurfaceMaterial.biome_id_at()`, not `BiomeClassifier.at()`
   directly** — the same dithered pick `SubsurfaceMaterial` (076) already reads, so a
   column's tree density always agrees with whichever biome's ground it actually stands on,
   including salt-and-pepper edge columns.
2. **The zero-density gate runs before either `SnowlineMaterial` or `DecorationMask`.** Three
   of six shipped biomes ship `vegetation_density = 0.0`; a `0` spacing short-circuits
   `is_tree_at()` before either heavier read runs, `CaveCarving.is_hollow_at()`'s (078)
   cheap-gate-first ordering.
3. **Snow cover is the exclusion `086`'s own class comment named and deliberately did not
   decide.** `SnowlineMaterial.is_snow_covered_at()` (085) is read after the density gate and
   before the anchor hash, so a snow-capped forest column never reaches `DecorationMask` at
   all — no wasted hash, no anchor reserved at a column this file is about to refuse anyway.

Not a generation version bump: no world has ever had a voxel written, and this brick mixes no
new salt or `GenerationHash` space of its own — `WorldHash.SALT_TREES` (reserved since brick
015) was already the salt `DecorationMask` (086) named for this brick. `docs/world-generation
.md` §26.5.

One real bug caught before it shipped: the first version of
`test_forest_reads_visibly_denser_than_grassland` sampled a fixed 200x200-column patch at this
file's own `SWEEP_ORIGIN` fixture constant, unchecked. That patch turned out to be entirely
inside a lake — `DecorationMask.is_eligible_at()` false on every column — so both fractions
measured `0.0` and the property the test exists to check went untested, only surfacing as a
hard `FAIL` (`forest fraction nan must exceed grassland fraction nan`) once run. Fixed by a
design-time sweep (ASCII-mapped `biome_id_at()`/`is_eligible_at()` over a wide area) for a
real origin with dry forest and grassland both present; `docs/world-generation.md` §26.4
records the finding. Lesson for 088 (rock/prop masks) and any later brick that pins a sample
coordinate: sweep and check what is actually there before trusting a "nearby" or reused
origin constant — this world's biome/water layout dithers at column granularity and a
sizeable fraction of the map is open water.

Docs: `docs/world-generation.md` §26 (new, six subsections). Tests: `tests/unit/
test_tree_mask.gd` (new, 19 tests, 87 assertions); `tests/unit/test_biome_definition.gd` and
`tests/unit/test_biome_catalog.gd` extended for the new `vegetation_density` field and its
`validate()`/ordering checks. Full suite: `files=60 tests=889 assertions=127735 failed=0`.
Compile probe OK (126 scripts). Headless boot OK.

`086` is the mechanism `matrix-world.md` §2 named in advance and left at LOW confidence: one
new file, `world/generation/decoration_mask.gd` (`DecorationMask`), plus two small additions
to `world/generation/generation_hash.gd` (`GenerationHash`) — a new `Space.DECORATION_CELL`
enum entry and `rng_decoration_cell(cell, salt)`. No biome, no climate grid, no specific
decoration content: 087 (trees) and 088 (rocks) each spend their own density and candidate
list on top of this.

```text
is_eligible_at(column)                     = not (ShorelineMaterial.is_water_at(column)
                                                   or ShorelineMaterial.is_shoreline_at(column))

spacing_for_density(density_per_column)    = max(1, round(1 / sqrt(density_per_column)))
cell_of(column, spacing)                   = floor(column / spacing)     -- per axis
anchor_column_in_cell(cell, spacing, salt) = the one column the cell's own RNG stream picks
is_anchor_at(column, spacing, salt)        = anchor_column_in_cell(cell_of(column, spacing),
                                                   spacing, salt) == column

is_decoration_anchor_at(column, spacing, salt) = is_eligible_at(column)
                                                   and is_anchor_at(column, spacing, salt)
```

Four things worth keeping:

1. **The one reference function (`WorldInfo_scatterObjectsInArea`, `0x005f56c0`) describes an
   order-dependent, distance-rejecting scatter — `CLAUDE.md` §1 forbids exactly that for world
   generation ("never of visit order").** Its only reusable idea is the name itself: density
   expressed as a spacing, `1 / sqrt(density)` apart. Everything else (the dart-throwing loop,
   `vec3_distanceSquared` neighbour checks, the per-region candidate-id list gated on sampled
   humidity/temperature) is dropped — the last one because it is a *content* decision that
   belongs to 087/088 once they choose what a tree or a rock actually is, not to a brick that
   reads no climate grid and owns no field.
2. **A fixed cell grid reproduces the same density without the dart-throwing.** A cell of side
   `spacing` covers `spacing^2` columns per candidate, i.e. density `1 / spacing^2` — the same
   relationship the reference name implies, reached by fixing the grid instead of rejecting
   close neighbours. `is_anchor_at()` is then an O(1), order-free query: hash the queried
   column's own cell, ask what column that cell's stream would have picked, compare. Verified
   both directly (`test_exactly_one_column_in_a_cell_is_an_anchor`: scanned every column of one
   8x8 cell, found exactly one) and statistically (`test_anchor_density_matches_the_requested_
   spacing`: a real 400x400-column patch at spacing 8 landed within 50% of the expected count).
3. **The anchor is a two-draw position-owned stream, not a coordinate hash or a bit-split.**
   `anchor_column_in_cell()` draws an `x` offset then a `z` offset from `GenerationHash.
   rng_decoration_cell(cell, salt)` — `GenerationHash`'s own "structure kind, then rotation"
   stream shape, reused rather than inventing a second way to get two independent values from
   one coordinate. Two passes reading the same cell at different salts
   (`WorldHash.SALT_TREES`/`SALT_PROPS`, both reserved since brick 015 and unused until now)
   legitimately pick different anchors — checked directly, not assumed.
4. **Eligibility is exactly `ShorelineMaterial`'s own wet-or-shoreline exclusion (084), nothing
   more.** No ruggedness gate, no snow exclusion (085's `SnowlineMaterial` is never touched) —
   086's backlog row asks "can decoration exist here at all", not "what kind, where", and both
   deferrals are named as open for 087/088 rather than silently decided here.

Not a generation version bump: no world has ever had a voxel written, and this brick mixes no
new salt of its own — every call site supplies its own (`SALT_TREES`/`SALT_PROPS`). The new
`Space.DECORATION_CELL` tag and `rng_decoration_cell()` are additions to `GenerationHash`,
not changes to anything it already answered — every existing `GenerationHash` test still
passes unmodified. `docs/world-generation.md` §25.7.

Docs: `docs/world-generation.md` §25 (new, eight subsections).

Tests: `tests/unit/test_decoration_mask.gd` (new, 24 tests, 4167 assertions — no signature
pinning: this brick has no world-content output to pin, only a boolean mask and a coordinate
transform); `tests/unit/test_generation_hash.gd` (+1 test,
`test_a_decoration_cells_stream_is_owned_by_that_cell`, plus `Space.DECORATION_CELL` added to
the existing space-distinctness sweep). Full suite: `files=59 tests=864 assertions=127630
failed=0`. Compile probe OK (124 scripts). Headless boot OK.

`085` is the combination `TemperatureField`'s (064, §9.3/§9.7) own class comment named in
advance as belonging to someone else: one new file, `world/generation/snowline_material.gd`
(`SnowlineMaterial`), composing `ShorelineMaterial` (084, itself holding `OceanPass`/
`SurfaceMaterial`), `TemperatureField` (064) and `TerracePass` (063) into
`block_id_at(column) -> String`. No change to any existing file, no new noise layer, no new
salt, no new `BiomeDefinition` field, no new block.

```text
height_above_land_base_at(column)  = max(0, TerracePass.at(column) - ElevationField.LAND_BASE_VOXELS)
effective_temperature_at(column)   = TemperatureField.at(column)
                                      - LAPSE_RATE_PER_VOXEL * height_above_land_base_at(column)
is_snow_covered_at(column)         = height_above_land_base_at(column) > 0
                                      and effective_temperature_at(column) < TEMPERATURE_COLD

block_id_at(column) = ShorelineMaterial.block_id_at(column)   if wet or shoreline
                     = SNOW_BLOCK_ID                            if is_snow_covered_at(column)
                     = ShorelineMaterial.block_id_at(column)   otherwise
```

Five things worth keeping:

1. **The lapse rate is derived, not picked.** `LAPSE_RATE_PER_VOXEL = (TemperatureField.
   MAXIMUM - BiomeClassifier.TEMPERATURE_COLD) / ElevationField.RELIEF_AMPLITUDE_VOXELS`
   (measured: `0.00625`), set so that the tallest a landward column's relief can ever raise
   it above `ElevationField.LAND_BASE_VOXELS` is always snow-capped even at the hottest
   climate the world can produce — the one guarantee a snowline is supposed to make.
   `self_check()` asserts that boundary algebraically rather than trusting the formula,
   `BiomeClassifier.RUGGEDNESS_MOUNTAIN`'s own precedent for a threshold derived from a
   relationship instead of measured or guessed.
2. **The gate at the land baseline is load-bearing, not an optimisation, and it is the
   answer to the open question the previous session's own handoff carried forward.**
   `is_snow_covered_at()` returns `false` outright for any column that does not clear
   `ElevationField.LAND_BASE_VOXELS`, before ever comparing a temperature — because at or
   below that baseline, the lapsed value collapses to the exact same raw `TemperatureField.
   at()` reading `BiomeClassifier.classify()` already tests against the exact same
   `TEMPERATURE_COLD` threshold. Without the gate this file would re-decide, and re-harden
   into a hard edge, the `SNOW`/non-`SNOW` biome boundary `BiomeTransition` (074) and
   `SurfaceMaterial` (075) already dither smoothly across — confirming the previous
   session's own guess that "snowline" means *raising the effective threshold near the
   frost line*, not a second independent snow-cover mechanism.
3. **One fixed block, `ShorelineMaterial`'s own argument extended a third time.**
   `SNOW_BLOCK_ID = "block.snow"` (shipped by 075) covers every snow-covered column
   regardless of biome — `WaterLevel` (080), `OceanPass` (083) and `ShorelineMaterial` (084,
   §23.2) all landed the same way, and no consumer anywhere distinguishes a snow-capped
   mountain from a snow-capped tundra.
4. **A pure combination over `ShorelineMaterial`, not `SurfaceMaterial` — so a wet or
   shoreline column is excluded for free.** Building on 084 rather than reaching past it
   means this brick never has to decide what a snowy beach or a frozen lake edge looks
   like; `ShorelineMaterial`'s own class comment left that door open for a future brick and
   this one does not walk through it.
5. **Reference: a real function this time, not another "nothing to diverge from."**
   `GAP_ANALYSIS.md`'s `terrain_surfaceColor_blend` (`0x005c56e0`, `cube/game_misc/
   game_misc.cpp`) gates a snow-coloured blend on a normalized **height** and **slope**
   (`height > 0.8`, `slope < 0.2`) — no moisture term anywhere in the body, despite the
   one-line summary claiming one. Kept: snow as a height effect independent of climate,
   arrived at first in §9.3/§9.7 before this function was read. Diverged, twice: no slope
   gate (already `ErosionPass.ruggedness_at()`'s question, one layer upstream, at
   `biome.mountain`'s own classification) and no discrete material at all in the original
   (066's own §12.5 divergence carried forward).

Not a generation version bump: no world has ever had a voxel written, and `SnowlineMaterial`
adds no field, no salt, no block of its own — a pure combination over three independently
unchanged passes (`ShorelineMaterial`'s, `TemperatureField`'s and `TerracePass`'s own tests
all still pass, none of the three files touched). `docs/world-generation.md` §24.7.

Docs: `docs/world-generation.md` §24 (new, eight subsections); `docs/reference/
traceability.md` (085's existing `terrain-climate-blend.md` row extended with the
`terrain_surfaceColor_blend` finding, since it falls outside that note's own scope).

Tests: `tests/unit/test_snowline_material.gd` (new, 23 tests; pins `signature()`
`671f7833af3596ab` for `block_id_at()` over `GenerationFixtures.columns()` on the `typed`
world — **identical to `test_shoreline_material.gd`'s and `test_surface_material.gd`'s own**
pinned value, because none of the 15 fixture columns is both above the land baseline and
cold enough once lapsed, the same small-sample-vs-sparse-feature finding every brick since
077 has recorded. Three hand-picked columns found by a design-time sweep of the standard
2304-column distribution exercise the real property: a `mountain` column at height 32,
raw temperature `0.389` (too warm for `BiomeClassifier` to call it `SNOW`), reads snow-
covered once lapsed to `0.189`; a `mountain` column at height 40, raw temperature `0.500`,
stays bare because lapsing only reaches `0.250`; and a `forest` column at height 24, raw
temperature `0.224` (again too warm for the classifier), reads snow-covered once lapsed to
`0.074`, overriding its own `block.grass` — proof the override reaches biomes other than
`mountain`. Measured over the same 2304-column sweep: 7.29% of the world reads snow-covered,
a real minority. Full suite: `files=58 tests=839 assertions=123455 failed=0`. Compile probe
OK (122 scripts, self-excluded). Headless boot OK. Measurement used a throwaway scratch test
(`tests/unit/test_zzz_scratch_snowline_material.gd`, print-only, run via `tools\scripts\
test.ps1 -File zzz_scratch -Verbose_`, then deleted — never committed), `076`'s/`080`'s/
`081`'s/`084`'s exact scratch-test-file precedent.

`084` is the combination `OceanPass`'s (083, §22.5/§22.8) own class comment named in advance
twice as belonging to someone else: one new file, `world/generation/shoreline_material.gd`
(`ShorelineMaterial`), composing `OceanPass` (083, itself holding `LakePass`/`RiverPass`/
`WaterLevel`) and `SurfaceMaterial` (075) into `block_id_at(column) -> String`. No change to
either existing file, no new noise layer, no new salt, no new `BiomeDefinition` field, no new
block.

```text
is_water_at(column)     = OceanPass.is_ocean_at(column) or OceanPass.is_river_or_lake_at(column)
is_shoreline_at(column) = not is_water_at(column)
                           and any neighbour in {(±1,0), (0,±1)} has is_water_at(neighbour)
block_id_at(column)     = SHORE_BLOCK_ID ("block.sand") if is_shoreline_at(column)
                           else SurfaceMaterial.block_id_at(column)
```

Five things worth keeping:

1. **This is the first pass in the project to ask about a column's neighbours, not just the
   column itself.** Every earlier field — `BiomeClassifier`, `SurfaceMaterial`, `OceanPass`,
   all of them — is a pure function of one column's own coordinates. Adjacency needed a real
   design decision with no precedent to lean on: Von Neumann (the four columns sharing an
   edge), not Moore (the eight sharing a corner too), for two reasons that both point the same
   way — cost (each neighbour check re-pays the whole `OceanPass`/`TerracePass` chain, so four
   calls is already 4x any earlier per-column field's cost; eight would double that again) and
   restraint (nothing downstream reads this file yet, so there is no measured artifact the
   corner-case gap would visibly cause — widening `_NEIGHBOR_OFFSETS` later is cheap and local
   whenever an actual consumer asks for it). `docs/world-generation.md` §23.1 has the full
   argument.
2. **One fixed block, not a per-biome field — extending a line every water-adjacent brick since
   080 has already kept.** `BiomeDefinition`'s own 067 class comment once grouped "water,
   shoreline, snowline, altitude bands" as fields a later brick might add; `WaterLevel` (080)
   added a bare constant instead, `OceanPass` (083) added no field at all, and this brick
   follows the same line: `SHORE_BLOCK_ID = "block.sand"` (already shipped by 075, no new
   block) covers every shoreline column regardless of biome, because no consumer anywhere
   distinguishes a snowy shore from a sandy one. Extends `SubsurfaceMaterial.DEEP_BLOCK_ID`'s
   own precedent one layer up instead of one layer down. `docs/world-generation.md` §23.2.
3. **A pure combinator, `OceanPass`'s/`UndergroundMaterial`'s own shape — no `self_check()`,
   because `_NEIGHBOR_OFFSETS` is a fixed geometric constant, not a hashed one, so there is no
   new relationship for one to assert.**
4. **The "how common is this" measurement had to change shape, because a shoreline is a
   1-voxel-wide boundary, not an area feature.** Every earlier rarity measurement (`CaveMask`,
   `RiverPass`, `LakePass`, `OceanPass`) used a sparse, wide-spaced sweep of independent
   columns; run the identical way here, it found **zero** shoreline hits across 2304 columns —
   not evidence of rarity, only evidence that an independent-point sweep cannot see a 1-voxel
   boundary by chance. The real measurement is a contiguous 100×100-column patch straddling an
   actual coastline (found by walking a line between two sweep points whose `is_water_at()`
   disagreed): 47.6% water, 1.0% shoreline, 51.4% ordinary dry — the water share lands close
   to `OceanPass`'s own 47.9% world figure, and the shoreline share is reported as a property
   of *this* coastline, explicitly not claimed as a world-wide constant the way `CaveMask`'s/
   `RiverPass`'s/`LakePass`'s own fractions are. `docs/world-generation.md` §23.4 has the full
   table and the reasoning for why the method itself had to change.
5. **Still nothing decides what a wet column looks like, and this file is careful not to
   accidentally start.** `block_id_at()` never checks whether its own column is wet — a river,
   lake or ocean column keeps reading straight through `SurfaceMaterial`, unchanged from before
   this brick existed, `OceanPass`'s own "what this brick does not do" boundary carried forward
   rather than quietly crossed. `test_a_wet_column_is_never_a_shoreline_column_and_is_never_
   overridden` pins this down directly.

Reference: a case-insensitive grep of `reference/CubeWorld-Reversal` for "shore" finds nothing;
"beach" finds two hits (`L"BeachUmbrella"`, `L"BeachTowel"`), both in the same landmark/prop
name-to-id map `Cave`/`Lake`/`Ocean` were already found in (`server/world/World.cpp`) — the same
"landmark/prop label, not a coverage mechanism" finding a fourth time. Nothing to diverge from.
`docs/world-generation.md` §23.6; `docs/reference/traceability.md` §4 (084 added, a ninth
instance in this shape).

Not a generation version bump: no world has ever had a voxel written, and `ShorelineMaterial`
adds no field, no salt, no block of its own — a pure combination over two independently
unchanged passes (`OceanPass`'s and `SurfaceMaterial`'s own tests all still pass, neither file
touched). `docs/world-generation.md` §23.7.

Docs: `docs/world-generation.md` §23 (new, eight subsections); `docs/reference/
traceability.md` §4 (084 added to the original-design list, ninth instance, fourth reference
location). `BiomeDefinition`'s own class comment (067) still names "shoreline" among fields a
later brick might add — worth a look by whichever brick next touches that file, to confirm 085
(snowline) settles the same way this brick and 080/083 already did before assuming a schema
change is needed.

Tests: `tests/unit/test_shoreline_material.gd` (new, 17 tests; pins `signature()`
`671f7833af3596ab` for `block_id_at()` over `GenerationFixtures.columns()` on the `typed`
world — **identical to `test_surface_material.gd`'s own pinned value**, because none of the 15
fixture columns lands within one voxel of water, so `block_id_at()` falls straight through to
`SurfaceMaterial.block_id_at()` at every one of them, the same "small sample can't see a rare/
thin feature" finding every brick since 077 has recorded, sharper here than anywhere before it.
No `test_is_seed_sensitive()` for `is_shoreline_at()`/`block_id_at()` — `test_cave_mask.gd`'s
own precedent for the same reason: a boolean derived from a 1-voxel boundary would have two
seeds "agreeing" (all false) at any affordable sample spacing, true and uninformative rather
than evidence of anything; `is_water_at()`'s own seed sensitivity is already exercised by
`test_ocean_pass.gd`. `KNOWN_SHORELINE_COLUMN` (`Vector2i(-94296, -94139)`) was found by a
design-time sweep that walked a line between two coarse sweep points whose `is_water_at()`
disagreed; `KNOWN_INLAND_COLUMN`/`KNOWN_WATER_COLUMN` reused from `test_ocean_pass.gd`'s own
`KNOWN_DRY_COLUMN`/`KNOWN_OCEAN_COLUMN` rather than re-swept, since the two sweeps share the
same spacing and origin. Full suite: `files=57 tests=816 assertions=123332 failed=0`. Compile
probe OK (120 scripts, self-excluded). Headless boot OK. Measurement used a throwaway scratch
test (`tests/unit/test_zzz_scratch_shoreline_material.gd`, print-only, run via `tools\scripts\
test.ps1 -File zzz_scratch -Verbose_`, then deleted — never committed), `076`'s/`080`'s/`081`'s
exact scratch-test-file precedent rather than the probe/runner split `077`–`079`/`082` used.

`083` is the combination `RiverPass`'s (§20.8) and `LakePass`'s (§21.8) own class comments both
named in advance as belonging to someone else: one new file, `world/generation/ocean_pass.gd`
(`OceanPass`), composing `LakePass` (082, itself holding `RiverPass`/`TerracePass`) and
`WaterLevel` (080) into `is_ocean_at(column) -> bool` and `ocean_depth_at(column) -> int`. No
new noise layer, no new salt, no new constant, no `self_check()` — a pure combinator, the same
shape as `UndergroundMaterial` (079).

```text
is_ocean_at(column) = not (river.is_river_at(column) or lake.is_lake_at(column))
                       and water.is_underwater_for(lake.surface_y(column))
```

Three things worth keeping:

1. **A river and a lake are rare, local clips (1.65%/1.82% of the world); ocean is the opposite
   shape — the ordinary, unclipped terrain chain's own output wherever it already sits below
   the water plane, measured at 47.9% (vs. `WaterLevel`'s own raw 50.2% split, §19.2) over the
   same 2304-column sweep every brick since 060 uses.** No new mechanism was needed for "large
   and contiguous" — that shape already exists in `WaterLevel`/`TerracePass`; this brick's only
   job was excluding the two named local features from double-claiming a column.
2. **The exclusion (`is_river_or_lake_at()`) always runs before the water-plane comparison, and
   a real measured case proves it is load-bearing, not decorative.** A genuine river column on
   the `typed` world (`(94139, 69581)`) has a *raw, uncarved* `TerracePass` surface already
   below `SEA_LEVEL_VOXELS` — a river running through land already low enough to be sea. Without
   the exclusion running first, this column would silently read "ocean" too; `test_a_river_
   column_never_reads_as_ocean_even_when_already_underwater` pins the case down. One real
   surprise found while writing the class comment: because the exclusion always returns before
   the water check runs, *which* surface height that check reads (`LakePass.surface_y()` vs. the
   raw `TerracePass` one) turns out to make **no observable difference** to `is_ocean_at()`
   today — the two exclusion conditions between them cover every column where the two surfaces
   could differ. `LakePass.surface_y()` is still what the pass reads (§22.3 has the full
   argument: "don't reach around the pass already held," plus it stays correct if the exclusion
   is ever narrowed later), but the first draft of the class comment claimed this choice was
   load-bearing for correctness, and the measurement sweep disproved that before it shipped —
   worth remembering that a design argument phrased as "matters at the margin" needs the margin
   actually swept before it is trusted.
3. **Reference: the same landmark-label finding as caves and lakes, from a different function
   this time.** `GameController_show_region_name` (`0x004e5320`, `GameController.cpp`, not
   `World.cpp`) formats a displayed region name and emits `L"Ocean"` for a negative zone field —
   an `[AUDIT] confidence: med` display-string heuristic, not a coverage computation. Same shape
   §16.5/§21.6 already found twice, an eighth instance of 067's "no mechanism to diverge from"
   argument, this time discovered in a different source file than the shared chunk-label table.

Not a generation version bump: no world has ever had a voxel written, and `OceanPass` adds
nothing of its own — a pure combination over three independently unchanged passes (`RiverPass`,
`LakePass` and `WaterLevel`'s own tests all still pass, none of the three files touched).
`docs/world-generation.md` §22.7.

Docs: `docs/world-generation.md` §22 (new, eight subsections); `docs/reference/
traceability.md` §4 (083 added to the original-design list, an eighth instance, discovered in a
different reference location — `GameController.cpp`, not `World.cpp`).

Tests: `tests/unit/test_ocean_pass.gd` (new, 15 tests; pins `signature()` `8bfd8320d3e56566`
for `is_ocean_at()` over `GenerationFixtures.columns()` on the `typed` world — all 15 fixture
columns read non-ocean, the same small-sample-vs-near-origin-columns finding `test_water_
level.gd` §19.6 already recorded, so seed sensitivity used the 2304-column sweep instead, the
identical fix). `KNOWN_OCEAN_COLUMN` (depth 96), `KNOWN_DRY_COLUMN` and `KNOWN_RIVER_ALSO_RAW_
UNDERWATER_COLUMN` were found by a design-time sweep; `KNOWN_RIVER_COLUMN`/`KNOWN_LAKE_COLUMN`
reused from `test_river_pass.gd`/`test_lake_pass.gd` rather than re-swept. Full suite:
`files=56 tests=799 assertions=123230 failed=0`. Compile probe OK (120 scripts). Headless boot
OK. Measurement used a throwaway probe (`tools/probe/temp_probe_ocean_pass.gd` + `_runner.gd`,
thin-entry/runner split per brick 052), run twice (once for the distribution/worked-case sweep,
once more after adding a river/lake breakdown for the raw-underwater column and the pinned
signature), read, then deleted — never committed, the exact `077`/`078`/`082` throwaway-probe
precedent.

`082` is the clip `RiverPass`'s own class comment named in advance twice as its job: one new
file, `world/generation/lake_pass.gd` (`LakePass`), composing `RiverPass` (081) — not
`TerracePass` directly — into the same shape of clip river carving already established, with
the opposite-tail threshold on the exact same channel layer. No change to `RiverPass`,
`TerracePass` or any other existing file; no new noise layer, no new salt.

```text
is_lake_at(column)  = is_basin_at(column) and river.terrace().at(column) <= LAKE_CEILING_VOXELS
surface_y(column)   = RiverPass.surface_y(column) - (CARVE_DEPTH_VOXELS if is_lake_at else 0)
```

Four things worth keeping:

1. **The layer is reused, not rebuilt.** `LakePass` holds a `RiverPass` and reads
   `channel_distance_at()` straight through it rather than constructing a second
   `ValueNoise.layer()` with identical `(cell size, octaves, gain, salt)` arguments — the
   exact "share, don't duplicate" instruction `RiverPass`'s own class comment left for this
   brick. `test_uses_the_same_layer_river_pass_does` asserts the delegation directly, and
   `channel_distance_at()`'s pinned signature over `GenerationFixtures.columns()` comes out
   bit-identical to `RiverPass`'s own (`71d53280c3e89764`) — not a coincidence, the same
   number for the same reason.
2. **The threshold direction flips, and nothing else does.** A river reads *close to* the
   channel field's own zero contour (a thin winding band, where a coherent field's level sets
   are densest); a lake reads *far from* it (`LAKE_MIN_DISTANCE = 0.85`, the field's own rare
   tail) — the identical "threshold a coherent field's magnitude to get a rare blob"
   argument `CaveMask.DENSITY_THRESHOLD` already used for a 3D field, applied here to a 2D
   one's distance-from-mean instead of a 3D one's density. Disjoint from a river column by
   construction (`0.85 > CHANNEL_HALF_WIDTH = 0.02`), asserted in `self_check()` rather than
   left as an accident of two numbers that happen not to collide today.
3. **The ceiling and the carve depth are reused wholesale, not re-derived.**
   `LAKE_CEILING_VOXELS = RiverPass.RIVER_CEILING_VOXELS` and `CARVE_DEPTH_VOXELS =
   TerracePass.TERRACE_HEIGHT_VOXELS` — the identical constants `RiverPass` uses for the same
   two jobs, `self_check()` asserting the first stays equal rather than only asserting its own
   internal relationships the way `RiverPass.self_check()` does. A lake basin is bound to the
   same continental-plain baseline a river channel is; nothing about the feature having a
   different name changes that.
4. **`LAKE_MIN_DISTANCE` was measured against `RiverPass`'s own river fraction, not chosen in
   isolation.** The sweep (same 2304 columns §20.4 used) showed basin/lake fractions ranging
   from 4.43%/3.30% (`0.80`) down to 0.52%/0.39% (`0.94`); `0.85` (2.34%/1.82%) was picked as
   the value landing closest to `RiverPass`'s own measured river fraction (1.65%) without
   copying it outright — lakes reading as comparably rare to rivers, not dominating or
   vanishing next to them. `docs/world-generation.md` §21.3 has the full table.

Not a generation version bump: no world has ever had a voxel written, and `LakePass` adds no
field, no salt, no noise layer of its own — a pure clip composed over an unchanged pass
(`RiverPass`'s own tests still pass, the file was not touched, its pinned signature is exactly
what it was before this brick). `docs/world-generation.md` §21.7.

Docs: `docs/world-generation.md` §21 (new, eight subsections); `docs/reference/
traceability.md` §4 (082 added to the original-design list — a seventh instance of 077's own
"one landmark-label hit, no mechanism" finding, this time for `L"Lake"` in the same
`cube/world/World.cpp` / `server/world/World.cpp` name-to-id map).

Tests: `tests/unit/test_lake_pass.gd` (new, 21 tests; pins `channel_distance_at()`'s own
signature `71d53280c3e89764` and `at()`'s signature `2af464f70e43590a` — both bit-identical to
`RiverPass`'s own pinned values, for the reason item 1 above states plus the same small-sample
finding every brick since 077 has recorded: none of `GenerationFixtures.columns()`'s 15
samples lands within `LAKE_MIN_DISTANCE` of the channel layer's own mean; `KNOWN_LAKE_COLUMN`
and `KNOWN_LAKE_ABOVE_CEILING_COLUMN`, found by a design-time sweep, are what actually
exercise the clip and the ceiling gate). Full suite: `files=55 tests=784 assertions=123116
failed=0`. Compile probe OK (116 scripts). Headless boot OK. Measurement used a throwaway
probe (`tools/probe/temp_probe_lake_pass.gd` + `_runner.gd`, thin-entry/runner split per
brick 052 — `Log`/`GenerationHash`/`RiverPass`/`LakePass` all need autoloads registered), run
once, read, then deleted — never committed, the exact `077`/`078`/`081` throwaway-probe
precedent.

`081` is the clip both `TerracePass`'s and `WaterLevel`'s own class comments named in advance
as belonging to someone else: a winding channel mask, clipped to lowland ground, that pulls a
column's already-terraced surface down by one riser where the two agree. One new file,
`world/generation/river_pass.gd` (`RiverPass`), composing `TerracePass` (063) with a new
`ValueNoise` channel layer at a new salt (`WorldHash.SALT_RIVERS = 13`, appended). No change
to `TerracePass`, `ErosionPass`, `ElevationField` or any other existing file.

```text
is_river_at(column) = is_channel_at(column) and TerracePass.at(column) <= RIVER_CEILING_VOXELS
surface_y(column)   = TerracePass.surface_y(column) - (CARVE_DEPTH_VOXELS if is_river_at else 0)
```

Five things worth keeping:

1. **`docs/world-generation.md` §8.8 (written when 063 was designed) predicted rivers would
   need to sit *underneath* terracing — shape the continuous height, then terrace it — and
   this brick deliberately did not do that.** Reaching into `ErosionPass`'s own composition
   to insert a new intermediate pass would have re-pinned every downstream signature
   (`SurfaceMaterial`, `SubsurfaceMaterial`, `CaveCarving`, `UndergroundMaterial`,
   `WaterLevel`) for a channel that covers under 2% of the world — the exact thing every
   Phase D brick since 074 has structured itself to avoid. The concern §8.8 actually raised
   — that a post-quantisation flattening term would produce heights that are not terrace
   planes — is answered a smaller way instead: the clip only ever subtracts a *whole*
   `TerracePass.TERRACE_HEIGHT_VOXELS`, so `surface_y()` stays exactly terrace-aligned
   without moving upstream at all. `TerracePass`'s own pinned signature is unchanged; so are
   the five files listed above. `docs/world-generation.md` §20.1 has the full argument.
2. **Nothing downstream reads `RiverPass` yet, and that is the same shape `CaveMask`/
   `CaveCarving` already established across two bricks, here inside one.** A river carved by
   this brick gets no wet material and does not count as underwater — `WaterLevel` still
   reads `TerracePass` directly. That wiring is explicitly 082–084's job, not invented here
   to make this brick feel more finished than its own scope asks for.
3. **The channel is a distance from a noise contour, not a threshold on the noise itself —
   the opposite shape from `CaveMask`'s.** `CaveMask` thresholds a 3D field's low tail to get
   rare blobs; a river needs a thin winding band instead, so `RiverPass` reads `ValueNoise.
   value()` (already signed, `[-1, 1]`, no remap needed) and asks how close a column sits to
   its own zero contour. A coherent field's level sets are winding curves in space at *any*
   level, including its most common one, which is what makes this read as a river network
   rather than a scatter of patches. The consequence for tuning: because the field
   concentrates near its own zero (the middle of a bell-shaped sum, not a tail), the
   threshold is far more sensitive here than a same-looking number would be on a tail
   threshold — measured rather than guessed, the same restraint `CaveMask.DENSITY_THRESHOLD`
   used for the opposite reason. `CHANNEL_HALF_WIDTH = 0.02` measures to 2.69% of the world
   in-channel, 1.65% actually carving once the lowland ceiling is applied.
4. **The lowland ceiling (`RIVER_CEILING_VOXELS = ElevationField.LAND_BASE_VOXELS`) exists so
   the mask cannot cut a channel through a mountain peak, and it is checked *after* the mask
   rather than before, because the cost is the other way around from `CaveCarving`'s
   ordering.** `CaveCarving` checks the cheap surface height before paying for expensive 3D
   cave noise; here the mask is the cheap half (two octaves of 2D noise) and the surface
   height is the expensive one (the whole `Continentalness`→`ElevationField`→`ErosionPass`→
   `TerracePass` chain), so the order is deliberately inverted. Measured: 70% of the sweep
   sits at or below the ceiling, which is the correct shape for a baseline pitched at the
   continental plain — the ceiling's job is excluding genuine mountains, not restricting
   rivers to a sliver of the map.
5. **The brick makes no claim that a channel reaches sea level, and says so explicitly rather
   than leaving it to be assumed.** A hand-picked worked case (`KNOWN_RIVER_COLUMN`, terraced
   height 56, carved to 48) stays well above `WaterLevel.SEA_LEVEL_VOXELS` — carving one
   riser only reaches the sea where the surrounding lowland already sits close to it, exactly
   as a real river's bed depth relative to the sea depends on where it flows. Guaranteeing it
   would need a flow network, explicitly out of scope (`docs/world-generation.md` §7.6), or a
   second deeper clip a later brick can add once it actually needs one — not invented here to
   answer a question this brick's own test fixtures never raised.

Reference: `docs/reference/terrain-base-height-field.md` claim 6 names `World_riverClimateGate`
as a per-column noise gate (not a flow simulation) among four flattening post-passes; its own
helper body was never opened (still `GAP_ANALYSIS`/`LOW`, unchanged by this brick), and claim
6's shape was enough to work from. The kept-vs-diverged split is recorded as its own row in
§8: the original's gate softens relief with nothing downstream needing it to stay aligned;
ours has real terracing downstream, so it carves a whole riser after quantisation instead of
softening relief before it.

Docs: `docs/world-generation.md` §20 (new, eight subsections); `docs/reference/
terrain-base-height-field.md` (header's backlog-bricks/Godot-contract lines updated, claim 6
divergence row added to §8, a new test row in §9); `docs/reference/traceability.md` (081
added to the `terrain-base-height-field.md` row, same shape 080 already used).

Tests: `tests/unit/test_river_pass.gd` (new, 20 tests; pins `channel_distance_at()`'s own
signature `71d53280c3e89764` and `at()`'s signature `2af464f70e43590a` — identical to
`TerracePass`'s own pinned value, because none of `GenerationFixtures.columns()`'s 15 samples
lands in the ~1.65%-of-the-world channel, the same small-sample-vs-sparse-field finding every
brick since 077 has recorded rather than re-argued; `KNOWN_RIVER_COLUMN` and `KNOWN_CHANNEL_
ABOVE_CEILING_COLUMN`, found by a design-time sweep, are what actually exercise the clip and
the ceiling gate). Full suite: `files=54 tests=763 assertions=122878 failed=0`. Compile probe
OK (114 scripts). Headless boot OK. Measurement used a throwaway scratch test
(`tests/unit/test_zzz_scratch_river_pass.gd`, print-only, run via `tools\scripts\test.ps1
-File zzz_scratch -Verbose_`, then deleted — never committed), the exact `077`/`080`
throwaway-probe precedent.

`080` is the constant `061`'s and `063`'s own class comments named in advance as its job: a
water plane, held apart from the terraced ground so it can move without regenerating a
column. One new file, `world/generation/water_level.gd` (`WaterLevel`), wrapping
`TerracePass` (063) with a single `SEA_LEVEL_VOXELS = 0` constant and two comparisons
against it — no new noise layer, no new salt, no new block.

```text
WaterLevel.is_underwater_at(column) = TerracePass.surface_y(column) < SEA_LEVEL_VOXELS
WaterLevel.depth_at(column)         = max(0, SEA_LEVEL_VOXELS - TerracePass.surface_y(column))
```

Four things worth keeping:

1. **`SEA_LEVEL_VOXELS = 0` is not arbitrary — three independent reasons converge on it.**
   It is already `TerracePass`'s own datum, and because `TERRACE_HEIGHT_VOXELS` (8) divides
   it, an exact terrace plane — no column's terraced surface can straddle it. It needed no
   new number: every other vertical anchor in this project was a value chosen against
   `WorldBounds`; `0` is the one height every earlier pass already agreed on. And it measures
   best: over the same 2304-column sweep §6.6/§7.5/§8 use, against `TerracePass`'s *terraced*
   output, candidates `-8`/`0`/`+8` split underwater/land `49.5/50.5`, `50.2/49.8`,
   `51.4/48.6` — `0` is closest to even. `WaterLevel.self_check()` asserts the divisibility
   claim rather than trusting the comment (`CaveMask`/`SubsurfaceMaterial`'s own precedent).
2. **The reference read turned up nothing to diverge from.** `World_waterDepthField`
   (`0x0052d990`), the one function named for water and left unread since 061, was read in
   full for this brick: despite the name, its body computes a chunk-type-gated *temperature*
   modulation (cosine terms over a terrain-gradient sample, folded against a "moisture" value
   from `World_roadField`) and the decompiler recovered no return value at all — `void`,
   guessed types throughout, `[AUDIT] confidence: low`. `World::waterProximityInfluence`
   (`0x00522e20`), the only other water-named function it reaches, is an undecompiled
   `GAP_ANALYSIS` stub, a per-region-grid falloff scan, not a sea-level constant. Recorded as
   claim 10 in `docs/reference/terrain-base-height-field.md` §3, which had left this one
   function unread since 061 (its own §1: "rated LOW, because 061 uses none of them"). 
   `WaterLevel` is therefore a clean-room constant, the same shape
   `OCEAN_FLOOR_VOXELS`/`LAND_BASE_VOXELS` already are, not a divergence from a reference
   shape.
3. **The boundary is strict, and static apart from the instance methods.** A column whose
   terraced surface sits exactly at the plane reads dry — the waterline is shore, not water —
   `CaveCarving.is_hollow_at()`'s own `voxel.y < surface_y(column)` convention, applied to the
   plane instead of a voxel. `is_underwater_for(surface_y)`/`depth_for(surface_y)` are static
   pure functions separate from the column-reading instance methods, `ElevationField.
   shore_weight()`/`base_for()`'s own reason: a test that wants the boundary exactly at the
   plane should not have to hunt the world for a column that happens to sit there.
4. **Not a generation version bump.** No world has ever had a voxel written; `WaterLevel`
   adds one constant and reads `TerracePass` unchanged (its own tests still pass, file
   untouched). `docs/world-generation.md` §19.5.

Docs: `docs/world-generation.md` §19 (new, seven subsections); `docs/reference/
terrain-base-height-field.md` (claim 10 added to §3, a new divergence row in §8, a new test
row in §9, header's confidence/backlog-bricks/Godot-contract lines updated); `docs/reference/
traceability.md` §row for 061–063/080/089–090 updated with the claim-10 finding.

Tests: `tests/unit/test_water_level.gd` (new, 17 tests, pins `signature()`
`2c52ab62cf0542d2` for `depth_at()` over `GenerationFixtures.columns()` on the `typed`
world). Seed sensitivity needed the 2304-column distribution sweep rather than
`GenerationFixtures.columns()`'s 15 samples — `test_underground_material.gd`'s own small-
sample finding repeated: a handful of near-origin/near-boundary columns can land dry under
both fixture seeds by coincidence. Full suite: `files=53 tests=743 assertions=122708
failed=0`. Land-fraction measurement used a throwaway scratch test
(`tests/unit/test_zzz_scratch_water_level.gd`, `print()`-only, run once via `tools\scripts\
test.ps1 -File zzz_scratch -Verbose_`, then deleted — never committed), the exact `077`/`078`
throwaway-probe precedent applied to a unit test file instead of a `--script` entry.

`079` is the combination `078`'s own class comment named in advance as its job (§17.4): one
new file, `world/generation/underground_material.gd` (`UndergroundMaterial`), composing
`CaveCarving` (078) and `SubsurfaceMaterial` (076) into a single
`block_id_at_voxel(voxel) -> String`. No change to either existing file, no new noise field,
no new salt, no new `BiomeDefinition` field, no new block.

```text
UndergroundMaterial.block_id_at_voxel(voxel) -> String
        |
        +-- CaveCarving.is_hollow_at(voxel)   -> ""   (air — the cave itself)
        +-- otherwise                         -> SubsurfaceMaterial.block_id_at_voxel(voxel)
                ("" at/above the surface, topsoil/bedrock below it — 076, unchanged)
```

Four things worth keeping:

1. **Both open questions the previous session's handoff carried forward are now settled,
   and both settled toward the smaller answer.** (a) "Underground material rules" does
   **not** mean a new cave-wall/floor material distinct from `SubsurfaceMaterial` — the
   backlog row's own title, §16.2's forward flag ("079 combines this mask with
   `SubsurfaceMaterial` as two independent inputs"), and §17.4's forward flag (both quoted
   verbatim in the previous handoff) all describe a *combination*, never a third material
   decision, and no consumer anywhere in the project asks a cave wall to look different from
   open ground at the same depth — inventing one now would be the sixth instance of 067's
   "field nothing reads" argument (§§12.3, 14.6, 15.2, 16.7 already the first five). (b) the
   project's existing empty-string-is-air convention (`block_edit_delta.gd`) is exactly the
   right value for a carved voxel, reused rather than given a second meaning — this is the
   first brick to return `""` for air *because it was carved out* rather than because
   nothing underground has started yet, and `test_an_above_ground_cave_voxel_stays_air_for_
   the_surface_reason_not_the_carving_reason` asserts both reasons land on the same value.
2. **The two passes stay two objects, not a merged field.** `UndergroundMaterial` holds a
   `CaveCarving` and a `SubsurfaceMaterial` and builds both itself
   (`TerracePass.for_world()`'s recurring reason: stateless, small, and a shared instance
   would be a second way for two passes to disagree about which world they are generating).
   `for_world()` delegates every registry/hash check to `SubsurfaceMaterial.for_world()` and
   adds none of its own — it has no field of its own to check, `SubsurfaceMaterial.
   for_world()`'s exact delegation to `SurfaceMaterial.for_world()` one layer further down.
3. **Testing the combination reused 078's own hand-picked voxels rather than sweeping for
   new ones.** `KNOWN_HOLLOW_VOXEL` and `KNOWN_ABOVE_GROUND_CAVE_VOXEL` from
   `test_cave_carving.gd` are exactly the two cases that exercise this brick's own logic (a
   real hollow voxel must read as air; a `CaveMask`-hollow-but-above-ground voxel must still
   read as air, but through `SubsurfaceMaterial`'s "not this pass's question" branch, not
   through the carving clip) — the same property 078 already needed a design-time sweep to
   find, so re-sweeping would have re-discovered the same coordinates. Seed sensitivity
   reused 076's own fix for the y-near-zero ambiguity in `GenerationFixtures.voxels()`
   (sampling one voxel below each column's own terraced surface, computed fresh from the
   pass under test) rather than re-deriving it.
4. **Not a generation version bump — same boundary as every Phase D brick since 062.** No
   world has ever had a voxel written, so nothing this brick computes can contradict one.
   `UndergroundMaterial` adds no field, no salt, no constant — a pure combination of two
   independently unchanged passes (both files' own tests still pass; neither was touched).
   `docs/world-generation.md` §18.4.

Docs: `docs/world-generation.md` §18 (new, seven subsections); `docs/reference/
traceability.md` §4 (079 added to the original-design list, sixth in the same shape).

Tests: `tests/unit/test_underground_material.gd` (new, 12 tests, pins `signature()`
`a9ac004142d5a8bb` against `CaveCarving`/`SubsurfaceMaterial` composed over
`GenerationFixtures.voxels()` on the `typed` world, against the shipped biome/block
catalogs). Full suite: `files=52 tests=726 assertions=122486 failed=0`. Compile probe OK
(110 scripts). Headless boot OK.

`078` is the clip `077`'s own class comment named in advance as its job: one new file,
`world/generation/cave_carving.gd` (`CaveCarving`), composing `CaveMask` (077) and
`TerracePass` (063) into a single `is_hollow_at(voxel) -> bool`. No change to either
existing file, no new noise field, no new salt, no new constant.

```text
CaveCarving.is_hollow_at(voxel) -> bool
        |
        +-- voxel.y >= TerracePass.surface_y(column)   -> false   (cheap check first)
        +-- otherwise                                  -> CaveMask.is_cave_at(voxel)
```

Four things worth keeping:

1. **The cheap check runs first, and it is a real cost decision, not style.** `surface_y()`
   is one division and a floor over an already-built height field; `CaveMask.is_cave_at()`
   is four octaves of 3D trilinear noise, eight hashed corners each (077). Every
   above-ground voxel — the majority of any column — short-circuits before the expensive
   half ever runs. `CLAUDE.md` §8 ranks world generation above every other performance
   concern, and this is the shape that ranking asks for at the one call site a future
   `VoxelGenerator` fill loop will actually hit per voxel.
2. **A strict inequality, matching `SubsurfaceMaterial`'s own boundary.** `surface_y(column)`
   names the top *solid* voxel of the ground (076's exact convention, `depth <= 0` is "not
   this pass's question"), so underground starts strictly below it: `y < surface_y(column)`.
   Carving the surface voxel itself away would hollow the one cell every other pass in the
   chain agrees is ground. Asserted at every fixture column regardless of what `CaveMask`
   says there (`test_the_surface_voxel_itself_is_never_hollow`).
3. **A bool, not a block id — the split 079 depends on.** `SurfaceMaterial`/
   `SubsurfaceMaterial` answer with a block id because both decide what a voxel is *made
   of*; this file never has to, because hollow-or-not is the whole question `CaveMask`
   started with and the backlog row calls this brick "carving", not "cave material".
   Answering with a block id here would force this file to also decide what a non-hollow
   underground voxel is made of — 079's job, kept as its own brick depending on this one
   rather than folded into it, the exact `CaveMask`/`SubsurfaceMaterial` split the 077
   handoff asked 078 to preserve.
4. **Testing a boolean composed from a sparse field needed the same restraint 077's own test
   file already used, not a new idea.** `CaveMask.is_cave_at()` reads hollow on ~4% of
   underground space; `GenerationFixtures.voxels()` (16 samples) reads `false` for every one
   of them on more than one fixture seed, so a seed-sensitivity check built on it reports
   two seeds "agreeing" everywhere — true and uninformative, not a bug. `test_cave_mask.gd`
   never ran that check against the boolean `is_cave_at()` either, only against the
   continuous `density_at()`; `test_cave_carving.gd` follows the identical precedent
   (`Callable`-of-`bool`, only `test_is_deterministic()`; no `test_is_seed_sensitive()`,
   documented in a comment rather than silently dropped) and instead exercises the boolean
   with three hand-picked voxels found by a design-time sweep: `KNOWN_HOLLOW_VOXEL`
   (= `CaveMask`'s own `KNOWN_CAVE_VOXEL`, `Vector3i(-323, 34, -221)`, reused rather than
   re-swept), `KNOWN_SOLID_VOXEL` (the origin, also reused), and — the property specific to
   this brick — `KNOWN_ABOVE_GROUND_CAVE_VOXEL` (`Vector3i(1, 344, 2)`, 280 voxels above its
   own column's terraced surface), which `CaveMask` alone calls hollow but which
   `CaveCarving` must not, proving the clip is load-bearing rather than a pass-through.

Not a generation version bump: no world has ever had a voxel written, and `CaveCarving`
adds no field, no salt, no constant of its own — a pure clip over two independently
unchanged passes (`docs/world-generation.md` §17.5). `WorldHash.SALT_CAVES` stays exactly
where 077 left it, reserved-and-unused; this brick does not move that boundary, only
inherits it.

Docs: `docs/world-generation.md` §17 (new, seven subsections); `docs/reference/
traceability.md` §4 (078 added to the original-design list, sixth in the same shape).

Tests: `tests/unit/test_cave_carving.gd` (new, 10 tests, pins `signature()`
`20ff1ccf274a9c05` against `CaveMask`/`TerracePass` on the `typed` world over
`GenerationFixtures.voxels()` — all 16 samples land solid, the same small-sample-vs-sparse-
field finding item 4 above records). Full suite: `files=51 tests=714 assertions=122430
failed=0`. Compile probe OK (108 scripts). Headless boot OK.

**One tooling note, the same shape as 077's own:** the three fixture voxels above were found
by a throwaway measurement probe (`tools/probe/temp_probe_cave_carving.gd` +
`_runner.gd`, thin-entry/runner split per brick 052 — `Log`/`GenerationHash`/`CaveMask`/
`TerracePass` all need autoloads registered, which a bare `--script` entry file predates),
run once, read, then deleted — never committed, matching 077's `temp_probe_cave_density*`
precedent exactly.

`077` is the first Phase D brick sampled at a **voxel** rather than a column, and the first
consumer of the 3D noise form §5.6 deliberately deferred back at brick 060 ("Caves
(077–078) need a 3D form of the same layer; nothing before them does, and adding it now
would ship an untested surface"). Two new files: `world/generation/cave_mask.gd`
(`CaveMask`) and a 3D extension of the existing `world/generation/value_noise.gd`
(`ValueNoise.value3()`/`value301()`/`octave_value3()`, trilinear rather than bilinear,
hashed in voxel space rather than column space). `WorldHash.SALT_CAVES = 4`, reserved
since brick 015, gets its first user. No change to `TerracePass`, `SubsurfaceMaterial` or
any other existing pass.

```text
CaveMask.is_cave_at(voxel) -> bool
        |
        +-- density_at(voxel) < DENSITY_THRESHOLD (0.25)
                density_at(voxel) = ValueNoise(cell=128, octaves=4, salt=SALT_CAVES).value301(voxel)
```

Four things worth keeping:

1. **The mask reads neither `TerracePass` nor `SubsurfaceMaterial`, and that was the
   central design decision, carried in from the previous session's handoff rather than
   re-derived.** A cave is a hollow, not a height and not a material choice — "is this
   voxel hollow" and "is this voxel underground" are two different questions, and a mask
   that answered both at once would take that split away from brick 078, which needs to
   ask them separately (078 clips this mask's answer against the terraced surface before
   ever carving anything, so `density_at()` sampled above the real ground stays a
   legitimate, uneventful number rather than something this file has to guard against).
2. **3D value noise concentrates far more tightly around its mean than the project's 2D
   layers, and that shaped the threshold rather than being corrected away.** Trilinear
   interpolation blends eight hashed corners per octave against a 2D layer's four; measured
   at the shipped constants over a 13824-voxel sweep (spacing 131, just under the coarsest
   cell) on four fixture-style seeds: `mean 0.499`, `sd 0.150`, against `sd 0.28 – 0.32` for
   a comparable fade-shaped 2D field (`docs/world-generation.md` §10.4). `DENSITY_THRESHOLD
   = 0.25` is a round quarter of `[0, 1]`, the same style of round constant
   `ElevationField.SHORE_MIDPOINT`/`SHORE_WIDTH` use, but what it actually selects — **4.1%
   – 4.3%** of raw 3D space, consistent across every seed measured — is a property of the
   3D field, not a number aimed at. Caves reading as rare and worth finding rather than the
   majority of the underground is the intended outcome, not a defect to retune away; the
   pinned test (`test_the_measured_fraction_is_a_minority`) asserts a band (`0.5% – 15%`)
   around this rather than the exact figure, so a future retune has room.
3. **The scale mirrors `ElevationField`'s relief, deliberately inverted.**
   `ErosionPass.RUGGEDNESS_CELL_SIZE_VOXELS` sits eight times *coarser* than
   `ElevationField.RELIEF_CELL_SIZE_VOXELS` because it decides *where* relief may exist, a
   coarser question than the relief itself; `CaveMask.CELL_SIZE_VOXELS` (128 voxels) sits
   eight times **finer**, because a cave system is a smaller thing than a mountain range.
   The finest cave cell (16 voxels) is half of `ElevationField`'s own finest relief cell
   (32) — the "half, not the whole" legibility argument bricks 074 and 076 already used,
   here so cave detail resolves finer than the smallest hill. Both relationships are
   literals (GDScript's warnings-as-errors flags exact integer division the same way
   `generation_grid.gd`'s `floor_div()` already worked around), asserted at runtime by
   `CaveMask.self_check()` rather than trusted from a comment — `SubsurfaceMaterial`'s exact
   precedent for the same constraint.
4. **Reference: the clearest "nothing to diverge from" finding yet.** A three-file
   case-insensitive grep of `reference/CubeWorld-Reversal` for "cave" turns up exactly one
   hit with content — the wide string literal `L"Cave"` in a name-to-id map in
   `server/world/World.cpp`, almost certainly a structure/POI label with no generation
   mechanism anywhere near it. `docs/world-generation.md` §16.5;
   `docs/reference/traceability.md` §4 gains a fifth row in the same shape 074/075/076
   already established.

Not a generation version bump: a new field and a new 3D noise capability, neither used by
any world generated so far (`docs/world-generation.md` §16.6, the same "no `VoxelBuffer`
has ever been filled" argument every Phase D brick since 062 has made). Every pinned
signature below this brick is untouched, including `ValueNoise.value()`'s own
`0d355b4d9ddddd7d`; the new `value3()` form pins its own (`70c1c6e87feda219`).

Docs: `docs/world-generation.md` §16 (new, seven subsections); `docs/reference/
traceability.md` §4 (077 added to the original-design list, fifth in the same shape).

Tests: `tests/unit/test_cave_mask.gd` (new, 15 tests, pins `signature()` `8dce87e95aeb1d89`
against `CaveMask.density_at()` over `GenerationFixtures.voxels()` on the `typed` world, plus
a worked cave voxel (`Vector3i(-323, 34, -221)`) and a worked solid one (the origin) found by
a design-time sweep — GenerationFixtures' 16-voxel sample set is too small to reliably land
on a true `is_cave_at()` given the measured ~4% fraction, so the property "the mask actually
calls something a cave" needed a hand-picked coordinate rather than a scan over the shared
fixture list); `tests/unit/test_value_noise.gd` (+11 tests for the 3D form: determinism,
seed-sensitivity, range, variation, lattice anchoring, octave summation, a pinned signature
`70c1c6e87feda219`, a 2D/3D non-collapse check, and a per-axis coherence walk). Full suite:
`files=50 tests=704 assertions=122379 failed=0`. Compile probe OK (106 scripts). Headless
boot OK.

**One tooling note, the same shape as 067's:** the measurement sweep behind item 2 above
needed the thin-entry/runner split from brick 052 (`--script` compiles before autoloads
register, and `WorldSeed`/`GenerationHash`/`ValueNoise` all touch `Log`) — a first attempt
without the split compiled far enough to print nothing and then sat in the headless main
loop forever rather than exiting, because the uncaught compile error meant `quit()` was
never reached. The probe scripts themselves were never committed (`tools/probe/temp_probe_
cave_density*.gd`, deleted after the measurement).

`076` is the brick that closes out `BiomeDefinition`'s original 067 wishlist (§12.2's
table): `world/generation/subsurface_material.gd` (`SubsurfaceMaterial`), one new file;
`BiomeDefinition.subsurface_block_id` (new field, five total now — the class comment says
explicitly this is the last one that table hands out for free); `SurfaceMaterial.
biome_id_at()` (new accessor on the 075 file, `block_id_at()` refactored to call it rather
than duplicate the roll); the six `.tres` biome records regenerated through
`generate_biome_catalog.gd` with the field filled in; no new blocks, no new salt, no change
to `BiomeClassifier`, `BiomeTransition` or any pinned generation signature.

```text
SurfaceMaterial.biome_id_at(column) -> winning biome id        (075's roll, reused, not re-rolled)
        |
        +-- TerracePass.surface_y(column) - y <= 0              -> "" (not this pass's question)
        +-- 1 .. SUBSURFACE_DEPTH_VOXELS                        -> winning biome's subsurface_block_id
        +-- deeper                                              -> SubsurfaceMaterial.DEEP_BLOCK_ID ("block.stone")
```

Six things worth keeping:

1. **The central design decision was refusing a second dither.** 076's first draft
   considered rolling its own independent coin for the subsurface layer, the same shape
   075's dither already has. Rejected: a column near a biome edge already picks its surface
   block per-column, not per-voxel (075, §14.1); an independent second roll would let part
   of that dithered band put a neighbor's grass over the primary's dirt — two biomes'
   ground stacked in one column, which is a seam, not a blend. `SurfaceMaterial.
   biome_id_at()` — new, exposing the winning id `block_id_at()` already computed rather
   than only the block it resolves to — is what 076 reads instead. No new salt follows from
   that: a second salt would only be a second dither on top of the first.
2. **The refactor that made (1) possible left `block_id_at()`'s observable behavior
   untouched.** `biome_id_at()` now does the roll; `block_id_at()` calls it and looks up
   `surface_block_id`. `test_surface_material.gd`'s pinned signature (`671f7833af3596ab`)
   still passes with no change to its own file, which is what proves the refactor is a
   refactor and not a second change wearing 075's name.
3. **Two layers, not three, and stone is not invented for the purpose.** Topsoil
   (`subsurface_block_id`, per biome — grass/forest/snow/wetland→dirt, desert→sand,
   mountain→stone) down to `SUBSURFACE_DEPTH_VOXELS`, then `DEEP_BLOCK_ID` (`block.stone`,
   every biome, no exceptions) forever. A third, per-biome bedrock layer is exactly the
   field-nothing-fills shape 067 already named twice; `block.stone` costs nothing new
   because it is already what a mountain's *surface* reads as (075). `docs/world-
   generation.md` §15.2 has the full table and reasoning per biome.
4. **The depth is derived from `TerracePass`, and the derivation is a legibility argument,
   not an arbitrary half.** `SUBSURFACE_DEPTH_VOXELS = 4`, half of `TERRACE_HEIGHT_VOXELS`
   (8) — the same "half, not the whole" shape 074's `TRANSITION_WIDTH` used, for a
   different reason here: `TerracePass` risers can be a full terrace tall
   (`max_riser_voxels()`), and a topsoil that shallow means a cliff crossing a whole shelf
   shows bedrock partway down its own face rather than reading as soil top to bottom. Not a
   const expression referencing a function this time — `TerracePass.TERRACE_HEIGHT_VOXELS`
   is a real constant — but the derivation is still asserted at runtime in
   `SubsurfaceMaterial.self_check()` rather than trusted from the comment, matching 074's
   precedent rather than leaning on the one case where GDScript would have allowed a const
   expression.
5. **A real bug in the test file's first draft, caught and fixed before it shipped:**
   `GenerationFixtures.voxels()` was the wrong sample set for `test_is_seed_sensitive()` —
   most of its y values sit at/near 0, and whether that is above or below a given world's
   ground is close to a coin flip the fixture was never built to control, so two seeds
   agreed at `""` (above the surface) on every one of the 16 samples. Fixed by sampling one
   voxel below each column's *own* terraced surface, computed fresh from the pass under
   test rather than baked into the sample coordinate — `tests/unit/test_subsurface_
   material.gd`'s `_one_below_surface()` helper, reused across the determinism, seed-
   sensitivity and signature tests. Worth remembering for any future column-plus-depth
   pass: `voxels()`/`columns()` are the right fixture for a 2D field, not automatically for
   one that also reads a height.
6. **Not a generation version bump, same boundary as 075's.** No world has ever had a voxel
   written, so nothing 076 computes contradicts one yet. The new pieces —
   `subsurface_block_id` (a record field, §12.6's stated exception) and
   `SUBSURFACE_DEPTH_VOXELS` (a pure constant) — join `SALT_SURFACE_MATERIAL` and every
   `surface_block_id` on the list §14.4 already opened, effective at the same moment: the
   first `VoxelGenerator` call that actually fills a `VoxelBuffer`, not before.

Docs: `docs/world-generation.md` §15 (new, seven subsections); `docs/reference/
traceability.md` §4 (076 added to the original-design list, same reasoning shape a fourth
time); `docs/reference/matrix-world.md` (biome-colour row, 076 added to `Bricks`).

Tests: `tests/unit/test_subsurface_material.gd` (new, pins `signature()` `58988f30d866891d`
against the shipped catalogs on the `typed` world, sampled one voxel below each column's own
surface); `test_biome_definition.gd` (+4, the new field's grammar/domain/independence
checks); `test_biome_registry.gd` (`_definition()` helper updated); `test_surface_material.gd`
(`_complete_biomes()` updated, +1 test for `biome_id_at()`). Full suite: `files=49 tests=678
assertions=122293 failed=0`. Compile probe OK (104 scripts) — hit 074/075's exact same
`BiomeTransition`-shaped shadowing gotcha, this time in `SubsurfaceMaterial.for_world()`:
locals named `surface`/`terrace` shadowed the class's own `surface()`/`terrace()` accessors.
Renamed to `bound_surface`/`bound_terrace`, matching `surface_material.gd`'s own
`bound_transition` precedent — this is now three bricks running into the identical trap, so
a future accessor named after a common noun (`surface`, `terrain`, `terrace`, `biome`) is
worth naming its constructor local something else from the start rather than fixing it after
the probe catches it. Also hit and fixed a real `integer_division` warning-as-error in
`self_check()` (`@warning_ignore("integer_division")`, `generation_grid.gd`'s exact
precedent). Headless boot OK.

`075` is the brick `BiomeDefinition` grew into a second time: `world/generation/
surface_material.gd` (`SurfaceMaterial`), one new file; `BiomeDefinition.surface_block_id`
(new field, four total now); two new block kinds (`block.sand`, `block.snow`, via a new
`tools/generators/generate_surface_blocks.gd`); the six `.tres` biome records regenerated
through `generate_biome_catalog.gd` with the field filled in; no change to
`BiomeClassifier`, `BiomeTransition` or any pinned generation signature.

```text
BiomeTransition.blend_at(column) -> {primary, neighbor, neighbor_weight}
        |
        +-- primary.surface_block_id                                  -> away from an edge
        +-- neighbor_weight > 0 and roll < neighbor_weight             -> neighbor.surface_block_id
                (roll = GenerationHash.value01_column(column, SALT_SURFACE_MATERIAL))
```

Five things worth keeping:

1. **A dither, not a blend, and the reason is the medium.** `neighbor_weight` (074) is
   continuous; a `VoxelBlockyModel` cube is one block or another. `block_id_at()` rolls a
   deterministic per-column value in `[0, 1)` and picks the neighbor's block under the
   weight, the primary's otherwise — `0` at `neighbor_weight = 0` (never wins, so a column
   away from every edge is always the primary), even odds exactly on a boundary. The
   dithered band this produces near an edge is the discrete-ground form of the "tint that
   does not jump" §13.5 already named. Its own salt, `WorldHash.SALT_SURFACE_MATERIAL`,
   appended rather than borrowed — `WorldHash`'s one-salt-per-pass rule.
2. **Two new blocks, not six.** Only grass/dirt/stone existed (038). Four of six biomes
   reuse them (grassland→grass, forest→grass — still grassy ground between trees until
   086–088 places any, mountain→stone — `RUGGEDNESS_MOUNTAIN` already means bare rock,
   wetland→dirt — swamp ground is honestly mud); desert→`block.sand` and snow→`block.snow`
   are genuinely new, because nothing already on disk is an honest stand-in for either.
   `generate_surface_blocks.gd` writes them with 038's exact speckled-placeholder-PNG
   technique — no Blender/bpy pass, matching the backlog row's own MCP note.
   `docs/world-generation.md` §14.2 has the full table and reasoning per biome.
3. **The cross-domain check lives where the two domains meet, not on `BiomeRegistry`.**
   `nextsteps.md` asked whether `BiomeRegistry.self_check()`/`coverage_reason()` needed a
   new coherence check for the field; the answer is no — `BiomeDefinition.surface_block_id`
   validates grammar and domain only (`BlockDefinition.drop_item_id`'s exact pattern), and
   `BiomeRegistry` stays unaware of `BlockRegistry` the same way it stays unaware of
   `BiomeClassifier`'s partition at the schema layer. The check that a `surface_block_id`
   actually resolves is `SurfaceMaterial.surface_block_reason_for(biomes, blocks)` — static
   and taking both registries, `BiomeRegistry.coverage_reason_for()`'s exact shape, and it
   is what `SurfaceMaterial.for_world()` refuses to build past.
4. **The version-bump question `nextsteps.md` asked 075 to answer explicitly, answered.**
   Not a bump — same reason as every Phase D brick since 062: no world has ever had a voxel
   written, so nothing here can contradict one. What's new is *where that stops being true*:
   the first later brick whose `VoxelGenerator` actually calls `block_id_at()` to fill a
   `VoxelBuffer` is where `SALT_SURFACE_MATERIAL`, every `surface_block_id` and (from that
   point on) `BiomeTransition.TRANSITION_WIDTH` become pinned generation inputs like
   `BiomeClassifier`'s thresholds already are. Recorded rather than assumed,
   `docs/world-generation.md` §14.4 — this is the answer to §13.6's own forward flag, too:
   `TRANSITION_WIDTH` is now an input to a material choice, not only a tint.
5. **Reference: none, a third time.** §12.5 and §13.5's finding applies again — no discrete
   biome means no discrete material either, so there is no material-selection mechanism in
   either binary to diverge from. `docs/world-generation.md` §14.5;
   `docs/reference/traceability.md` §4 and `matrix-world.md` §2 both updated.

Docs: `docs/world-generation.md` §14 (new, six subsections); `docs/reference/
traceability.md` §4 (075 added to the original-design list); `matrix-world.md` §2 (biome
colour row, 075 added to `Bricks`).

Tests: `tests/unit/test_surface_material.gd` (new, pins `signature()` `671f7833af3596ab`
against the shipped catalogs on the `typed` world); `test_biome_definition.gd` (+3, the new
field's grammar/domain/independence checks); `test_biome_registry.gd` (`_definition()`
helper updated so every fixture registration still validates); `test_block_set.gd` (counts
moved 3→5 records, 4→6 library models for the two new blocks). Full suite: `files=48
tests=653 assertions=122029 failed=0`. Compile probe OK (102 scripts) — hit the same
`BiomeTransition`-shaped shadowing gotcha 074 already recorded below (`transition`/`biomes`
locals shadowing this file's own accessor methods of the same name; renamed). Headless boot
OK.

`074` is the brick that resolved the question 065–067 kept handing forward: bricks 068–073
("implement the grassland biome" through "implement the aquatic/wet biome") turned out to own
**nothing** once actually checked against `docs/world-generation.md` §12.2's ownership table
— every field they could plausibly add belongs to 075–076, 080, 085 or 086–088, none of which
exist yet. Rather than write six bricks that each add a field nothing reads,
`backlog.md` now marks all six `FOLDED`, pointing at the brick that will actually add their
content, and 074 — the one biome-related task `BiomeClassifier.sample_at()`'s own doc comment
already named as its reader — is implemented in their place. One new file,
`world/biomes/biome_transition.gd` (`BiomeTransition`), no change to `BiomeClassifier` or
any generation field, no new salt, no new hash. `docs/world-generation.md` §13 is the full
writeup; `docs/reference/traceability.md` §4 records it as original design, for §12.5's
reason — the reference has no discrete biome and so no boundary to smooth.

```text
BiomeClassifier.sample_at(column) -> (t, h, r)
        |
        +-- classify(t, h, r)                         -> primary id      (unchanged, 066)
        +-- nearest_boundary(t, h, r)  [5 threshold probes, real classify() calls]
                -> (neighbor id, field-unit distance)
                        -> _weight_for_distance()  [ValueNoise.fade(), TRANSITION_WIDTH=0.15]
                                -> neighbor_weight_at(column) in [0, 0.5]
```

Six things worth keeping:

1. **The neighbor is found by calling the real function, not by re-deriving its precedence.**
   `classify()` is a decision list (§11.1): a column deep in `SNOW` can sit numerically close
   to `HUMIDITY_WOODED` and that closeness means nothing, because temperature already decided
   the answer before humidity was ever read. `nearest_boundary()` nudges one input at a time
   to just the other side of each of the five thresholds and calls `BiomeClassifier.
   classify()` again rather than hand-encoding which rule shadows which a second time. A
   worked case in the test file catches exactly the failure a naive nearest-threshold
   calculation would have: a cold column 0.05 from the mountain cut reports `MOUNTAIN` as its
   neighbor even though a humidity cut sits numerically closer, because relief outranks
   climate (§11.3) and the probe reproduces that ordering by construction rather than by
   assumption.
2. **The width is derived, and the derivation is asserted at runtime because it cannot be a
   const expression.** `TRANSITION_WIDTH = 0.15`, exactly half of `BiomeClassifier.
   narrowest_climate_gap()` (`0.3`) — half, not the whole gap, so a column at the midpoint of
   the *narrowest possible* climate band sees both neighboring blend zones fade to zero
   exactly there rather than overlapping into a three-way mix. `generate_biome_catalog.gd`'s
   constraint from brick 067 applies again: a function call is not a const expression in
   GDScript, so the identity is a `self_check()` and a test, not a comment trusted on faith.
3. **One width for all five thresholds is an honest simplification, named as one.** Ruggedness
   has no "gap" of its own to derive a width from — it is a single cut against a ceiling, not
   two cuts on a shared axis like temperature/humidity are. Reusing the climate width is the
   least invented number available, explicitly not a measured property of the ruggedness
   layer; a mountain-specific width is left to whichever of 072 or 085 first needs one, since
   neither exists to make that call today.
4. **73.5% of the unit cube sits within the transition width, and that is a measurement of
   the cube, not of the world.** The three humidity cuts sit exactly `2 · TRANSITION_WIDTH`
   apart, so their blend zones tile the humidity axis edge to edge with no gap between them.
   Conflating that with "73% of the world blends" would be wrong: a climate field only visits
   the cube along an 8192-metre-per-cell path, and the number that actually describes the
   *world* is still §11.5's — a mean biome run of 3.05–3.25 km, unchanged by this brick.
   `docs/world-generation.md` §13.4 states the distinction explicitly so it cannot be
   miscited later.
5. **Not a generation version bump, and more clearly so than any brick since 063.** Nothing
   here is generation: no hash, no salt, no noise layer, no field beyond what
   `BiomeClassifier.sample_at()` already produces. `BiomeClassifier.at()` is untouched and
   still pinned at `33a42963660cb452`. `GENERATION_VERSION` stays where it is — but see the
   flag left for 075 above: the moment a `TRANSITION_WIDTH`-derived weight becomes an input to
   a *material choice* rather than only a tint, that argument wants re-reading, not assuming.
6. **Reference: none, and the reason is the strongest form of "no reference" this project has
   recorded.** §12.5 already found the original has no discrete biome at all —
   `Terrain_computeBiomeColor` blends climate straight into a continuous colour — so there is
   no boundary-blending mechanism in either binary to diverge from, only the same "continuous
   under the hood" property arrived at from the opposite direction.

Docs: `docs/world-generation.md` §13 (new, seven subsections); `docs/reference/
traceability.md` §4 (074 added to the original-design list, alongside 063's identical
reasoning shape); `backlog.md` (068–073 marked `FOLDED` with their content's real
destination named in the brick description; 074 marked `DONE`; a new `FOLDED` status
convention added to Usage).

Tests: `tests/unit/test_biome_transition.gd` (new, 16 tests) pinning a golden
`neighbor_weight_at()` signature (`ab6dcc4542c8a2d1`). Full suite: `files=47 tests=634
assertions=121936 failed=0`. Compile probe OK (99 scripts).

**One tooling note, cheap to fix once seen:** the first draft of `blend_at_voxel()`
shadowed `BiomeTransition`'s own `classifier()` accessor by naming a local variable
`classifier` inside `for_world()` — GDScript's warnings-as-errors treats that as a parse
error (`res://tools/probe/check_scripts.gd`'s job), not a warning, so the compile probe
caught it before the test run rather than at runtime. Renamed the local to `biomes`,
matching the parameter name `BiomeClassifier.for_world()` itself already uses for the same
reason.

`067` is the first Phase D brick that is **content rather than a field**: no noise layer, no
salt, no constant, nothing sampled at a coordinate. Four new files under `world/biomes/` and
`tools/generators/`, six generated `.tres` files in a directory empty since brick 005, and
**no change to any existing file** except docs and the backlog row.

```text
data/biomes/*.tres  --BiomeCatalog.load_default()-->  locked BiomeRegistry
                                                       |
                              BiomeClassifier.at(column) -> id -> get_biome(id)
```

Seven things worth keeping:

1. **The catalog does not own the set, and that asymmetry is the brick.** `BiomeClassifier.
   IDS` stays the closed set; the catalog is checked against it in both directions, and the
   two failures are different animals. A record for an id nothing can classify is *dead
   content* — caught per entry, in `register_biome()`. An id with **no** record is a *broken
   world*, every column in it resolving to nothing, and no per-entry check can see it — so
   `coverage_reason()` runs once over the whole catalog. `BlockSet` (038) has no equivalent
   because blocks are an **open** set: a registry holding three or thirty is equally
   correct. That difference is the only reason `BiomeCatalog` is its own loader instead of a
   second call into `BlockSet`'s, and it is worth remembering before "deduplicating" the two
   directory scans.
2. **`coverage_reason_for(ids)` is static and list-taking on purpose.** `register_biome()`
   refuses an unclassifiable id, so a *live* registry can only ever be short — the
   unknown-id branch of the instance method is unreachable from any test that goes through
   the front door. The static form makes both branches reachable, and it is also what a save
   audit or a handshake wants: three places that hold ids before they hold definitions.
   A branch no test can reach is a branch nobody has run.
3. **Three fields, and the restraint is the design decision.** `id`, `display_name`,
   `debug_color`. Everything else the word "biome" suggests belongs to a brick that has not
   happened: materials 075–076, vegetation 086–088, spawns 095/106–107, transitions 074,
   water and snowline 080/085. A field nothing fills is worse than a record that grows, so
   the record is exactly what all six entries could fill today with nothing invented. §12.2
   carries the table, so 068–073 can check the owner before adding.
4. **`debug_color` is named for what it is for.** A flat opaque swatch for telling six
   biomes apart on an overlay — explicitly **not** the terrain or vegetation tint, which is
   075's material and Phase J's renderer. `palette_reason()` keeps every pair ≥ `0.25` apart
   in RGB (a guard against two biomes getting the same swatch, not colour science); the
   shipped palette's closest pair is grassland against mountain at **0.28**, and the test
   pins that margin so a recolour that scrapes past the threshold is visible.
5. **The reference has no biome catalog at all, and that is the finding.** Not a gap — a
   divergence. Nothing in either binary names a biome or looks one up: `Terrain_
   computeBiomeColor` and `terrain_biomeColorFromNoise` blend constants against
   temperature/humidity/height noise straight into terrain/vegetation RGBA, so a biome there
   is a **continuous colour**. `WorldInfo_generateBiomeContent` was opened (targeted read)
   and closed again: a placement routine with a ~6 KB stack frame, no recoverable record
   structure, and about content population (068+, 086–088, 095) rather than about what a
   record holds. The one idea taken from the reading is small and honest — the only
   per-biome datum the original carries is a *colour*, and this catalog carries one too,
   discrete and debug-only where theirs is continuous and is the terrain itself. §12.5.
6. **`matrix-world.md` Q4 is resolved, by decision rather than by reading.** It asked
   whether procedural region/place naming (`NameGen::generateRegionName`) belongs to the
   Phase D biome catalog. It does not: a biome record names a *kind* of place — six of them,
   permanent, identical in every world, keyed by a stable id — where a region name names
   *one* place, is generated per world from its coordinates, and is display text with no id
   at all. Deferred explicitly to the Phase J map/UI scoping pass (229), not left open.
   `traceability.md` §2 and §3 both updated; nothing in Phase D was ever blocked by it.
7. **Not a generation version bump, and the reason is stronger than 066's.** 066 could at
   least argue about its thresholds; 067 touches no hash, no layer, no salt, no threshold,
   no coordinate. Every pinned signature stands untouched and still asserted. Worth carrying
   forward: a `display_name` or `debug_color` edit is *never* a version bump, but adding,
   removing or renaming a biome **is** — because the ids are `BiomeClassifier`'s, and §11.8
   already calls a change to the partition a bump.

One structural note for later: `BiomeCatalog.load_default()` and `BlockSet.load_default()`
now share ~30 lines of `.tres` directory scan. Two uses is not yet three, and the completeness
check makes them genuinely different loaders (item 1), so the duplication was left in place
deliberately. The third catalog — items (Phase H) or creatures (Phase F) — is where a shared
`core/serialization/` loader should be extracted, and that brick should take all three.

Docs: `docs/world-generation.md` §12 (new, seven subsections);
`docs/reference/matrix-world.md` §2 (biome-content row annotated, new
`Terrain_computeBiomeColor` row, region-naming row retargeted) and §4 (Q4 resolved);
`docs/reference/traceability.md` §2 (three rows: Q4 resolved, 067–068 row annotated, new
biome-colour row; the stale "no brick" Q4 row removed) and §3 (Q4 status).
`docs/README.md` already named `world/biomes/` — unchanged.

Tests: `tests/unit/test_biome_definition.gd`, `test_biome_registry.gd`,
`test_biome_catalog.gd` (new, 39 tests together). Full suite:
`files=46 tests=618 assertions=93984 failed=0`. Compile probe OK (97 scripts), headless
boot OK.

**Tooling note that cost time this session:** the generator needed the **thin-entry/runner
split** from brick 052 and `generate_block_set.gd` does not, which is easy to mis-copy. A
`--script` entry file compiles before autoloads are registered, so it may not statically
reference `BiomeClassifier`/`BiomeRegistry`/`BiomeCatalog` — all three touch `Log`, directly
or transitively. `generate_block_set.gd` gets away with a single file purely because
`BlockDefinition` happens to touch nothing. Also: `Color8()` is a call, not a constant
expression, so a colour table cannot be a `const` — `records()` is a static function.
Everything ran through the engine binary from `docs/environment.md` directly
(`--import`, then `--script`), which remains more reliable than the `tools\scripts\*.ps1`
wrappers under a non-interactive shell.

`066` is the first brick whose answer is an **id**, and the first consumer of both climate
axes: `world/biomes/biome_classifier.gd` (`BiomeClassifier`), one new file in a directory
that had only a `.gitkeep`, **no** change to any existing file, no new salt, no new noise
layer, no constant touched anywhere below it.

The whole classifier is a six-line decision list over three `[0, 1]` inputs:

```text
ruggedness >= 1/sqrt(2)   -> biome.mountain     # relief outranks climate
temperature < 0.2         -> biome.snow         # cold outranks dry and wet
humidity    < 0.2         -> biome.desert
humidity   >= 0.8         -> biome.wetland
humidity   >= 0.5         -> biome.forest
otherwise                 -> biome.grassland
```

Seven things worth keeping:

1. **Three of the five thresholds are the reference's own literals, and that was the
   cheapest good decision available.** `terrain-climate-blend.md` claim 5 records the
   original reading climate on a bare `[0, 1]` scale against `< 0.2` and `> 0.8`. We cannot
   reuse its *mechanism* — 064 spent a full reference read establishing that it blends
   stored per-region values — but the **scale** it reads on is exactly ours, so its idea of
   "cold" and "very wet" transfers. `HUMIDITY_ARID` is written as `1 - HUMIDITY_WETLAND`
   rather than as `0.2`, so the two ends of the axis cannot drift apart. This is the note's
   one *convergence* rather than a divergence, and it is now a row in its §8 and two rows
   in its §9.
2. **`RUGGEDNESS_MOUNTAIN` is derived, not picked.** `1/sqrt(2)` is where
   `ErosionPass.ruggedness_weight()` reaches the middle of its own range, so rule 1 reads
   "a column that keeps more than half the relief in the world is a mountain" — a claim
   about ground rather than about a noise value, and one that moves with `ErosionPass` if
   that pass is retuned. The test asserts the *identity*, not the number. It reads the raw
   unsquared layer 062 deliberately left public; squaring is monotone, so the partition is
   the same and the number stays on the scale it is quoted on.
3. **The evenness of the result was not aimed at, and it is the measurement of the brick.**
   Over the climate-scale sweep on 12 seeds: snow `0.1941 .. 0.2102`, grassland
   `0.1597 .. 0.1775`, forest `0.1572 .. 0.1775`, desert `0.1465 .. 0.1628`, wetland
   `0.1479 .. 0.1589`, mountain `0.1426 .. 0.1616` — against an even sixth, `0.1667`. Six
   rules land within a factor of `1.5` of each other with no constant chosen for balance,
   because `spread()` already leaves each climate axis with about a quarter of the world
   below `0.2` and a quarter above `0.8` (§10.2), so `0.2 / 0.5 / 0.8` quarters an axis.
   Test bands `[0.12, 0.24]`, on all four fixture worlds.
4. **The order of the rules carries as much as the numbers.** Relief above climate (a
   mountain is a mountain in any weather — the one input visible from a distance); cold
   above dry and wet (cold-dry is tundra, cold-wet is taiga, and with six biomes both are
   `biome.snow`). Both are asserted across a whole axis rather than at a point, so a
   re-ordering fails before it becomes a map with no mountains in the cold half.
5. **A classifier owes different tests from a field.** `range_reason()` has no meaning —
   there is no range — and `test_answers_only_with_ids_it_declares` replaces it, checking
   `typeof() == TYPE_STRING` as well as membership, because a classifier that started
   answering with an index would pass a naive `IDS.has()` on nothing at all. `signature()`
   still applies and is type-strict: pinned at `33a42963660cb452`. `variation_reason()` is
   **2**, not 8 — 063's §8.4 finding one level worse, since the fixture columns sit inside
   about one 16384-voxel climate cell; the world-scale claim is item 3 above.
   `classify()` being static and pure is what lets totality, rule order and the half-open
   boundary convention be asserted exhaustively over a 21³ grid of the unit cube with no
   world attached.
6. **Both decisions `nextsteps` handed 066 were answered "no", and both now have reasons
   rather than deferrals.** *Base class for the two climate axes* (§10.5's question): no —
   the first consumer reads them **by name**, not by iteration, and treats them
   asymmetrically (one cut on temperature, three on humidity, and an order between them),
   so a common type buys nothing at the only call site there is. *Coastal wetness* (§10.1
   decision 2): declined here too, for a reason of 066's own — a coast is a place you can
   only see once there is water in it, and the waterline is brick 080; a `biome.coast`
   drawn on continentalness alone would put a boundary where nothing on the ground changes.
   A fourth input is one rule and one field whenever 074 or 080 wants it.
7. **The slivers are real and the test says so.** On the 800 km line: 123–131 runs, mean
   run **3.05 – 3.25 km**, all six biomes present on every fixture world's line — but the
   shortest run is `0.025 – 0.125 km`. A threshold on a continuous field always grazes a
   boundary somewhere and no constants remove that, so the test asserts the **mean**; a
   minimum-run assertion would test where the line happens to be. That measurement is what
   brick 074 inherits. `minimum_climate_band_voxels()` is the derived floor on the
   *climatic* boundaries only — `1048` voxels = **524 m** — and explicitly not a promise
   about the map, since the mountain rule reads a field eight times finer.

One naming deviation, deliberate: the field accessors are `temperature_field()`,
`humidity_field()`, `erosion_pass()`, where `ErosionPass.elevation()` and
`TerracePass.erosion()` are bare nouns. In this file `temperature` and `humidity` are the
names of `classify()`'s **values**, and a bare accessor shadows them — a warning under
warnings-as-errors and a confusing read regardless.

**Not a generation version bump** (§11.8): a new consumer that changes no constant, no hash
and no existing field, appends no salt, and leaves every pinned signature below it
(`0babd0a337dd7cab`, `cc4f0f5ecb8fa581`, `2af464f70e43590a`, `fb91406f3e801b7f`,
`76802ec9aa907fee`) untouched and still asserted. Its own five thresholds join the pinned
set from here on.

Docs: `docs/world-generation.md` §11 (new, nine subsections);
`docs/reference/terrain-climate-blend.md` §1 scope, §8 (two new rows: the taken literals,
and the region-site classification we do not copy), §9 (five new test rows), header rows;
`traceability.md` §2's `064–067` row; `docs/README.md`.

Tests: `tests/unit/test_biome_classifier.gd` (new, 29 tests, ~10000 assertions). Full
suite: `files=43 tests=579 assertions=93731 failed=0`. `check.ps1` OK (89 scripts).

**Two tooling notes from this session, both cost time:**

- A new `class_name` is invisible to `godot --script` probes until the project is
  re-imported. `tools\scripts\test.ps1` does this itself (`Update-ClassCache`); a bare
  `godot --headless --script …` does not. Run `godot --headless --import` first, or the
  probe fails with `Identifier "X" not declared in the current scope` and then **hangs**
  rather than exiting.
- Invoking `tools\scripts\*.ps1` through a non-interactive PowerShell wrapper failed with
  `Impossible d'extraire la variable $LASTEXITCODE` and swallowed the engine's output.
  Calling the engine binary from `docs/environment.md` directly worked for every step
  (`--import`, `--script res://tools/probe/check_scripts.gd`,
  `--script res://tests/run_tests.gd`).

`065` is 064's mirror and the second **climate** axis:
`world/generation/humidity_field.gd` (`HumidityField`), one new file, salt
`WorldHash.SALT_HUMIDITY = 3` (in the list since brick 015, no user until now — nothing
appended), same constants as temperature, same `spread()` curve by call rather than by
copy. It is also the first brick to **correct** an earlier brick's measurement, and that is
the half worth reading.

The field itself is one line and 064 already argued it:

```text
at(column) = fade( noise01(column) ),   cell 16384 voxels, 2 octaves, gain 0.5
```

`nextsteps` handed 065 three questions and all three answered **no** — no
`Continentalness` term, no coupling to temperature, no shared base class
(`docs/world-generation.md` §10.1, §10.5). The reference is what settles the first:
`terrain-climate-blend.md` claim 1 finds no continentalness term in the original's
humidity, and taking one would make humidity the first climate axis derived from another
field, which §9.3 spent a whole reference read establishing climate is not. Coastal
wetness stays available to 066/074 *visibly, on top of two independent axes*. `U1` (which
region word the original's humidity blends) was checked before designing and confirmed not
to gate the brick — a noise layer cannot care — and is recorded as checked in the note.

Six things worth keeping:

1. **The constants really are 064's, and that was measured rather than inherited.** Run on
   its own layer over 24 climate layers (12 seeds × both climate salts): every decile of
   `at()` holds `7.1% .. 15.8%` of the world, sd `0.312 .. 0.320`, span `0.0000 .. 1.0000`
   exactly. Same field, different values — which is what the reference describes (`INV-3`:
   same window, same warp, same weight, a different region word). The alternatives fail as
   they did for temperature and the wider sweep sharpens it: **no curve** leaves under 3%
   in each end decile, **two applications** puts 27–31% there.
2. **065's finding: the standard sweep cannot measure a climate field.** Every Phase D
   field before this is measured on a 2304-column sweep at spacing 4093 — four independent
   samples per relief cell, excellent; but a **quarter of one climate cell**, so about
   **144 independent climate cells**, and everything measured on it moves more than what
   it measures. Evidence, on that sweep, all four fixture worlds: temperature's smallest
   decile reads `0.037 .. 0.072`, its sd `0.251 .. 0.280`, and `r`(humidity, temperature)
   swings to `−0.148` between two fields sharing no salt, no offset and no term — which is
   just the standard error of a correlation over ~144 samples (~`0.08`).
3. **So §9.5's numbers were an artifact and 064's decile test passed by luck.** It asserted
   `0.05 ≤ decile ≤ 0.16` and `sd > 0.26` on `WORLD_TYPED` alone; **three of the four
   fixture worlds fail it**. Corrected in place rather than worked around: both climate
   test files now use a **climate-scale sweep** — 64 × 64 columns at spacing `16381` from
   `−524192`, 1032003 of the world's 1048576 voxels per axis, inside `WorldBounds`, prime
   spacing just under the cell so samples walk the lattice phase — and every distributional
   and correlational test runs on **all four worlds**. §9.5 is struck through in place, not
   deleted (`confidence.md` §4), and §10.4 carries the corrected measurement.
4. **The real distribution is a mild U, not "almost uniform".** sd `0.316` against a
   uniform field's `0.289`, with the end deciles the fattest: `fade()` moves mass outward
   faster than it thins the middle, and 4096 independent cells are enough to see the tails
   the old sweep missed. Better for 066, not worse — the extremes are the hardest columns
   to find. One claim was **withdrawn** rather than re-tuned: §9.5 said the raw layer
   "reaches neither end" (`0.016 .. 0.983`); over 4096 cells it reaches `0.004 .. 0.994`.
   Reaching an end on 0.1% of the world is not having a decile there, so the assertion is
   now distributional (each end decile under 3%), which is both true and what mattered.
5. **Independence is the property, and it is what makes the pair worth two fields.** Over
   the climate-scale sweep, worst case across all four worlds: `|r|` `0.023` against
   temperature, `0.021` against ground height, `0.013` against continentalness. In the form
   066 will use it: over a 4×4 grid of the climate square on 12 seeds, **every one of the
   16 cells holds `3.9% .. 9.3%`** of the world against an even `6.25%` — the corners (hot
   desert, hot swamp, cold desert, tundra) are the *fattest* cells, because both axes are
   U-shaped. On one 800 km line the two axes are `0.94` apart at their widest.
6. **What was coupled is not a base class** (§10.5). Three lines name `TemperatureField` —
   the three constants, and `spread()` by call — so the two axes cannot silently drift to
   different scales or different curves, and a test asserts the equality. Neither inherits
   from the other; retuning one axis stays a one-line edit plus a test failure that asks
   whether the other meant to follow. 066 is the brick entitled to factor them.

The line geometry is the one place 065 deliberately differs from 064: **800 km, not 400**.
At 400 km this field's line at `z = 613` spans `0.088 .. 0.994` — it never reaches its dry
end. A climate field is not obliged to cross its whole range in any particular 400 km, and
hunting for a latitude where it does would be tuning the test to the seed. At 800 km the
line spans `0.008 .. 0.996` with a worst kilometre of `0.308`, inside the derived `0.572`.
`max_step_per_voxel()` = `0.000286` and `minimum_climate_span_voxels()` = **3495 voxels =
1.75 km**, identical to temperature's and asserted equal to it.

**Not a generation version bump** (§10.6): a new field that changes no constant, no hash
and no existing layer, appends no salt, and leaves every pinned signature below it
(`0babd0a337dd7cab`, `cc4f0f5ecb8fa581`, `2af464f70e43590a`, `fb91406f3e801b7f`) untouched
and still asserted. The §10.4 correction touches test files and documentation only.

Docs: `docs/world-generation.md` §10 (new, seven subsections) and §9.5/§9.7 corrected in
place; `docs/reference/terrain-climate-blend.md` §8 (two new divergence rows: the
identical-but-for-salt axes, and the refused continentalness term), §9 (five new test
rows), `U1` marked checked-by-065, `U2` updated with the corrected distribution;
`traceability.md` §2's `064–067` row now cites both fields and §9–§10.

Tests: `tests/unit/test_humidity_field.gd` (new, 28 tests) pinning a golden `signature()`
(`76802ec9aa907fee`); `tests/unit/test_temperature_field.gd` corrected (its four sweep
tests moved to the climate-scale sweep and to all four worlds, plus a new
`test_the_sweep_is_wide_enough_to_measure_a_climate` guard). Full suite: `files=42
tests=550 assertions=83696 failed=0`. `check.ps1` OK (87 scripts).

**065 exposed that the repository was missing, and it was re-established after the
brick.** `git rev-parse` reported "not a git repository" and there was no `.git`
anywhere — not in the project, not in any parent — so the per-brick commit and the
`git diff` review of `CLAUDE.md` §5 could not run for 065. Only the tracked-file
markers had survived (`.gitignore`, `.gitattributes`, the `.gitkeep` placeholders),
which is what a zip download leaves behind. Nothing was recoverable, so the history
was **not** reconstructed: `git init -b main` plus one baseline commit (`81100f7`)
carrying the on-disk state after 065. Bricks 001–065 are that one commit; the one-commit-
per-brick convention resumes at 066. `reference/` stayed untracked on §16's IP
discipline, and `.godot/` on `.gitignore`.

`064` is the first **climate** field and the first brick since 061 to open the reference
tree: `world/generation/temperature_field.gd` (`TemperatureField`), one new file, **no**
change to any existing file, and no new salt — `WorldHash.SALT_TEMPERATURE = 2` has been in
the list since brick 015 with no user, and 064 is its user.

The whole field is one line, and the line that matters is the second half of it:

```text
at(column) = fade( noise01(column) ),   cell 16384 voxels, 2 octaves, gain 0.5
```

Six decisions worth keeping:

1. **The reference read is the brick's centre, and it contradicted a standing claim.**
   `terrain-base-height-field.md` `U2` (opened by 061) asked whether climate rides on
   elevation's squared weight fields. Full read of `World_temperatureBlend`
   (`server/world/World.cpp:4167–4365`) and `World_humidityBlend` (`4376–4491`), written up
   as **`docs/reference/terrain-climate-blend.md`**: the answer is **no**. The original
   takes *no* noise sample for a climate value at all — it blends stored per-region values
   over a nearest-site window. `U2` is closed and that note's `MEDIUM` claim 7 is
   **contradicted**, struck through in place rather than deleted (`confidence.md` §4).
   The only thing climate and elevation share is the ±768-unit noise that jitters the
   region sites, which moves where a boundary falls and never what the value is.
2. **So temperature is its own axis, and the test measures that rather than asserting it.**
   Its own salt, its own layer, and `|r| < 0.05` against both `ErosionPass.at()` and
   `Continentalness.at()` over the standard 2304-column sweep — measured `+0.007` and
   `−0.006`. If a later edit ever derived climate from a height, it fails there before it
   shows up as every mountain being cold.
3. **No lapse rate, and that is 085's brick, not an omission.** Written into §9.3 and into
   the class comment: cold peaks are the snowline reading *this field and a height*. Baking
   the altitude term in here would make every high place cold in every world and take the
   decision away from the brick that owns it. Same reasoning for the unit: the original
   reads its climate off a bare `[0, 1]` scale (`> 0.8`, `< 0.2`), and a degree scale here
   would be a number nothing in this project could check.
4. **Climate is the coarsest field in the world, and the octave count is what says so.**
   Cell 16384 = twice `Continentalness.CELL_SIZE_VOXELS`; two octaves, so the *finest*
   climate cell is 8192 — exactly the coarsest cell of both `Continentalness` and
   `ErosionPass`' ruggedness. §6.4's "meet, don't overlap" rule one level up. The test
   asserts the inequality against those two constants, not the octave count. The ordering
   is the original's: its climate window is `0x4000` units across against relief tiers of
   ~5000 and weight fields of ~10000.
5. **`spread()` is the quintic used as a redistribution, and it is the measured half of the
   brick.** Summed octaves cluster: the raw layer puts **69.8%** of the sweep in the middle
   four deciles and reaches neither end (`0.016 .. 0.983`) — a climate field on which no
   threshold 066 could pick selects a desert, because those columns do not exist. One
   `ValueNoise.fade()` fixes it: `fade'(0.5) = 1.875` pulls the middle apart, `fade'(0) =
   fade'(1) = 0` pushes the tails to the ends, and it is monotone with fixed points at both,
   so ordering and the stated range survive untouched. sd `0.181 → 0.280` against
   `1/sqrt(12) = 0.289` for uniform, and the sweep now spans `0.0000 .. 0.9999`. One
   application, **not two**, and no linear stretch first: both were measured and both
   overshoot into a bimodal map with a fifth pinned at each end (`fade(fade(x))`: 20.6% /
   27.0%). Three octaves instead of two also visibly peaks the histogram. Reusing the
   project's one blending polynomial keeps §5.3's promise — nothing new to keep in step with
   `FADE_MAX_SLOPE`.
6. **The test pins the property, not the histogram**: no decile of the range holds less than
   5% or more than 16% of the world. That is what 066 actually needs — a threshold anywhere
   in the range selecting a real share of the map — and it survives retuning that a pinned
   histogram would not.

Measured: `max_step_per_voxel()` = `0.000286` and `minimum_climate_span_voxels()` = **3495
voxels = 1.75 km**, the derived floor on how far apart the coldest and hottest column can
be. On a 400 km east–west line at `z = 613`, the **worst** kilometre anywhere moves the
temperature by `0.301` — inside the derived `0.572`/km — while the line as a whole spans
`0.011 .. 0.999`. Gentle everywhere and both ends present: that pair is the brick.

**Not a generation version bump** (§9.6): a new field that changes no constant, no hash and
no existing layer, appends no salt, and leaves every pinned signature below it
(`0babd0a337dd7cab`, `cc4f0f5ecb8fa581`, `2af464f70e43590a`) untouched and still asserted.

Docs: `docs/world-generation.md` §9 (new, seven subsections); new
`docs/reference/terrain-climate-blend.md`; `terrain-base-height-field.md` claim 7 struck
through and `U2` marked `(RESOLVED — brick 064)`; `docs/README.md` and `traceability.md`
§2 list the new note.

Tests: `tests/unit/test_temperature_field.gd` (new, 23 tests, 706 assertions) pinning a
golden `signature()` (`fb91406f3e801b7f`). Full suite: `files=41 tests=521
assertions=83195 failed=0`. `check.ps1` OK (85 scripts).

`063` is the brick that turns the height field into a **block world**:
`world/generation/terrace_pass.gd` (`TerracePass`), one new file, **no** change to any
existing file — no new salt, no new noise layer, no constant touched anywhere below it.
`ErosionPass`' pinned signature `cc4f0f5ecb8fa581` is unchanged and still asserted, which
is the check that it really is downstream-only.

The whole pass is one line, and that is the design:

```text
at(column) = floor(erosion.at(column) / H) * H,   H = TERRACE_HEIGHT_VOXELS = 8 (= 4 m)
```

Six decisions worth keeping:

1. **It reads `ErosionPass`, not `ElevationField`** — the backlog dependency row says 061,
   but terraces laid over unshaped ground would make 062 invisible
   (`docs/world-generation.md` §7.6). Every future shaping term (rivers, roads, structure
   flattening — 080–083, 089–090) belongs *underneath* this pass, in §7.1's product:
   applied after quantisation it would produce heights that are not terrace planes and
   every consumer of `surface_y()` would have to re-snap them.
2. **`floor`, never `round`, and it keeps the family invariant.** `floor` is monotone, so
   `base <= erosion.at()` gives `terraced(base) <= at()`, and §7.1's shape survives in
   terraced form: `terraced(base_at) <= at <= erosion.at`, never more than one terrace
   below where it started. Rounding would raise ground as often as it lowers it and break
   the family outright. Stated honestly in §8.1: the *unterraced* base stops being a lower
   bound, because a column just above its base is pulled past it by under one terrace.
3. **The terrace height was pinned by 061, not chosen here.** `RELIEF_OCTAVES = 6` puts the
   finest relief cell at 32 voxels = **four times** 8 (§6.4); coarsen the terrace and 061's
   finest octave is rounded away entirely. The test asserts
   `finest_relief_cell == 4 · TERRACE_HEIGHT_VOXELS` rather than the constant alone, so the
   two cannot drift apart. Terrace planes are anchored to the **datum** (`y = 0` is a
   boundary), and the negative side floors rather than truncating toward zero — truncation
   would put voxel −1 and voxel 0 on one shelf and mirror the staircase about the origin,
   the same defect `GenerationGrid.floor_div()` avoids one level down (§3.5).
4. **`max_step_per_voxel()` is replaced, not dropped.** This is the first pass whose output
   is deliberately discontinuous, so a per-voxel slope bound means nothing. What replaces
   it is `max_riser_voxels() = ceil(erosion.max_step_per_voxel() / H) · H`, because
   `floor(a/H)` and `floor(b/H)` differ by at most `ceil(|a−b|/H)` steps. 062's bound is
   `2.627`, comfortably under one terrace, so **every riser in the world is a single 4 m
   face and never a stacked cliff** — a derived consequence of the constants, and a number
   that would grow and say so if a later pass steepened the ground.
5. **A power of two, and that is a determinism decision.** `h / 8.0` is an exact exponent
   shift for every finite double and `floor` is exactly specified by IEEE-754, so the pass
   is bit-identical on every platform — §5.3's `cos`/`pow` argument applied to a division.
6. **`variation_reason()` is asserted at 2 here where every other Phase D pass uses 8**,
   and that is the pass working rather than a weakened check. `GenerationFixtures.columns()`
   is a list of deliberately *nearby* coordinates; 062 answers 15 distinct heights there but
   they span barely 12 voxels, so quantising lands on exactly two shelves (`+64`, `+56`).
   The real variation check runs over the 2304-column sweep and demands a *populated span*
   of terraces (§8.4).

Measured over the same sweep 060/061/062 used: lowest `−96.0` (was `−95.7`), highest
`+144.0` (was `+148.6`), mean `−8.9` (was `−5.1`), 49.8% above the datum (unchanged). It
removes `3.9` voxels from the average column — half a terrace, which is what a floor over a
field with no preferred phase should remove — and never a whole one. The sweep lands on
**31 distinct terraces spanning indices −12…18**: every terrace in the span is populated.
The kilometre walk at `z = 613` is now **1992 flat steps and 8 risers**, each exactly one
terrace; the same line under 062 had *zero* flat steps. That contrast is the brick.

**Not a generation version bump** (§8.7): a new pass that changes no constant, salt, hash
or existing field, and no world has ever had a voxel written from this chain, so there is
no world whose terrain it could contradict. That stops being true the moment a generator
writes voxels — from then on `TERRACE_HEIGHT_VOXELS` is a bump like any other pinned
constant.

**Reference read**: none, and that is recorded rather than assumed.
`terrain-base-height-field.md` contains no claim about vertical quantisation, so terracing
is **original design** within the pass shape 062 established — written up as
`docs/world-generation.md` §8.6, with `traceability.md` §2's `061–063` row annotated to say
so and 063 added to its §4 "original design" list. The reference note itself is unchanged.

Docs: `docs/world-generation.md` §8 (new, eight subsections); `traceability.md` §2 and §4.

Tests: `tests/unit/test_terrace_pass.gd` (new, 26 tests, 51 326 assertions) pinning a
golden `signature()` (`2af464f70e43590a`). Full suite: `files=40 tests=498
assertions=82482 failed=0`. `check.ps1` OK (83 scripts).

`062` is the first brick that is a **pass** rather than a field:
`world/generation/erosion_pass.gd` (`ErosionPass`), one new file, one appended
`WorldHash.SALT_RUGGEDNESS = 11`, and a three-line pure refactor of `elevation_field.gd`
(`base_for(shore)` extracted next to the existing `relief_amplitude_for(shore)`, output
bit-identical — **not** a version bump; 061's pinned signature `0babd0a337dd7cab` is
unchanged and still asserted).

The problem it fixes: 061 gives every landward column the *same* relief budget, so every
stretch of land was equally hilly — no plains, and no ranges to stand out against them.
`ErosionPass` takes 061's terms apart and puts them back with the relief scaled down:

```text
shore  = elevation.shore_at(column)                          # one continentalness sample
relief = ruggedness(column) · valley_shaped(relief01(column)) # both in [0, 1]
height = base_for(shore) + relief_amplitude_for(shore) · relief
```

Five decisions worth keeping:

1. **It is a pass, and the invariant says so:** `base_at <= at <= unshaped_at`. Every term
   multiplies relief by something in `[0, 1]`; nothing touches the base. That is the shape
   of all four of the original's own post-passes (`terrain-base-height-field.md` `INV-2`),
   and it buys three things — the range is *inherited* from 061 rather than restated (both
   ends still reachable, so still a closed range), rivers/roads/structure flattening
   (080–083, 089–090) join the same product instead of rewriting it, and "the pass only
   lowers" is a per-column assertion rather than a claim.
2. **The squaring is the mechanism, and it is the original's** — the half of claim 3 that
   061 deliberately left here. `ruggedness_weight(w) = FLOOR + (1 − FLOOR)·w²` places
   relief before it is detailed; `w²` puts most of its mass near zero, so **flat is the
   default and rugged is the exception**. Measured mean weight `0.342` against a
   `[0.1, 1]` midpoint of `0.55` — the `1/3` the reference note predicts, shifted by the
   floor. `RUGGEDNESS_FLOOR = 0.1` because `w²` reaching zero is a mathematical plane, and
   a plane is not a plain (12.8 voxels = 6.4 m of roll on the flattest ground).
3. **A weight field must be coarser than what it weights.** Cell `8192` (8 regions —
   powers of two are the nearest thing we have to the original's decade), 3 octaves, so
   the *finest* ruggedness cell (2048) is twice the *coarsest* relief cell (1024). A
   weight octave finer than a relief octave stops placing relief and starts being relief,
   with a multiplier's amplitude and no slope bound of its own. The test asserts the
   inequality, not the octave count.
4. **`valley_shaped(r) = lerp(r, r², 0.5)` is the "erosion" half of the brick title** —
   fixed points at `0` and `1`, strictly below in between, so material comes off the
   hillsides while the valley floor and the ridge line stay where 061 put them and the
   stated range survives untouched. Both curves are integer powers written as
   multiplications, **never `pow()`**: §5.3's `cos` argument, unchanged — libm is not
   bit-reproducible and both sides generate.
5. **`max_step_per_voxel()` went up, from 2.179 to 2.627, while every height went down.**
   Not a mistake: `v'(r) = (1 − k) + 2kr` peaks at `1 + k` on a ridge line, so the valley
   bias multiplies the relief's own slope by up to 1.5 where relief is highest. **The pass
   lowers ground but can locally steepen it** — which is the point of an erosion pass, and
   the bound is what keeps "steeper" from becoming "a cliff". Stated plainly in the code
   and in `docs/world-generation.md` §7.4 rather than left for someone to rediscover.

Measured over the same 2304-column sweep 060/061 used: lowest `−95.7` (was `−93.2`),
highest `+148.6` (was `+180.5`), mean `−5.1` (was `+24.3`), 49.8% of columns above the
datum (was 53.1%). It removes `29.4` voxels from the average column and `89.2` from the
one it flattens hardest, and the extremes survive — the sweep still reaches both an ocean
basin and high ground. The mean falling below the datum is **not** a statement about sea
level: `y = 0` is a datum, the land fraction is still 080's decision, and 080 now gets a
world whose ground under the waterline is genuinely varied.

**Reference read**: none new. 062 is the implementation of a finding 061 already recorded
(`terrain-base-height-field.md` §3 claim 3 and §8's fourth divergence row), so the note was
*updated* rather than re-read: claim 3's row now reads **kept, once, by 062** with the
reasons it is one weight layer and not three; claim 6's row records that `INV-2` became
this pass's contract; §9 gains three test rows; the header's brick and Godot-contract rows
now name `erosion_pass.gd` and §7. `traceability.md` §2's `061–063` row cites the new file.

Docs: `docs/world-generation.md` §7 (new, six subsections);
`docs/reference/terrain-base-height-field.md` updated as above; `traceability.md` §2.

Tests: `tests/unit/test_erosion_pass.gd` (new, 23 tests, 19 672 assertions) pinning a
golden `signature()` (`cc4f0f5ecb8fa581`). Full suite: `files=39 tests=472
assertions=31149 failed=0`. `check.ps1` OK (81 scripts).

`061` is the first field that answers a question about **terrain** rather than about the
world map: `world/generation/elevation_field.gd` (`ElevationField`), one new file plus a
three-line change to `value_noise.gd`.

Elevation is a **signed height in voxels measured from `y = 0`** — the centre of
`WorldBounds`' vertical extent, and a datum, *not* a sea level (080 still owns the water
plane, and it is a constant applied to these numbers rather than a property of them).
Composition, per column:

```text
shore     = shore_weight(continentalness)                    # quintic over [0.42, 0.58]
base      = lerp(-96, 64, shore)                             # voxels
amplitude = lerp(128 * 0.25, 128, shore)
height    = base + amplitude * relief01(column)              # relief01 in [0, 1]
```

Range `[-96, +192]` voxels = `[-48 m, +96 m]`, both ends inside a quarter of
`HALF_EXTENT_VERTICAL_VOXELS` so 077's caves have room below and there is sky above (the
test asserts the headroom rather than trusting it). Relief layer: cell `1024`, 6 octaves,
gain `0.5`, `WorldHash.SALT_ELEVATION`.

Five decisions worth keeping:

1. **Relief is additive-upward, never signed** — the base is a genuine floor, so an ocean
   floor cannot be turned into a mountain by a noise sample, and `MINIMUM_VOXELS` has an
   exact value instead of a bound. This is the one shape decision taken from the original
   (see the reference read below), and it is what `test_relief_never_digs_below_the_base`
   pins.
2. **The relief layer's coarsest cell is exactly `Continentalness`' finest cell** (one
   region, 1024 voxels). The two fields *meet* at the region grid instead of overlapping:
   continentalness carries every scale coarser than a region, relief every scale finer.
   Six octaves put the finest relief cell at 32 voxels = 16 m — four times the terrace
   height 063 will quantise to, so the detail survives that pass instead of being rounded
   away by it.
3. **The shore band is narrow (`0.16`) and centred on `0.5`**, the field's own middle.
   Narrow so the transition is a *coast* rather than a world-wide ramp; centred because
   how much of the world is **land** is 080's decision (where the water plane goes), not
   something 061 should pre-bake — §5.6 promised the land-fraction target to the brick
   that makes it, and this is that promise kept.
4. **The shore curve is the quintic, through `ValueNoise.fade()`, not a cubic
   `smoothstep()`.** §5.3's argument one level up and it bites harder here: a `C¹`-only
   curve leaves a slope discontinuity at each end of the band, and a slope discontinuity
   in a *blend* becomes a crease along a continentalness contour — in-game, a
   straight-edged terrace following the coast at exactly the band's edge. `_fade()` was
   renamed to `fade()` for this (output unchanged, so **not** a version bump); it is now
   the project's one blending curve, so nothing has a second copy to keep in step with
   `FADE_MAX_SLOPE`.
5. **`max_step_per_voxel()` is derived, not measured**, like 060's: `(coast span +
   amplitude swing) · shore_max_slope() · continentalness step + amplitude · relief step`
   = **2.179 voxels per voxel**. `shore_max_slope()` = `FADE_MAX_SLOPE / SHORE_WIDTH` =
   `11.719` is named rather than inlined, because narrowing the band steepens the coast in
   exact proportion. A real kilometre walk across the origin measures a largest step of
   `0.231` and 95 voxels of climb; `test_the_step_bound_is_a_real_constraint` runs the same
   check over raw `GenerationHash` values at the same amplitude, where it fails on
   essentially every step, so the assertion is known to be capable of failing.

Measured over the same 2304-column sweep 060 used: lowest `-93.2`, highest `+180.5`, mean
`+24.3` voxels; 50.1% of columns landward of the shore midpoint, 53.1% above the datum.

**Reference read** (`traceability.md` §1: 061 sits in the `060–067` rows and in
`region-coordinate-hashing.md`'s `058, 061, 089–090` row, no gating question): full read of
`World_baseHeightField` (`server/world/World.cpp:4496–4900`), recorded as
**`docs/reference/terrain-base-height-field.md`**. It closes `terrain-value-noise.md`'s
`U2`. Findings: the ladder is **three decade-spaced relief tiers** (`0.0002` ×2 at
amplitude 200, `0.002` ×2 at 100, `0.01` ×1 at 40), not an fBm; every term is
**positive-only** (`(noise + 1) · k`), so relief stacks upward on a base; **each tier's
amplitude is modulated by a separate noise field one decade coarser, squared** (`w²` has
mean `1/3`, so flat is the default and mountains are the exception); the **base itself is
blended from region-array heights**, not from noise, with the region sites jittered ±768
units by noise; and four post-passes (river/climate gate, roads, water depth, structure
falloff) all scale relief *toward* the base and never away from it. §8 is the divergence
table — we keep only the additive-upward shape, because their base is world *state* where
ours must be a pure function of `(seed, column)`.

The squared per-tier weight field is deliberately **left to 062**: a per-place ruggedness
field is a shaping decision, and 061 modulates by the field it already has. It is written
into `docs/world-generation.md` §6.7 as the mechanism 062 should reach for first.

Explicitly *not* in scope: sea level, water and the land fraction (080); erosion and a
ruggedness field (062); terracing — `at()` is continuous on purpose (063); rivers, roads
and structure flattening (062, 080–083, 089–090); climate, where whether temperature and
humidity share elevation's weight fields is the new note's `U2` for 064 to resolve; any
voxel — still nothing is written to a `VoxelBuffer`.

Docs: `docs/world-generation.md` §6 (new, seven subsections); new
`docs/reference/terrain-base-height-field.md`; `terrain-value-noise.md` `U2` marked
resolved; `docs/README.md` and `traceability.md` §2 list the new note.

Tests: `tests/unit/test_elevation_field.gd` (new, 22 tests) pinning a golden
`signature()` (`0babd0a337dd7cab`). Full suite: `files=38 tests=449 assertions=11469
failed=0`. `check.ps1` OK (79 scripts).

`060` is **the first brick that generates anything**, and it is two files under
`world/generation/`, split the way the brick title is:

**`value_noise.gd` (`ValueNoise`, an instance configured per layer)** — the coherent-noise
primitive every Phase D field will stand on. `GenerationHash` (058) answers every
coordinate independently, which is right for a placement mask and unusable for a *field*:
terrain whose height is a hash per column is a forest of one-voxel spikes with no slope, no
valley and no scale at which a biome could exist. `ValueNoise` hashes the corners of a
coarse lattice and interpolates, then sums octaves at halving cell sizes. Built **on top
of** `GenerationHash`, not beside it, so the seed binding, the checked version, the space
tag and order-freedom all still hold underneath. Surface: `layer()`/`reject_reason()`,
`value()` `[-1, 1]`, `value01()` `[0, 1]`, `octave_value()`, `cell_size()`/`octaves()`/
`gain()`/`salt()`/`finest_cell_size()`, `max_slope_per_voxel()`/`max_slope01_per_voxel()`.

**`continentalness.gd` (`Continentalness`)** — its first user and the first generated
field: per column, `0` = middle of an ocean, `1` = middle of a landmass. Pinned
`CELL_SIZE_VOXELS = REGION_SIZE_VOXELS * 8` (8192 voxels = 4096 m), `OCTAVES = 4` (so the
finest layer is exactly one region across — 089's structure grid gets a value of its own,
not an interpolation of its neighbours'), `GAIN = 0.5`, new
`WorldHash.SALT_CONTINENTALNESS = 10` (appended, never renumbered). Constants, not
arguments: they are baked into every world made with them.

Five decisions worth keeping:

1. **The lattice lives in integer voxel space, divided with `GenerationGrid.floor_div()`.**
   No float ever carries a world coordinate, so nothing loses exactness at the ±524288
   corners of `WorldBounds`, and the interpolation weight `floor_mod(x, cell) / cell` is
   exact because the cell is a power of two. Truncating division would mirror the whole
   field about the origin — which is exactly what the original's own `valueNoise2D` does
   (see the reference read below). Third appearance in Phase D of the same class of defect,
   always in the half of the world a positive-quadrant test never visits.
2. **The fade is the quintic polynomial, not the original's `cos`, and that is a
   networking decision.** `cos` is a libm implementation detail; `+`, `-`, `*` on doubles
   are exactly specified by IEEE-754. Both server and client generate from the same seed
   (`world-generation-authority.md`), so a last-bit disagreement about a coastline is a
   disagreement about where the land is. The quintic is also `C²` where the cosine is only
   `C¹`.
3. **Octaves are separated by a lattice offset, not by a salt.** Salts are one per pass and
   must stay below `SPACE_SALT_STRIDE`, so `salt + octave` walks into the next pass's salt.
   Without any offset every octave samples lattice `(0, 0)` at the world origin and agrees
   there — a spike at the one coordinate everything else is measured from. Recorded as a
   rule in `docs/rng.md` §4.
4. **`max_slope_per_voxel()` is derived, not measured, and is asserted.** Along an axis an
   octave is `lerp(a, b, fade(t))` with `a, b ∈ [-1, 1]`, so its slope is at most
   `2 · 1.875 / cell`; the layer's bound is the amplitude-weighted sum over the amplitude
   sum. "Coherent" is the whole claim this brick makes, and a claim nothing checks quietly
   stops being true — so the test walks 1201 adjacent columns across the origin against the
   bound, **and runs the same walk over raw `GenerationHash` values to prove the check can
   fail**. Falls out of the algebra: at `gain = 0.5` with halving cells every octave
   contributes the *same* amount to the bound — detail octaves buy detail, not coherence.
5. **The field decides nothing.** No sea level (080), no height (061), no vegetation
   (067–073). Keeping the field and the thresholds apart is what lets 080 move a coastline
   without reshaping the continents underneath it.

One property the shared fixtures cannot check, asserted in `test_continentalness.gd`: the
field must **span** its range. A macro field whose values all sit near 0.5 is repeatable,
order-free, seed-sensitive, in range, varied — and has no oceans and no interiors. Measured
over 2304 columns across ~24 coarse cells per axis: lowest `0.083`, highest `0.970`, mean
`0.501`.

**Reference read** (`traceability.md` §1: 060 falls in the `060–067` rows —
`matrix-world.md` §1 `cube::Field` LOW and §2 terrain noise/height/climate fields MEDIUM,
no gating question): full read of `valueNoise2D` (`server/world/World.cpp:3495–3536`) plus
a grep-only pass over `World_baseHeightField`'s call sites, recorded as
**`docs/reference/terrain-value-noise.md`**. Findings: it is value noise with a **linear**
corner key `i + 57·j` (so `(i + 57, j - 1)` is the same corner — the field repeats along a
diagonal), Hugo-Elias-shaped 32-bit integer hashing, cosine interpolation through libm,
corner values in `(-1, 1]`, **no seed parameter at all** — per-world variation comes from
adding offsets to the *sample coordinates*, so every world is a translation of every other
— and a lattice taken by C truncation, which mirrors the field about the origin on each
axis. §9 of the note is the divergence table. Nothing from the original is kept except the
shape of the idea (lattice value noise) — every constant, the seeding, the interpolation
and the octave ladder are ours.

Explicitly *not* in scope: anything that reads the field (061 elevation, 062–063 shaping,
064–065 climate, 080 sea level); a redistribution curve or land-fraction target (that is a
decision, and it belongs to the brick that makes it); a 3D form of the layer (caves,
077–078); domain warping, ridged/billow variants, analytic derivatives; any voxel — nothing
is written to a `VoxelBuffer` yet.

Docs: `docs/world-generation.md` §5 (new, six subsections); new
`docs/reference/terrain-value-noise.md`; `docs/rng.md` §3 records that the free-fix window
is now closed and §4 gained the octave-offset rule; `docs/README.md` and
`traceability.md` §2 list the new note.

Tests: `tests/unit/test_value_noise.gd` (new, 17 tests), `tests/unit/
test_continentalness.gd` (new, 11 tests), both pinning a golden `signature()`. Full suite:
`files=37 tests=427 assertions=10953 failed=0`. `check.ps1` OK (77 scripts).

`059` built the shared floor every Phase D determinism test stands on, in one new file
outside the layer tree: **`tests/fixtures/generation_fixtures.gd`** (`GenerationFixtures`,
static-only). Bricks 060–090 each add a pass, and each owes the same four properties —
repeatable, order-free, seed-sensitive, in range. Left to each brick those get re-asserted
thirty ways against whichever coordinates the author thought of, and the coordinates an
author thinks of are the ones that work.

Three parts: **four named worlds** with *pinned* seed values (seed 0, a typed phrase, the
`"12345"` face-value branch, `-1`); **five coordinate sample lists** (voxel, column,
chunk, chunk column, region), each entry present for a stated reason and each list handed
out freshly built; and the **checks** — `determinism_reason()`, `repeatability_reason()`,
`order_independence_reason()`, `seed_sensitivity_reason()`, `range_reason()`,
`variation_reason()`, plus `signature()` for golden pinning and `self_check()`. All return
the project's empty-string-means-fine reason, so they read the same in a test, a debug
probe or a server self-test.

Four decisions worth keeping:

1. **Two checks take a factory, not a sampler.** `determinism_reason()` and
   `seed_sensitivity_reason()` build the pass themselves, because order dependence can
   only be seen against a *fresh* instance: a pass that numbers cells as it first meets
   them answers a repeated call consistently and so passes repeatability outright. The
   test file proves this by running exactly that broken pass past the weaker check and
   into the stronger one. Three visit orders (forward, reversed, odds-then-evens),
   three instances.
2. **Seed values are pinned, not computed.** That turns the fixture set into a contract
   on `WorldHash.seed_from_text()`: a changed string hash fails here rather than quietly
   agreeing with itself, which after 060 is a version bump. Same reason
   `test_generation_fixtures.gd` pins one golden `signature()` over the whole
   015 + 056 + 058 stack (`e33366942fe2f8f6`).
3. **`variation_reason()` earns its place.** A stub returning `0.0`, a field whose
   amplitude ended up zero, and a mask nothing ever passes are all repeatable, order-free,
   in range, and wrong.
4. **The digest reads a float's exact bits** (`encode_double`/`decode_s64`), never
   `str()` — two genuinely different terrains print identically to six digits. `-0.0` is
   normalised to `0.0`; type is folded in, so an `int` 1 and a `float` 1.0 digest apart.

**A second real defect fell out of the first fixture run**, in the same primitive 058
fixed and by the same mirror: `value01_column(-7, -9)` still equalled `(7, 9)`, and
`(9, -9)` equalled `(-9, 9)`. Multiplication *distributes over* negation
(`(-v) * C == -(v * C)`), so multiplying preserves an exact negation rather than
destroying it — and `s ^ (-a) == -(s ^ a)` holds for every odd `a` whenever the effective
seed `seed_value * 31 + salt` is **even**, so the second axis's own negation mask cancels
against it. That is half of all (seed, salt) pairs mirrored through the origin, for every
column with both coordinates odd: **15% of a 151 263-pair sweep**. 058's regression test
missed it because every assertion in it uses an odd effective seed, where the identity
does not hold. Fixed in `world_hash.gd` by adding an odd constant after each fold
(`_ROUND`), making the mirror value `-v + 2 * _ROUND` — no longer any negation mask away
from `v`. A rotation fixes the same class and measured **69% slower** in this interpreter
against **2%** for the addition, on what `generation_hash.gd` calls the hottest path;
candidates were compared over the same sweep (`+K`, rotate, per-axis `mix64` all reached
zero non-trivial collisions). Regression lives in `test_world_hash.gd` as
`test_no_mirror_world_at_any_seed_and_salt_parity` — 3 402 pairs, **both parities**, which
is the rule now.

One convention change: `tests/fixtures/` is exempt from the `test_<subject>.gd` file-name
rule (the runner only collects `test_*.gd`, so a fixture named `test_` would be a test
that asserts nothing), and in exchange a fixture file may declare no `test_*` method —
`test_conventions.gd` enforces both halves.

Explicitly *not* in scope: any pass to run the checks against (060); golden *terrain* (no
voxels are generated yet, and the digest is the cheaper form of the same guarantee); a
performance fixture (generation's `docs/performance-budget.md` row stays empty until
257–258); making the checks available to production code.

Reference: none needed — `traceability.md` has no row for 059, and §4 now lists it under
original design (test harness work, not generated behavior).

Docs: `docs/world-generation.md` §4 (new, seven subsections incl. §4.6 on the defect);
`docs/rng.md` §3 rewritten to record **both** algorithm changes and the both-parities
rule, §5 gained a "test through the shared fixtures" bullet; `docs/conventions.md` §6 and
`tests/README.md` carry the fixtures exemption; `traceability.md` §4 lists 059. No new
docs file, so `docs/README.md` needed no change.

Tests: `tests/unit/test_generation_fixtures.gd` (new, 20 tests — each check run against a
deliberately broken pass as well as a correct one, because a check that never fails is
indistinguishable from one that cannot), `test_world_hash.gd` (+1 sweep),
`test_conventions.gd` (+1). Full suite: `files=35 tests=399 assertions=10830 failed=0`.
`check.ps1` OK (73 scripts).

`058` gave generation its coordinate spaces and the only supported way to hash them, in
two files under `world/generation/`:

**`generation_grid.gd` (`GenerationGrid`, static-only)** — the five grids generation asks
questions at (voxel, column, chunk, chunk column, region) and the conversions between
them. `CHUNK_SIZE_VOXELS = 16` because that is Voxel Tools' *data* block size (fixed for
`VoxelTerrain`; a generator is handed one at a time, so any other grid would straddle a
block boundary on every fill) — deliberately **not** `DEFAULT_MESH_BLOCK_SIZE`, which is
a rendering choice ADR 0002 leaves free to become 32. `REGION_SIZE_VOXELS = 1024` (512 m)
was chosen so the region grid is exactly 1024 × 1024 across `WorldBounds`' horizontal
extent (050). Public `floor_div()`/`floor_mod()`, because `-1 / 16` is `0` in GDScript and
truncation would put voxel −1 and voxel 0 in the same chunk — asymmetric across half the
world, invisible until someone walks west. Grids are **half-open**, which surfaces one
documented seam: `WorldBounds.aabb()` includes its maximum face (`AABB.has_point()` is
inclusive), so the single voxel plane at `x == +524288` is inside the world and outside
the region grid; `is_region_in_world()` is the authority.

**`generation_hash.gd` (`GenerationHash`, an instance bound to one world)** — wraps
`WorldHash` (015) and adds the three things the primitive cannot know: the `WorldSeed`
binding (056's "call sites take a `WorldSeed`, never an integer" is unenforceable if each
call site reaches for `config.value`), a version check that runs **once** in `for_world()`
rather than per call (hashing is the hottest path in the project), and a **space tag**
per grid — chunk `(3, 0, 5)` and voxel `(3, 0, 5)` are different places carrying the same
numbers, and untagged, a per-chunk pass sharing a salt with a per-voxel pass would agree
cell for cell. The tag is `space * SPACE_SALT_STRIDE + salt`; `Space.VOXEL` is `0`, so
voxel-space hashing stays byte-identical to a bare `WorldHash` call.

Three decisions worth keeping:

1. **The generation version is not mixed into the hash.** A version *selects* an
   algorithm; it is not an *input* to one. Mixing it in would make every bump reshuffle
   every unrelated pass (a fix to the tree mask would move every mountain) and would make
   "version 2 is version 1 with different numbers" indistinguishable from a genuine
   algorithmic change — exactly the distinction §2.1's bump test asks a human to make.
2. **`for_world()` is where a world is refused.** It is the point a `WorldSeed` becomes
   numbers, so it is where "this build cannot reproduce that algorithm" has to stop:
   generating a retired world *approximately* produces terrain that looks right and
   stitches a second algorithm into ground a player already explored.
   `refuse_reason()` is the pure form, for a load screen or the 235–236 handshake.
3. **A salt must stay below the stride**, or two spaces share effective salts and the
   tagging silently stops working. `test_generation_hash.gd` asserts it over
   `WorldHash`'s whole constant map, so adding a salt cannot skip the check.

**A real defect fell out of the first test run**: `WorldHash.hash2(-7, -9)` was *equal* to
`hash2(7, 9)`. Negating an integer flips every bit above its lowest set bit, so `-n` is
`n` XOR a suffix mask determined only by its trailing-zero count; two axis products whose
trailing-zero counts match contribute the **same** mask, and XOR-combining them cancelled
both. The world had a point symmetry through the origin across every coordinate pair with
matching trailing-zero counts (~a quarter of all columns), and for any *subset* of axes
too — `hash3(-7, 5, -9) == hash3(7, 5, 9)`. Fixed in `world_hash.gd` by multiplying by an
odd constant between axis folds, so each axis reaches the high bits before the next
arrives and no later term can cancel an earlier one. Free to fix now; after brick 060 the
same change is a generation version bump (`docs/rng.md` §3 now says so). Regression
assertions live in `test_world_hash.gd` (015's own file), not the new ones.

**Reference read** (`traceability.md` §1: 058 falls in the `056–067` row,
`matrix-world.md` §1, LOW, no gating question): targeted read of
`World_generateRegionSite` (`server/world/World.cpp:4993–5030`) plus the identical line in
the client (`cube/control/GameController.cpp:87676`), recorded as
**`docs/reference/region-coordinate-hashing.md`**. Findings: region coordinates are
**unsigned, `0..1023`** (a corner-counted 1024 × 1024 grid); a region's content is seeded
by a **linear** combination fed to the C library's **process-global** `srand()`
(`srand(regX + 0x108a + regZ * 0x400 + seed * 3)`), whose first decision is `rand() & 1`
— the low bit of an LCG; the site cache is indexed `regX * 0x400 + regZ` while the seed
pairs the axes the other way. §9 of the note is the divergence table (hash not global
seed, avalanche not addition, top bits not low bit, signed grid centred on the origin,
one axis order). The 1024 × 1024 *shape* is the one piece kept, which is where
`REGION_SIZE_VOXELS` comes from.

Explicitly *not* in scope: any field, noise layer or placement rule (060 onward); new
salts (each pass adds its own as it lands); using `is_region_in_world()` for anything
(089–090); a region *record* — this brick defines the coordinate and its hash, nothing
that lives at it.

Docs: `docs/world-generation.md` §3 (new, six subsections: the spaces, the binding, why
the version stays out of the hash, what the original did, the primitive defect, out of
scope); new `docs/reference/region-coordinate-hashing.md`; `docs/rng.md` §2/§3/§4 gained
the space-tag rule, the `GenerationHash`-not-`WorldHash` routing rule, and the record of
the one algorithm change; `docs/README.md` and `traceability.md` §2 list the new note.

Tests: `tests/unit/test_generation_grid.gd` (new, 18 tests), `tests/unit/
test_generation_hash.gd` (new, 20 tests), `test_world_hash.gd` (+1 regression test). Full
suite: `files=34 tests=377 assertions=10698 failed=0`. `check.ps1` OK (71 scripts).

`057` gave the generation version a lifecycle: `world/generation/generation_version.gd`
(`GenerationVersion`, static-only, second file under `world/generation/`). The number
itself stays `SaveVersion.GENERATION_VERSION` — `core/` cannot depend on `world/`, so
`core/serialization/save_version.gd` (017) keeps the constants and the header verdicts,
`world_seed.gd` (056) keeps "which version applies to *this* world", and this file
answers the three things neither did: **when the number must be bumped**, **which
algorithms this build can still reproduce**, and **what happens to a world whose
algorithm is gone**.

Surface: `CURRENT` (= `SaveVersion.GENERATION_VERSION`), `SUPPORTED` (`PackedInt32Array`,
`[1]` today), `SUMMARIES` (one describable line per version, kept for retired versions
too), `enum Status {CURRENT_VERSION, LEGACY, RETIRED, FUTURE, INVALID}`, plus
`supported()`/`is_supported()`/`oldest_supported()`, `status()`/`status_name()`/
`summary()`/`explain()`, `classify_header()`/`can_load_header()`/`explain_header()`, and
`self_check()`.

Four decisions worth keeping:

1. **Two pure forms, deliberately.** `status_of(version, current, supported)` and
   `self_check_of(current, supported, min_supported, summaries)` take their inputs
   instead of reading the constants, and the zero-argument forms delegate. That is what
   makes version histories this build does not have yet (a retirement, a hole, a newer
   peer) testable today — and `status_of()` is the shape bricks 235–236 need anyway,
   since a handshake judges the *other* side's declared set, not its own.
2. **`classify_header()` is the only supported way to ask about a world header.**
   `SaveVersion.classify()` called without an explicit list falls back to the
   `MIN_SUPPORTED_GENERATION_VERSION..GENERATION_VERSION` **range**, which is correct
   only while `SUPPORTED` has no holes. Holes are legal (retiring one short-lived broken
   algorithm while keeping its neighbours is a real decision), so the wrapper always
   passes the list. This is the concrete reason the constant is not just
   `range(min, current + 1)` spelled out.
3. **The bump checklist is enforced, not remembered.** `self_check()` requires: newest
   supported == `CURRENT` (a build must reproduce what it writes, or every world it
   creates is unloadable by the build that made it); `SUPPORTED[0]` ==
   `SaveVersion.MIN_SUPPORTED_GENERATION_VERSION` (the two files can never disagree about
   the oldest world that still opens); sorted/unique/positive entries; every supported
   version described; no summary outside `1..CURRENT`. `test_generation_version.gd`
   asserts it, so a half-finished bump fails the suite rather than the first save nobody
   can open. Steps 1 (raise the constant) and 5 (write down what changed) are the parts a
   human still has to mean.
4. **A refusal names the world.** `explain()`/`explain_header()` quote the version's own
   `SUMMARIES` line — `docs/persistence.md` §2's "a player told only 'cannot load'
   deletes the save", applied to the generation axis.

`world_seed.gd`'s constructor default moved from `SaveVersion.GENERATION_VERSION` to
`GenerationVersion.CURRENT` (identical value) so "a new world is created under this
build's current algorithm" reads from the lifecycle owner; its doc comment lost the "brick
057 will…" placeholder. No other production file changed — nothing yet calls
`classify_header()`, because nothing yet loads a world save (that path lands with
102–103).

Explicitly *not* in scope: implementing a second algorithm or any migration/side-by-side
execution of two (nothing needs it until a second version exists); enforcing version
agreement across a session (235–236 run the checks this brick and 056 provide); where the
header is stored (102–103).

Docs: `docs/world-generation.md` §2 (new, six subsections: bump triggers, the supported
set, the status table, retiring, the enforced checklist, out-of-scope) and §1.7's pointer
updated; `docs/persistence.md` §3 and `docs/rng.md` §3 gained pointer paragraphs naming
`GenerationVersion` as the owner and warning off the bare `SaveVersion.classify()` call.
No new docs file, so `docs/README.md` needed no change.
`docs/reference/traceability.md` needed none either: its Phase D row `056–067` already
covers 057 (`matrix-world.md` §1, LOW), and no open question gates it — Q2, the one that
gated 056, is resolved.

Tests: `tests/unit/test_generation_version.gd` (new, 14 tests). Full suite: `files=32
tests=338 assertions=10440 failed=0`. `check.ps1` OK (67 scripts).

`056` is the first Phase D brick, and the first one this project started with an open
reference question actually gating it (`traceability.md` §1's rule). Two pieces, in
order:

**(a) Resolved `matrix-world.md` Q2** — "the client re-runs world generation
(`WorldInfo`); was that singleplayer convenience, or a trust model?" — via a new
reference note, **`docs/reference/world-generation-authority.md`** (the file the Q2 row
itself promised, "to be created before brick 056"). Targeted read only: the sites in
`server/world/World.cpp`, `cube/world/WorldInfo.cpp` and `cube/control/GameController.cpp`
that read the world-seed slot, plus the two `GAP_ANALYSIS.md` rows for the send loop and
receive dispatch. **Answer: neither reading in the question.** Both binaries hold one
integer world seed in the same world-struct slot and mix it with region coordinates
using the *same* constants — the client's copy of the region-site/feature generators is
the server's — so terrain is never transmitted, it is **recomputed on both sides**; the
attributed server→client traffic is entity/zone state only. Client-side generation was a
**bandwidth design**, and the original simply never asked whether the client's copy could
be wrong.

The rule adopted in response, which keeps `CLAUDE.md` §1 intact without pretending the
client is inert: **the client may generate, the client never decides.** Every
gameplay-visible conclusion drawn from generated terrain (movement collision, edit
validity, spawn placement, structure contents) is resolved server-side against the
server's own generation. The consequence that lands *in this brick*: `(seed, generation
version)` agreement stops being an internal detail and becomes a checked precondition,
because a client generating from a different seed produces a world that looks right and
is wrong. Enforcement at handshake time is 235–236; 056 provides the check.

**(b) Implemented the seed configuration** — `world/generation/world_seed.gd`
(`WorldSeed`, the first file under `world/generation/`). Carries `value` (the integer
`WorldHash` hashes), `text` (what a player typed, trimmed, `""` if nothing was) and
`generation_version` (pinned from `SaveVersion.GENERATION_VERSION` at creation). Four
constructors — `from_text()`, `from_value()`, `arbitrary()`, `from_header()` — plus
`validate()`, `display_text()`, `mismatch_reason()`/`matches()`, `rng_for(key)`,
`to_header(extra)`, `to_context()`.

Four decisions worth keeping: (1) generation call sites take a `WorldSeed`, never an
`int`, because `docs/rng.md` §6's "a seed alone does not identify a world" is
unenforceable if the pair can be split; (2) `text` is provenance, **not** identity — two
players who reached the same seed by different routes are in the same world, so
`mismatch_reason()` compares only `value` + `generation_version`; (3) `validate()`
enforces a **round-trip rule** — whenever `text` is set, re-hashing it must give `value`,
because a drifted pair means the seed a player is shown and quotes in a bug report would
create a *different* world than the one they are looking at; (4) `to_header()` writes the
*world's* generation version over the build's constant (`SaveVersion.make_header()` still
owns the container/data versions), and `from_header()` reads it back — that is
`docs/persistence.md` §3's "a world keeps generating with the version it was created
with", made mechanical rather than remembered.

`arbitrary()` is the one deliberately unreproducible call in the generation stack, and
harmlessly so: it picks *which* world to create, once, and is never consulted again. It
still avoids engine-global randomness (`docs/rng.md` §1 forbids it under `world/`, and
`test_rng_discipline.gd` enforces that) — wall clock, uptime counter and process id
through `DeterministicRng.hash_string()`. `from_text("")` is seed **0**, a real world;
translating a blank UI field into "pick one for me" is the UI's job, not this type's.

Explicitly *not* in scope: the generation-version **lifecycle** (what a bump means, which
versions a build still implements) is 057 — this brick only records which version
applies; save-directory layout is 102–103; actual generation starts at 060.

Docs: new `docs/world-generation.md` (§1, the seed contract, laid out to grow one section
per Phase D brick) and new `docs/reference/world-generation-authority.md`;
`matrix-world.md` Q2 + `traceability.md` §2/§3 rows carry `(RESOLVED — brick 056)` per
the brick-029 lifecycle (rows kept, not deleted); `docs/rng.md` §6 and
`docs/persistence.md`'s header gained pointer sentences; `docs/README.md` gained both new
files.

Tests: `tests/unit/test_world_seed.gd` (new, 20 tests). Full suite: `files=31 tests=324
assertions=10393 failed=0`. `check.ps1` OK (65 scripts).

`055` is the last Phase C brick — docs only, no production code changed. It lifts the
§17/§18 benchmark numbers and ADR 0002's estimated per-edit re-mesh cost out of
`docs/voxel-tools.md` §17-19 + `nextsteps.md` and into a standalone durable document,
**`docs/performance-budget.md`**. That file: (1) defines the synthetic meshing workload
(default block set, flat-stone placeholder generator, one `VoxelViewer` at
`view_distance = 128`, cold start to streaming-settle); (2) records the size-16 baseline
(~377 ms / 52 frames to settle, `block_count = 324`, `voxel_used ~= 2.65 MB`, zero
dropped loads/meshes, task queues drained) with the size-32 comparison beside it;
(3) sets provisional regression thresholds (settle ≤ 450 ms / ≤ 64 frames; any dropped
load/mesh is a regression; queues must drain; data-block footprint within a few % of
324 / 2.65 MB); (4) flags the still-unmeasured per-edit re-mesh cost (16³ = 4 096-cell
job per affected chunk at the default size) as a gap — the edit-throughput benchmark
ADR 0002 "Revisit if" wants does not exist yet; (5) names re-measure triggers (Phase D
real generation, `DEFAULT_VIEW_DISTANCE` change, any toolchain change) that hand off to
Phase L bricks 257-258. The doc is laid out in `CLAUDE.md` §8 subsystem order with
placeholder rows for the not-yet-measured subsystems (generation, streaming, entities,
AI, network, rendering, UI) so it grows in place rather than being reorganised later.

Changes: new `docs/performance-budget.md`; `docs/README.md` gained a "Performance"
section pointing to it; `docs/voxel-tools.md` §20 (new) summarising the hand-off. No
`.tscn` added, no player/camera — that Phase F scene-wiring question (raised in 039's
nextsteps entry, carried by 042-054) carries forward into Phase D unchanged.

`docs/reference/traceability.md` §4 already confirmed no reference matrix cites 031-055,
so no reference read was needed.

Tests: none added — docs-only brick. Regression check only: full suite
`files=30 tests=304 assertions=10337 failed=0`; `check.ps1` OK (63 scripts).

`054` chose the project default mesh block size from 052's (size 16) and 053's (size 32)
measurements. **Decision: `VoxelTerrainBuilder.DEFAULT_MESH_BLOCK_SIZE` stays `16`** — now a
deliberate, measured choice, not the inherited engine default. Size 32 benchmarked ~7-9%
(~25-35 ms) faster to cold-settle, but that saving is one-time and on flat, un-edited
terrain; the benchmark never touched the per-edit re-mesh path, where size 32 is a 32³ =
32 768-cell mesh job against size 16's 16³ = 4 096 — 8× the meshing work on every block
edit, on the player-visible latency path, in an edit-heavy game. Data-block memory is
identical either way (`mesh_block_size` doesn't affect the fixed 16³ data-block storage),
so the trade-off is purely cold-start latency vs. per-edit latency. `build()` keeps its
optional `mesh_block_size` parameter and still accepts an explicit `32` for a future
static-terrain / heavy-view-distance context measured to benefit.

No production code behavior changed — the constant already read `16`. Changes: new
**ADR 0002** (`docs/adr/0002-mesh-block-size.md`, indexed in `docs/adr/README.md`); the
`DEFAULT_MESH_BLOCK_SIZE` / `mesh_block_size`-param doc comments in
`voxel_terrain_builder.gd` rewritten from "inherited engine default" to "deliberate
measured choice, see ADR 0002"; `docs/voxel-tools.md` §19 (new) + §6 property-table row.
Test: `test_voxel_terrain_builder.gd` gained one assertion
(`DEFAULT_MESH_BLOCK_SIZE == 16` explicitly, citing ADR 0002, so a silent flip to `32`
fails). Brick 055 writes these numbers into the formal voxel performance budget.

`docs/reference/traceability.md` §4 already confirmed no reference matrix cites 031-055,
so no reference read was needed.

Tests: `tests/unit/test_voxel_terrain_builder.gd` (+1 assertion). Full suite:
`files=30 tests=304 assertions=10337 failed=0`. `check.ps1` OK (63 scripts).

`053` is a pure measurement brick — no production code changed. It re-runs the
brick-052 harness (`tools/benchmarks/benchmark_mesh_block_size.gd` +
`mesh_block_size_benchmark_runner.gd`) unchanged except `--block-size=32`; the
`mesh_block_size` parameter and its `32`-wired / `8`/`64`-rejected tests already landed
with 052, so no test file changed either. **Measured** (`mesh_block_size = 32`,
`view_distance = 128` matching `DEFAULT_VIEW_DISTANCE`, default block set, placeholder
flat-stone generator, three repeated runs on the dev machine): settles in 50-51 polled
frames (30 are the fixed stability window, so real work completes by ~frame 20-21) and
341.4-352.6 ms wall-clock; `memory_pools.block_count = 324`, `voxel_used ~= 2.65 MB`;
`dropped_block_loads = dropped_block_meshs = 0`; all `tasks` queues `0` at settle;
`RESULT=OK`, exit `0` on all three runs.

Side-by-side with 052 (size 16): settle frames 52 -> 50-51; wall-clock 375.7-377.9 ms ->
341.4-352.6 ms; `block_count` 324 -> 324 (identical); `voxel_used` ~2.65 MB -> ~2.65 MB
(byte-identical). The data-block counters match exactly because they track 16³ *data*
blocks, which `mesh_block_size` does not affect — it only changes mesh-chunk granularity.
The one real difference this harness sees is wall-clock: size 32 settles ~25-35 ms
(~7-9%) faster and one to two frames sooner on this small flat-terrain workload,
consistent with fewer/larger mesh chunks meaning less per-chunk bookkeeping. This is a
single synthetic benchmark, not a decision — brick 054 weighs both bricks' numbers (plus
the memory/latency trade-off of larger mesh chunks under real generation and frequent
edits) to choose the project default; 055 writes the chosen budget into a formal
document. Full reasoning + comparison table in `docs/voxel-tools.md` §18 (new section).

`docs/reference/traceability.md` §4 already confirmed no reference matrix cites 031-055,
so no reference read was needed.

Tests: none added (052 covers the `mesh_block_size` surface). Regression check only: full
suite `files=30 tests=304 assertions=10336 failed=0`.

`052` gave `VoxelTerrainBuilder.build()` a third optional parameter,
`mesh_block_size: int = DEFAULT_MESH_BLOCK_SIZE` (16, `VoxelTerrain`'s own engine
default) — the last `VoxelTerrain` property Phase C had left implicit since 039.
Confirmed against upstream `VoxelTerrain.xml` (`godot_voxel` reference repo, tag `v1.7`):
only `16`/`32` are valid; an out-of-range value is rejected via `Log.check` + null return,
same pattern as an unlocked registry.

Added a new headless benchmark harness, split into two files on purpose:
`tools/benchmarks/benchmark_mesh_block_size.gd` (the `--script` entry, no static
references to any `Log`-touching project class) and
`mesh_block_size_benchmark_runner.gd` (the actual measurement logic, `load()`ed at
runtime). The split exists because of a genuine, empirically-confirmed engine behavior
this brick surfaced: **a file passed to `--script` is compiled before project autoloads
are registered as global identifiers**, so a script that statically references a
`Log`-touching class (`VoxelTerrainBuilder`, `BlockSet`, `VoxelTerrainMetrics` all call
`Log` internally) at the top level fails to compile with `Identifier not found: Log`,
cascading into every one of those classes. `tests/run_tests.gd` never hits this because it
only statically references `TestCase` (no `Log` dependency) and reaches every real,
`Log`-dependent test file through a runtime `load()` call instead. Any future
`tools/**/*.gd` script that wants to call `Log`-touching project code needs the same
entry/runner split — recorded in both files' own header comments and
`docs/voxel-tools.md` §17, not just here.

A second finding changed how the harness detects "done": `VoxelTerrain.get_statistics()`'s
`updated_blocks` reads as "blocks updated on this specific tick", not a running total — an
early version polled it for a stable plateau and reported "settled" while it sat at a
constant `0` for an entire run that still grew `memory_pools.block_count` from `0` to
hundreds and printed real final statistics; the actual update burst happened between two
polls and was never sampled. Settle detection now watches
`VoxelTerrainMetrics.engine_snapshot()`'s `memory_pools.block_count` (monotonically
non-decreasing while streaming is in flight) plus every `tasks` queue reading `0`, for 30
consecutive frames — a direct "no more in-flight background work" signal.

**Measured** (`mesh_block_size = 16`, `view_distance = 128` matching
`VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE`, default block set, placeholder flat-stone
generator, three repeated runs on the dev machine): settles in 52 polled frames (30 of
which are the fixed stability window, so real work completes by roughly frame 22) and
375.7-377.9 ms wall-clock; `memory_pools.block_count = 324`, `voxel_used ~= 2.65 MB`;
`dropped_block_loads = dropped_block_meshs = 0`. Brick 053 repeats this unchanged except
`--block-size=32`; 054 compares both bricks' numbers to choose a default; 055 writes both
into a formal performance-budget document — none of that comparison/choice/documentation
work is done by 052 itself.

`docs/reference/traceability.md` §4 already confirmed no reference matrix cites 031-055,
so no reference read was needed. Full reasoning in `docs/voxel-tools.md` §17 (new
section).

Tests: `tests/unit/test_voxel_terrain_builder.gd` (+2 tests, now also covers 052) — an
invalid `mesh_block_size` (8, 64) is rejected; an explicit `32` is wired through
unchanged; the existing `test_builds_a_configured_voxel_terrain` gained one assertion
(default is 16). Full suite: `files=30 tests=304 assertions=10336 failed=0`.

`051` added `world/terrain/voxel_terrain_metrics.gd` (`VoxelTerrainMetrics`) — named,
typed access to Voxel Tools' own debug-statistics dictionaries, so bricks 052-055 (mesh
block size 16/32 benchmarks, choosing a size, documenting the performance budget) read
them through shared constants, not scattered string literals (`CLAUDE.md` §1's "one
shared utility" rule). Three static entry points: `terrain_snapshot(terrain) ->
Dictionary` (wraps `VoxelTerrain.get_statistics()`, `{}` + logged reason for a null
terrain), `engine_snapshot() -> Dictionary` (wraps the `VoxelEngine` singleton's
`get_stats()`), `log_terrain_snapshot(terrain, channel = Log.CH_VOXEL)` (one structured
`Log.debug` line per sample — the actual profiling hook a benchmark calls).

Found and resolved a doc/code discrepancy along the way: `doc/classes/VoxelTerrain.xml`
(`godot_voxel` reference repo, tag `v1.7`) documents 9 keys for `get_statistics()`, but
the actual C++ source (`terrain/fixed_lod/voxel_terrain.cpp`'s `_b_get_statistics()`)
only ever sets 7 — `time_process_update_responses` and `remaining_main_thread_blocks` are
documented but never written. Confirmed both by reading the source and empirically (a
real, meshed terrain's snapshot in this build never has either key). `KEY_*` constants
list only the 7 real keys; the test asserts the dictionary size is exactly 7 to catch a
future engine change. `VoxelEngine.get_stats()` has no such mismatch (checked against its
own binding source too). Full reasoning in `docs/voxel-tools.md` §16 (new section).

Not reverse-engineered: `docs/reference/traceability.md` §4 already confirmed no
reference matrix cites 031-055.

Tests: `tests/unit/test_voxel_terrain_metrics.gd` (new, 5 tests). Full suite:
`files=30 tests=302 assertions=10328 failed=0`.

`050` added `world/terrain/world_bounds.gd` (`WorldBounds`, static `aabb() -> AABB` and
`contains(voxel_position: Vector3i) -> bool`) — the first real value for `VoxelTerrain.
bounds`, left at the engine's effectively-unbounded default since 039. A clean-room policy
decision, not reverse-engineered (`traceability.md` §4 confirms no reference matrix cites
031–055, and the reference's own `Zone`/`WorldMap` classes carry no recovered world-size
constant): `+-524288` voxels (`+-262.144 km`) horizontally (X/Z), `+-2048` voxels
(`+-1.024 km`) vertically (Y) — round powers of two (`2^19`, `2^11`), same style
`DEFAULT_VIEW_DISTANCE`/`mesh_block_size` already use. `voxel_terrain_builder.gd` (039)
now sets `terrain.bounds = WorldBounds.aabb()` unconditionally in `build()`.

Confirmed against upstream `VoxelTerrain.xml` (`godot_voxel` reference repo, tag `v1.7`,
fetched this brick): `bounds` only clips what an infinite generator fills in ("blocks will
only generate within this region... everything outside will be left empty") — it is not
documented as an edit-authority gate. The real edit-authority enforcement remains
`block_edit_validator.gd`'s (045) `OUT_OF_BOUNDS` verdict, which already reads this same
live `terrain.bounds` property independently — giving `bounds` a real value fixes both the
generator's clip and the edit-authority boundary at once, with zero code change to 045.
Full reasoning (including why `VoxelTerrainMultiplayerSynchronizer` stays deferred to
Phase K rather than adopted here) in `docs/voxel-tools.md` §15 (new section).

Tests: `tests/unit/test_world_bounds.gd` (new, 5 tests) — symmetric AABB, vertical extent
smaller than horizontal, `contains()` accepts the origin and exact face points
(`AABB.has_point()` is inclusive at both min and max), rejects one voxel past each face,
two `aabb()` calls agree. `tests/unit/test_voxel_terrain_builder.gd` (+1 assertion):
`terrain.bounds == WorldBounds.aabb()`. Full suite: `files=29 tests=297 assertions=10306
failed=0`.

`049` added `tests/integration/test_voxel_load_save.gd` (1 test) — the first file under
`tests/integration/`, closing the loop 048 opened by actually proving an edit survives a
real save/reload round trip rather than only that `VoxelStreamBuilder`/
`VoxelTerrainBuilder`'s `stream` parameter are wired correctly in isolation. Flow: build a
terrain against a real on-disk `VoxelStreamSQLite`, apply one `REMOVE` edit via
`BlockEditApplicator.apply()` (046), force-save via the newly-used
`VoxelTerrain.save_modified_blocks() -> VoxelSaveCompletionTracker` and poll
`is_complete()` (saving is asynchronous per the engine's own doc), fully free the terrain
and its stream (not via `track_node()`, which only frees after the test method returns —
too late for a second stream to safely reopen the same database path within the same
test), then rebuild a fresh terrain against the same database path. Two assertions:
the edited voxel is still air (the delta survived), and an untouched ground voxel
elsewhere still comes from the placeholder generator, not a stale/duplicated stream entry
— the concrete proof that `save_generator_output = false` (048) actually behaves as
documented, not just that the property reads back correctly.

No new engine API beyond what 043/046 already established, except `save_modified_blocks()`
and `VoxelSaveCompletionTracker` (`is_complete()`) — both confirmed against
`doc/classes/VoxelTerrain.xml`/`VoxelSaveCompletionTracker.xml` fetched from the
`godot_voxel` reference repo (CLAUDE.md §15 source, tag `v1.7`) this brick, alongside a
re-check of `VoxelStreamSQLite.xml` confirming no documented `close()`/flush call exists —
its connection lifetime is tied to the `RefCounted` resource's own lifetime, which is why
the test frees the first terrain explicitly rather than relying on test-runner teardown.
Full reasoning in `docs/voxel-tools.md` §14 (new section); `docs/persistence.md`'s header
gained one pointer sentence, same "pointer, not a new contract" pattern prior bricks used.

Scope is deliberately one edit (`REMOVE`), not a PLACE/REMOVE/multi-edit/concurrent-terrain
matrix — the backlog's own wording is "basic... integration test", and this closes exactly
the one open question `nextsteps.md`'s prior "Next 10 actions" item 1 named. No `.tscn`,
no player/camera decision — same deferral 039–048 all carry forward (still open below).

Tests: `tests/integration/test_voxel_load_save.gd` (1 test, +1 total). Full suite:
`files=28 tests=292 assertions=10289 failed=0`.

`048` added `world/persistence/voxel_stream_builder.gd` (`VoxelStreamBuilder`, static
`build(database_path: String) -> VoxelStreamSQLite`) — the first code that constructs a
`VoxelStream`, closing the "`stream` left null" note 039–047 all carried. Scope is
deliberately just the stream object itself, not where its database lives on disk —
`docs/persistence.md`'s own header already reserved that storage-layout question for
bricks 102–103, so this brick doesn't invent a save-directory convention.
`voxel_terrain_builder.gd`'s `build()` (039) gained a matching optional `stream:
VoxelStream = null` parameter; every existing call site (all in tests — no scene wires a
terrain yet) keeps building a save-less terrain unchanged.

Three deliberate property decisions, each confirmed against `doc/classes/
VoxelStreamSQLite.xml`/`VoxelStream.xml` fetched from the `godot_voxel` reference repo
(CLAUDE.md §15 source — note the GitHub tag is `v1.7`, not `v1.7.0`; unrelated to
`docs/environment.md`'s own verified version string): `save_generator_output = false`
(matches the engine default, named explicitly per 041/042's "explicit is a decision"
precedent) — `docs/persistence.md` §5 requires deltas only, and `true` would instead
save every generated block, duplicating terrain the generator can already reproduce;
`set_key_cache_enabled(true)`, called immediately at construction per the property's own
"must be called before load" doc note — key caching speeds up exactly the sparse
edited-block save shape `save_generator_output = false` produces;
`preferred_coordinate_format = COORDINATE_FORMAT_STRING_CSD` (value 2, the engine
default, named explicitly) — the one format with no fixed coordinate-range cap, correct
until world bounds are decided (brick 050), and only affects a new database so it can be
revisited later without a migration.

`build()` rejects only an empty `database_path` (`Log.check`, `Log.CH_PERSIST` — the
channel `autoload/log.gd` already reserves for persistence, distinct from
`Log.CH_VOXEL`); every other failure mode (bad parent directory, etc.) is Voxel Tools'
own responsibility and isn't re-validated here. Full reasoning in `docs/voxel-tools.md`
§13 (new section); `docs/persistence.md`'s header gained one pointer sentence, same
"pointer, not a new contract" pattern 047 used for `block_edit_delta.gd`.

Tests: `tests/unit/test_voxel_stream_builder.gd` (new, 3 tests) — empty-path rejection,
a built stream's three properties match the decisions above, two independent `build()`
calls produce independent stream objects. `tests/unit/test_voxel_terrain_builder.gd`
(+1 test, now also covers 048): a passed-in stream is wired onto `terrain.stream`
unchanged; its existing null-by-default assertion's comment was updated ("no save format
yet" was no longer accurate — the format now exists, the default is just still `null`).
Full suite: `files=27 tests=291 assertions=10284 failed=0`.

`047` added `world/terrain/block_edit_delta.gd` (`BlockEditDelta`) — the per-voxel delta
unit `docs/persistence.md` §5 names ("world modifications... stored as deltas") but had
not yet given a concrete shape, and the unit an undo replays. Carries `position`,
`previous_block_id`/`new_block_id` (`""` = air, the same convention 044/046 already use),
and `tick`. Two behaviors beyond plain data: `is_noop()` (both sides name the same
content), and `inverse_command(p_tick) -> EditBlockCommand` — restoring air means
`REMOVE`, restoring a named block means `PLACE`, so an undo replays through the exact
same `BlockEditApplicator.apply()` (046) that performed the original edit, no second
voxel-writing code path. `face_normal` on an inverse command is `Vector3.ZERO` — nothing
was struck, and no 043–045 check reads it today. `inverse_command()`'s own `p_tick` is
always the undo's tick, never the delta's own — an undo is issued now, not backdated.

`world/terrain/block_edit_applicator.gd` (046) gained one new static method,
`apply_capturing_delta(command, terrain, registry) -> BlockEditDelta`: reads the target
voxel's pre-edit content (the one thing `apply()` itself cannot report back, since
`set_voxel()` overwrites it) via the same `id_from_network_index(raw - 1)` pattern
045/043 already use, then delegates the actual write to `apply()` — so the two entry
points can never disagree about what a `PLACE`/`REMOVE` does. Returns null on the same
rejections `apply()` already logs (unlocked registry, no voxel tool, unregistered
`block_id`); adds no `Log.check` calls of its own, since every failure path was already
logged one layer down. `apply()` itself is unchanged — every 046 test still passes
unmodified, and 047 only adds a second entry point beside it.

Scope note: this brick builds the *representation* and its one-step inverse, not a
multi-step undo stack/history service — no backlog brick asks for one, and CLAUDE.md §6
("avoid silently expanding scope") argues against inventing one speculatively. A future
undo-stack brick, if ever added, would hold a list of `BlockEditDelta` and pop+apply
inverses; nothing here needs to change to support that.

`docs/reference/traceability.md` §4 already confirmed no reference matrix cites
031–055, so no reference read was needed, same as 031–046. `docs/persistence.md`'s
header gained one pointer sentence to `block_edit_delta.gd` as §5's concrete delta unit
— not a new contract, so no new section.

Tests: `tests/unit/test_block_edit_delta.gd` (new, 5 tests) — `is_noop()` true/false,
`inverse_command()` shape for both directions (kind, position, block_id, tick), and both
inverse commands passing their own `validate()`. `tests/unit/test_block_edit_applicator.gd`
(+7 tests, now also covers 047): `apply_capturing_delta()` reports air-before-a-place and
the removed block on a remove, returns null on the same unlocked-registry and
unregistered-block rejections `apply()` itself returns false for (voxel left untouched),
and two full round-trip tests — capture a delta, apply its `inverse_command()`, confirm
the voxel is back to exactly its pre-edit raw value. Full suite: `files=26 tests=287
assertions=10265 failed=0`.

`046` added `world/terrain/block_edit_applicator.gd` (`BlockEditApplicator`, static
`apply(command: EditBlockCommand, terrain: VoxelTerrain, registry: BlockRegistry) ->
bool`) — the last stage of the edit pipeline, applying an already-validated command
(044 structural + 045 gameplay, both assumed `ACCEPT`) to real voxel data via
`VoxelTool.set_voxel()`. Writes `registry.network_index(block_id) + 1` for `PLACE`, `0`
for `REMOVE` — the exact inverse of the `- 1` offset 043/045 apply when reading a voxel
back into a block id. Performs no gameplay re-check (occupied/air/destructible) — that
would duplicate 045 for no benefit — but keeps the same defensive `Log.check` shape
043/045 use: registry locked, terrain produces a `VoxelTool`, and (`PLACE` only)
`block_id` is actually registered. That last check matters because
`DefinitionRegistry.network_index()` returns `-1` for an unknown id, which the `+1`
offset would otherwise silently turn into `0` (air) — a caller that skipped 045 would
get silent data corruption instead of a clear rejection. All three are programmer/data
errors, not normal gameplay outcomes, so all three are logged; no rejection-counting
was added, same reasoning as 045 (stateless, no per-peer state to key on here).

`set_voxel()` needed no doc-verification caveat the way 043's `raycast()` did (§10) — it
is a direct single-voxel write, not a shape/SDF paint operation, so there is no
`do_point`/commit step to account for. `docs/voxel-tools.md` §12 (new section) records
the full reasoning; `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed, same as 031–045.

Tests: `tests/unit/test_block_edit_applicator.gd` (4 tests, +4 total) — same
built-vs-meshed terrain split 043/045 use: `INVALID_REGISTRY` against a built-but-unmeshed
terrain, and three voxel-content checks against a fully meshed terrain (`PLACE` writes
`network_index + 1`, `REMOVE` writes `0`, an unregistered `block_id` is rejected and
leaves the target voxel untouched). No `INVALID_TERRAIN` test — 043/045's own test files
never construct that case either, same precedent.

`045` added `world/terrain/block_edit_validator.gd` (`BlockEditValidator`, static
`validate(command: EditBlockCommand, terrain: VoxelTerrain, registry: BlockRegistry) ->
Verdict`) — layer 2 (gameplay) validation for `EditBlockCommand` (044) per
`docs/server-authority.md` §3, the counterpart to layer 1 (`CommandGate`, 019). Assumes
`command.validate()` (044, structural only) already passed, the same way `CommandGate`
assumes a well-formed envelope; this layer only checks what that pass cannot: registry
membership and actual voxel content. Returns a `Verdict` enum (`ACCEPT`,
`INVALID_REGISTRY`, `INVALID_TERRAIN`, `OUT_OF_BOUNDS`, `UNKNOWN_BLOCK`,
`UNRESOLVABLE_VOXEL`, `TARGET_OCCUPIED`, `TARGET_IS_AIR`, `NOT_DESTRUCTIBLE`), mirroring
`CommandGate.Verdict`'s shape rather than the string-reason convention `StableId`/
`BlockDefinition`/`EditBlockCommand.validate()` use — this is a command-authority
decision (layer 2), not a data-shape self-check, so it follows the sibling layer's
pattern instead.

Checks, in order: registry locked (`INVALID_REGISTRY`) -> terrain produces a
`VoxelTool` (`INVALID_TERRAIN`) -> `command.position` inside `terrain.bounds`
(`OUT_OF_BOUNDS`) -> per-kind. `PLACE`: `block_id` is actually registered
(`UNKNOWN_BLOCK`, distinct from 044's grammar/domain-only check), target voxel is air
(`TARGET_OCCUPIED` otherwise). `REMOVE`: target voxel is not air (`TARGET_IS_AIR`
otherwise), its resolved id exists in the registry (`UNRESOLVABLE_VOXEL` otherwise —
data corruption or a terrain built from a different registry, same defensive case
`block_raycast_service.gd`, 043, already guards), its `BlockDefinition.destructible` is
true (`NOT_DESTRUCTIBLE` otherwise). Reuses the exact `+1`/`-1` air-offset convention
043 established (`tool.get_voxel(pos) - 1` -> `registry.id_from_network_index()`) —
no new offset logic.

Bounds decision: rather than invent a bounds concept ahead of brick 050 ("voxel world
bounds/authority policy"), this reads `VoxelTerrain.bounds` directly — a real property
that already exists on every terrain (confirmed via `doc/classes/VoxelTerrain.xml`,
`godot_voxel` v1.7 tag, fetched this brick: `type="AABB"`, in voxel coordinates,
currently left at the engine's own effectively-unbounded default per
`docs/voxel-tools.md` §6). 050 only ever needs to set `terrain.bounds` correctly; no
second bounds mechanism was added here. Also confirmed this brick: `VoxelNode` itself
(the `VoxelTerrain` base class) carries no `bounds` member — it is `VoxelTerrain`'s own
addition, not inherited, so a future non-`VoxelTerrain` `VoxelNode` subtype would need
its own equivalent decision.

Logging is deliberately asymmetric: `INVALID_REGISTRY`/`INVALID_TERRAIN`/
`UNRESOLVABLE_VOXEL` go through `Log.check()` (programmer/data errors), but the five
ordinary gameplay verdicts are *not* logged — `docs/server-authority.md` §4 ("rejection
is normal") plus `docs/logging-and-errors.md`'s no-per-frame-spam rule, since block
edits (mining swings, misclicks) can be frequent enough that per-rejection logging
would be exactly that spam. No stateful metrics/counters (`CommandGate`'s
`_rejections` dictionary) were added — this validator is a stateless per-command check
with no peer state to key metrics on, same "plain static utility" shape as
`block_raycast_service.gd` (043); a future server loop can add counting at its own call
site if needed, without changing this file.

Tests: `tests/unit/test_block_edit_validator.gd` (9 tests, +9 total) — split the same
way `test_block_raycast_service.gd` (043) splits its own: `INVALID_REGISTRY`/
`OUT_OF_BOUNDS`/`UNKNOWN_BLOCK` against a built-but-unmeshed terrain (added to the tree
so `get_voxel_tool()` is real, but no wait for meshing since these never read voxel
content), and the five voxel-content-dependent verdicts (`ACCEPT`/`TARGET_OCCUPIED`/
`ACCEPT`/`NOT_DESTRUCTIBLE`/`TARGET_IS_AIR`) against a fully meshed terrain via the same
poll-`is_area_meshed()` `_ready_terrain()` helper 043's test file uses, plus
`verdict_name()`. `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed for gameplay design, same as
031–044 (only the one `VoxelTerrain.xml` engine-doc fetch above, for `bounds`'s real
type).

`044` added `network/packets/edit_block_command.gd` (`EditBlockCommand`) — the
`docs/protocol.md` §2 worked example given a concrete shape. Carries only intent: `kind`
(`PLACE`/`REMOVE`), `position` (the voxel to write), `face_normal` (the struck face, for
gameplay validation in 045 that needs approach direction), `block_id` (required and
`StableId`-checked for `PLACE`, must be empty for `REMOVE`), and `tick`
(`MessageTaxonomy.requires_tick()`). Deliberately excludes peer/owner/sequence — per
`docs/server-authority.md` A4, ownership is resolved by `CommandGate` from the connection,
never carried in the payload. `from_hit(hit: BlockRaycastHit, kind, block_id, tick)`
picks `hit.placement_position` for `PLACE` and `hit.hit_position` for `REMOVE`
automatically, so no caller re-derives that distinction (043's hand-off note). `validate()`
is structural only (well-formed id, correct domain, empty/non-empty `block_id` matching
`kind`, non-negative tick) — whether the position is in-bounds or the block is placeable
is 045's job, against world state, not this type's. Tests:
`tests/unit/test_edit_block_command.gd` (10 tests, +263 total).

One non-obvious parser interaction surfaced and is worth keeping: `check_scripts.gd`'s
self-check (renames a copy's `class_name` to `X__selfcheck` to parse it without
conflicting with the already-registered real class) makes a **bare** nested-type
reference (e.g. `Kind` used unqualified as a parameter type) resolve to the *local*
(renamed) copy, while a **fully-qualified** reference (`EditBlockCommand.Kind`, or the
class's own name written out as a return type) resolves through the global class-cache
lookup to the *real* class — two nominally different types for the same enum. A static
factory that both takes its own nested enum as a parameter and constructs itself via the
explicit class name (`EditBlockCommand.new(...)`) must qualify the parameter type the
same way (`p_kind: EditBlockCommand.Kind`, not bare `Kind`) or the self-check fails with
a spurious argument/return-type mismatch that only exists under the renamed copy, never
in a real run. No prior file collided with this (existing self-constructing factories
like `DeterministicRng.from_seed()` pass only primitives).

`043` added `world/terrain/block_raycast_service.gd` (`BlockRaycastService`, static
`cast(terrain, registry, origin, direction, max_distance) -> BlockRaycastHit`) — the
first code calling `VoxelTool.raycast()`. `VoxelRaycastResult` (the engine's own return
type) only carries a raw voxel position/normal/distance, with no concept of
`BlockRegistry` or the `+1` air offset `blocky_library_builder.gd` (037) established;
`cast()` reads the hit voxel's raw value via `tool.get_voxel()`, subtracts the offset,
and resolves it through `registry.id_from_network_index()`, returning a small typed
result, `world/terrain/block_raycast_hit.gd` (`BlockRaycastHit`: `block_id`,
`hit_position`, `placement_position`, `normal`, `distance`). Returns null (logged) for an
unlocked registry, a zero direction, a terrain with no voxel tool, a plain miss, or an
unresolvable voxel value. Same "no player/camera yet" scope as 039–042: `cast()` takes
an explicit ray rather than reading one from a camera. `collision_mask` is left at
`VoxelTool.raycast()`'s own default (every bit set) — a non-solid block's model already
has `collision_mask = 0` (037), so it's excluded from a hit regardless; no extra
filtering decision was needed. `DEFAULT_MAX_DISTANCE` (10.0) is named explicitly even
though it matches the engine default, same "explicit, not merely matching the default"
reasoning 041/042 used — real player reach balance is Phase F/G and may replace it
outright.

This brick surfaced one thing worth recording that no upstream doc page states:
`VoxelToolTerrain.raycast()` only finds a hit once the terrain has actually meshed the
area under the ray — confirmed by direct experiment (a throwaway headless probe script,
not committed), not by reading a doc page. Even against the placeholder
`VoxelGeneratorFlat` (039) with no stream/persistence involved, this needs the
`VoxelTerrain` added to the `SceneTree` with a `VoxelViewer` nearby and several real
frames for Voxel Tools' worker threads to catch up; `try_set_block_data()` does not work
synchronously outside the tree either (returned `false` even several frames after being
added). Recorded in `docs/voxel-tools.md` §10 (new section). Tests in
`tests/unit/test_block_raycast_service.gd` (4 tests, +252 total) poll
`VoxelTerrain.is_area_meshed()` per frame up to a generous cap rather than waiting a
fixed frame count, so the test doesn't flake on worker-timing variance: unlocked-registry
rejection and zero-direction rejection (both fail before touching the terrain, no tree
needed), a real hit on the placeholder ground (block id, hit/placement positions,
distance all asserted against `VoxelTerrainBuilder.PLACEHOLDER_GROUND_HEIGHT`), and a
miss (ray pointing into open air) returning null. No reference read — traceability.md §2
confirmed 043 isn't cited by any matrix, same as 031–042.

`042` added `world/terrain/voxel_viewer_builder.gd` (`VoxelViewerBuilder`, static
`build() -> VoxelViewer`) — the last of the four `VoxelNode`/`VoxelTerrain` properties
`docs/voxel-tools.md` §6 had split across bricks 039–042. `VoxelViewer` turned out to be
a separate `Node3D`, not a `VoxelTerrain` property — confirmed by fetching
`doc/classes/VoxelViewer.xml` and re-checking `VoxelTerrain.xml`'s `max_view_distance`
doc from the `godot_voxel` reference repo (CLAUDE.md §15 source) — so the brick splits
into two small pieces: `voxel_terrain_builder.gd` now also sets
`terrain.max_view_distance = DEFAULT_VIEW_DISTANCE` (a new constant, `128`, matching both
properties' own engine default but named explicitly so it can't drift into two
independently-defaulted literals), and the new `voxel_viewer_builder.gd` builds a
`VoxelViewer` with `view_distance` set to that same constant plus `requires_visuals =
true`/`requires_collisions = true` — explicit, not merely left at the matching engine
default, same "explicit is a real decision" reasoning 041 used for `material_override`.
`enabled_in_editor`/`requires_data_block_notifications` are left at their engine defaults
(`false`) — no live-in-editor streaming workflow or block-notification consumer exists to
justify overriding either.

Neither builder adds the viewer to a scene tree or parents it under a camera — no
player/camera exists yet (Phase F, bricks 106–130) to attach it to. This carries forward,
not resolves, the "where does this node live in a scene" question 039's own nextsteps
entry first raised; full reasoning in `docs/voxel-tools.md` §9 (new section, same pattern
as §§6–8). Tests: `tests/unit/test_voxel_viewer_builder.gd` (new, 2 tests) — baseline
`requires_visuals`/`requires_collisions` are true, and `view_distance` matches
`VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE` exactly (the coupling this brick's whole
design rests on). `tests/unit/test_voxel_terrain_builder.gd`'s existing
`test_builds_a_configured_voxel_terrain` gained one assertion (`max_view_distance ==
DEFAULT_VIEW_DISTANCE`), same shape as 041's addition to that same test. No new docs
contract beyond `docs/voxel-tools.md` §9 — this is a direct continuation of §§6–8's
per-property pattern, not a new one.

`041` resolved the open question `nextsteps.md` itself had flagged (former "Next 10
actions" item 1): does `VoxelTerrain.material_override` still need a value now that
037/040 already give every block kind its own per-model `StandardMaterial3D` (texture
atlas + baked-AO flag)? Fetched `doc/source/blocky_terrain.md` from the `godot_voxel`
reference repo (CLAUDE.md §15 source) — it documents an explicit override order where a
non-null `VoxelTerrain.material_override` replaces *every* per-model material in the
mesher's library, not adds to them. Setting one here would have silently discarded the
per-block atlas texturing already built and tested. Since nothing in this project needs
one material applied uniformly across every block kind yet, the correct baseline is an
**explicit `null`** — `world/terrain/voxel_terrain_builder.gd` now sets
`terrain.material_override = null` as a real assignment (same style as the existing
explicit `terrain.stream = null`), not left merely implicit, so the decision reads as
intentional rather than an oversight. Full reasoning in `docs/voxel-tools.md` §8 (new
section, following the §6/§7 per-brick pattern 039/040 established); §6's property table
row updated to point at it. No new `.tres`/asset/registry work — this brick is a single
property decision plus its documentation and test, not new content.

Tests: `tests/unit/test_voxel_terrain_builder.gd`'s existing
`test_builds_a_configured_voxel_terrain` gained one assertion
(`terrain.material_override` is null) rather than a new test method — same coverage
shape as the adjacent `stream`/`generate_collisions` assertions it sits beside. No other
file needed a test change. `docs/reference/matrix-world.md` Q1 and
`docs/reference/traceability.md` §3 already carried `(RESOLVED — brick 040)` covering
bricks "040–041" jointly — both already read correctly and needed no edit, since 041's
finding (no additional shader/material equivalent needed) is consistent with, not a
change to, that resolution.

`040` extended `world/terrain/voxel_terrain_builder.gd` (039) to also build and assign
`terrain.mesher`: a plain `VoxelMesherBlocky` whose `library` comes from
`BlockyLibraryBuilder.build(registry)` (037), the same `registry` argument the
placeholder generator already reads — the generator and mesher can never disagree about
which block ids exist. No new file — one property assignment plus a three-line
`_build_mesher()` helper inside the existing builder, since wrapping one library in one
mesher didn't justify a dedicated `VoxelMesherBuilder` class. `build()` now returns null
if `_build_mesher()` does (only reachable via `BlockyLibraryBuilder.build()` returning
null, which itself only happens for an unlocked registry — already rejected earlier in
`build()`, so this is a defensive propagation, not a new failure mode).

This brick also resolved `matrix-world.md` Q1 (open since brick 021, blocking 040–041
per `docs/reference/traceability.md` §3): does the terrain material/shader need a custom
equivalent of the reference's `ChunkBuffer_sampleVoxelColorAO` baked-color-AO blend, or
is `VoxelMesherBlocky`'s own baked AO sufficient? Fetched
`doc/source/blocky_terrain.md` from the `godot_voxel` reference repo (CLAUDE.md §15
source) to check: `VoxelMesherBlocky` always bakes ambient occlusion into cube-edge
vertex colors; a model's material only needs `vertex_color_use_as_albedo = true` to
display it — no custom shader needed. Answer: **sufficient**. Applied by setting that
one flag on `blocky_library_builder.gd` (037)'s existing per-block `StandardMaterial3D`
(`_build_model()`), not by starting 041's terrain-level `material_override` scope early.
Recorded in `docs/voxel-tools.md` §7 (a new section, not a new `world-terrain-material.md`
file — the answer is a compact engine fact, not a design needing its own document);
`matrix-world.md` Q1 and `traceability.md` §3's Q1 row both carry the
`(RESOLVED — brick 040)` prefix per the brick-029 open-question lifecycle, row not
deleted.

Tests: `tests/unit/test_voxel_terrain_builder.gd` (6 tests, +2 net after removing the
now-false "mesher is 040's responsibility" assertion) — mesher is a real
`VoxelMesherBlocky`, and its library's model at `network_index(id) + 1` has
`resource_name == id`, confirming the generator and mesher share one offset convention.
Its `_block()` helper now writes real 2x2 `user://` PNGs (same pattern
`test_blocky_library_builder.gd` already used) instead of referencing nonexistent
`res://dummy_*.png` paths — those paths were harmless before 040 because nothing ever
loaded them; building a real mesher now does, and surfaced this immediately as a test
failure (`Error opening file`), not a silent gap.
`tests/unit/test_blocky_library_builder.gd` (+1 test): a solid block's material has
`vertex_color_use_as_albedo == true`. No docs page changed beyond `voxel-tools.md` §7
and the two open-question rows above.

`039` added `world/terrain/voxel_terrain_builder.gd` (`VoxelTerrainBuilder`, static
`build(registry: BlockRegistry) -> VoxelTerrain`) — the first code that instantiates a
real `VoxelTerrain` node. Scope is deliberately one node's worth of the properties Phase
C splits across 039–042: this brick owns `generate_collisions` (`true`) and `generator`;
`mesher` is left unset for 040 (`BlockyLibraryBuilder`'s output), `material_override` for
041, `VoxelViewer`/`max_view_distance` for 042. `stream` is explicitly set to `null` —
persistence is 048, and `VoxelNode.stream`'s own doc says an unassigned stream makes the
whole volume regenerate from the generator, which is exactly what a save-less baseline
needs. `bounds` is left at the Voxel Tools engine default — no world-size decision exists
yet to justify overriding it, and inventing one wasn't this brick's job.

The `generator` is an explicit, temporary placeholder, not real world generation: a flat
plane of one registered block (`block.stone`) via `VoxelGeneratorFlat` (`channel =
VoxelBuffer.CHANNEL_TYPE`, `voxel_type = registry.network_index(id) + 1`, reusing the
exact +1 air-offset convention `blocky_library_builder.gd` (037) established). Real
generation is Phase D (056–067, deterministic noise/height/climate fields per
`docs/reference/matrix-world.md`), which replaces `terrain.generator` outright rather
than extending this file — recorded explicitly in both the file's own header comment and
`docs/voxel-tools.md` §6 so a future reader doesn't mistake the placeholder for a design
decision. Verified against the upstream `godot_voxel` doc classes (`VoxelNode.xml`,
`VoxelTerrain.xml`, `VoxelGeneratorFlat.xml`, `VoxelBuffer.xml`) fetched this brick,
since no local doc page previously recorded `VoxelTerrain`'s own property surface
(037 only needed `VoxelBlockyLibrary`/`VoxelBlockyModel`).

Same "one entry missing, not a crash" degrade pattern as 037: `build()` returns null (and
logs via `Log.CH_VOXEL`) for an unlocked registry or a registry missing
`PLACEHOLDER_BLOCK_ID`, rather than building a half-configured node. `docs/voxel-tools.md`
§6 records the full property table and both explicit-null decisions (`stream`, deferred
`bounds`). Tests in `tests/unit/test_voxel_terrain_builder.gd` (4 tests): unlocked-registry
rejection, missing-placeholder-block rejection, `mesher`/`stream` left null while
`generate_collisions` is true, and the generator's `channel`/`voxel_type`/`height` values
including the network-index-plus-one offset. No scene (`.tscn`) added — the builder
returns a plain `VoxelTerrain` node for a caller to add to a tree; wiring it into
`client/main/main.tscn` or a dedicated world scene is left to whichever of 040–042 first
needs something visible to test against.

`038` added the first real, committed content: four placeholder textures under
`assets/textures/blocks/` (`grass_top.png`, `grass_side.png`, `dirt.png`, `stone.png` —
16x16, flat base color plus small deterministic per-pixel noise so faces read as a
material rather than a solid swatch; `grass_side` is dirt with a green fringe on the top
quarter, the reference grass-block silhouette) and three `BlockDefinition` resources
under `data/blocks/` (`grass.tres`, `dirt.tres`, `stone.tres`), both written by a new
one-off headless generator, `tools/generators/generate_block_set.gd` (a new `generators/`
subdirectory of `tools/`, alongside `probe/` — deterministic content generation run via
`--script`, output committed and re-generatable, distinct from `probe/`'s "assert
something about the environment" role). The generator calls `BlockDefinition.validate()`
and `ResourceSaver.save()` itself, so a bad field value fails the generation step, not a
later load. Texture/data paths match exactly what `test_block_definition.gd` and
`test_block_registry.gd` already hardcoded as example fixtures (`grass_top.png`,
`grass_side.png`, reusing `dirt.png` as grass's bottom face) — those tests never asserted
the files existed, but the coincidence confirmed the naming scheme before any file was
written. `hardness` differs per kind (grass 0.5, dirt 0.75, stone 3.0) as a first
placeholder mining-effort ordering; `drop_item_id` is left empty on all three — no
`ItemRegistry` exists yet (Phase H), and 035 already made that field optional for exactly
this reason.

Added `world/terrain/block_set.gd` (`BlockSet`, static `load_default(dir) -> BlockRegistry`)
— the loader `block_definition.gd`'s own header comment predicted back in 031 ("a loader
parses `data/blocks/*.tres` ... and hands each one to a `BlockRegistry`"), and the first
concrete implementation of `docs/ids-and-registries.md`'s generic "a loader parses data
and calls register()" line. Scans the directory and sorts filenames rather than
hardcoding the three ids, so a later block kind is purely a new `.tres` data file — no
loader change. A missing directory, a file that fails to load, a file that isn't a
`BlockDefinition`, or a definition that fails its own `validate()` is logged and skipped
rather than failing the whole load, same "one entry missing, not a crash" contract
`BlockRegistry.register_block()` already uses; the returned registry is always locked,
even when nothing loaded. No new docs page — this is a direct implementation of an
existing contract, not a new one, same reasoning 033–036 used.

Running the generator against the real project surfaced one thing worth recording: once
these PNGs are real, imported `res://` project assets (rather than the runtime-only
`user://` PNGs `test_blocky_library_builder.gd` synthesizes), loading them with
`Image.load()` — what `blocky_library_builder.gd` (037) does for every face texture —
now prints an engine warning, `"Loaded resource as image file, this will not work on
export"`. Tests still pass (the warning doesn't fail anything headless), but it is a real
signal that this texture-loading path will not survive an exported build, not just a
theoretical one — recorded in Known risks below rather than fixed here, since fixing it
means changing `blocky_library_builder.gd` (037)'s already-tested loading strategy, out
of this brick's "create a block set" scope.

Tests added in `tests/unit/test_block_set.gd` (5 tests): default load is a locked
registry with exactly grass/dirt/stone; footstep tags match each kind; every loaded
definition is individually valid; the default set builds a real `VoxelBlockyLibrary`
through `BlockyLibraryBuilder` with **no** block degrading to a placeholder (the
end-to-end check that the real texture assets actually load, not just the synthetic ones
037's own tests generate); and a missing directory returns an empty, still-locked
registry rather than null or a crash.

`037` added `world/terrain/blocky_library_builder.gd` (`BlockyLibraryBuilder`, static
`build(registry: BlockRegistry) -> VoxelBlockyLibrary`) — the first brick that actually
constructs Voxel Tools engine resources from `BlockDefinition` data, closing the
"deferred to 037" note left on `texture_top`/`texture_side`/`texture_bottom` (033) and
`is_solid`'s collision-layer mapping (034). Two decisions this brick had to make, both
now recorded:

1. **`VoxelBlockyLibrary` + `VoxelBlockyModelCube`, not `VoxelBlockyType`/
   `VoxelBlockyTypeLibrary`** — recorded in `docs/voxel-tools.md` §5, which had flagged
   this as a required deliberate choice since brick 003. `BlockDefinition` has no
   attribute/state axis (no rotation, no connected-state), so the plain library is the
   correct minimal fit; revisit only if a future block kind needs per-voxel state.
2. **Voxel value 0 = air, offset by one from `BlockRegistry.network_index()`.**
   `network_index()` is a general registry concept (032, used for packets/saves too) and
   was not redefined to reserve 0 for air. Instead `build()` inserts an explicit
   `VoxelBlockyModelEmpty` at library index 0, then appends one model per
   `registry.ids()` entry (sorted == locked network-index order) — `add_model()` assigns
   indices by call order, so the result is always `library index == network_index(id) +
   1`. Any future code writing raw voxel values (block edit application, 044–046) must
   apply that `+1`. Documented in the file's own header comment, not just here.

Texture resolution (deferred by 033) turned out to need a real sub-decision:
`VoxelBlockyModelCube.set_tile(side, position)` addresses one shared atlas per model —
confirmed by fetching `doc/source/blocky_terrain.md` from the `godot_voxel` reference
repo (CLAUDE.md §15 source) — so three independent per-face image paths cannot be
wired in directly. `_build_atlas()` packs each block's own top/side/bottom images into
one small 3-tile-wide runtime atlas (`Image.blit_rect`, no dedup for a block whose
faces repeat one path — not worth the complexity yet, `CLAUDE.md` §8) and assigns it as
a `StandardMaterial3D` on the model (nearest-filter, for the blocky look). A missing or
unreadable face texture, or three face textures that don't share one size, degrades
that one block to a placeholder `VoxelBlockyModelEmpty` and logs why — `build()` keeps
going rather than failing the whole library, same "one entry missing, not a crash"
pattern `BlockRegistry.register_block()` already uses. `collision_aabbs` also needed an
explicit decision: Voxel Tools does not default a cube model to a full collision box —
an empty list means no collision — so `is_solid` now maps to one explicit unit-cube
`AABB`, confirmed against the same reference doc page.

No real texture assets exist yet (038 creates the first grass/dirt/stone set), so
`tests/unit/test_blocky_library_builder.gd` (8 tests) generates its own tiny PNGs under
`user://` at test time (`Image.create` + `fill` + `save_png`, cleaned up in
`after_each`) rather than depending on `res://assets/textures/blocks/*`. Covers:
unlocked-registry rejection, air-only library for an empty registry, index-plus-one
alignment against two registered blocks, solid/opaque vs non-solid/transparent
collision+culling, atlas packing (pixel-exact via 8-bit `Color8` values, since a PNG
round trip quantizes float color), missing-texture degrade, and mismatched-face-size
degrade. `docs/voxel-tools.md` §5 updated with the decision (see above); no ADR — the
README's own "routine implementation choice inside a single file" exclusion applies
once the library-vs-type choice itself is recorded, and this file's own header comment
carries the +1 offset and atlas reasoning for the next reader.

`036` extended `world/terrain/block_definition.gd` with the last block-property field
this phase deferred: `footstep_tag: String = ""` — a plain lowercase surface-material
category ("grass", "dirt", "stone", ...) for footstep/movement audio. Deliberately not
a stable ID: unlike `drop_item_id` (035), which names one piece of identified content
(an item) that will eventually live in a registry, `footstep_tag` names a *category*
shared by many block kinds and is never looked up through a registry — no `sound`-domain
ID or registry entry is created for it. It is the input key, not a reference, to the
tag -> sound-event table that backlog brick 220 ("footstep/audio surface mapping",
Phase J) builds; that mapping is out of scope here, same as texture-path resolution
staying out of scope for 033 pending 037. Required (like the texture fields) rather than
optional (like `drop_item_id`): every block a player can stand on needs a footstep
category, and unlike `hardness` (harmless-but-meaningless when `destructible` is false)
there's no default value that would be correct for an unset tag, so `validate()` rejects
an empty string. `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed, same as 031–035. Tests extended in
`tests/unit/test_block_definition.gd` (24 tests, +1): missing-footstep_tag rejection;
`_valid()` now sets `footstep_tag = "grass"`. `tests/unit/test_block_registry.gd`'s
`_grass()`/`_dirt()` helpers updated to set `footstep_tag` so they stay valid under the
new mandatory field (no new registry tests needed, same reasoning as 033–035). No docs
page added — same "direct application of an existing convention" (required-string-field
pattern already used by the texture fields) reasoning as 033–035, not a new contract.
Phase C's per-block-property bricks (031–036) are now complete; 037 (`VoxelBlockyLibrary`
bootstrap) is next.

`035` extended `world/terrain/block_definition.gd` with three fields: `destructible: bool
= true` (bare adjective, same style as `transparent`, not `is_destructible` — independent
of `is_solid`, since a block can collide but never be destroyed or vice versa), `hardness:
float = 1.0` (an abstract positive mining-effort multiplier, deliberately not seconds and
not tied to any tool-tier scheme — that belongs to Phase G/H equipment/combat data, not
block-kind data; validated `> 0` regardless of `destructible`, so a data file can't carry
a stale nonsensical value), and `drop_item_id: String = ""` (stable ID, domain `item`,
empty = no drop; quantity/roll variance is deferred to the Phase H loot system — this
field only names *what*, not how many). No `ItemRegistry` exists yet, so `validate()`
only checks `drop_item_id`'s grammar and domain via `StableId`, the same way `id` itself
is checked without a live registry to cross-reference — whether the named item actually
exists is a data-loading-time concern, not this resource's, same reasoning brick 033 used
for texture paths. `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed, same as 031–034. Tests extended in
`tests/unit/test_block_definition.gd` (23 tests, +9): destructible default/false-stays-
valid, hardness default/zero-rejected/negative-rejected, drop_item_id default-empty-
valid/well-formed-accepted/malformed-rejected-with-field-prefix/wrong-domain-rejected.
`tests/unit/test_block_registry.gd` needed no change — all three new fields default to
values that keep its existing `_grass()`/`_dirt()` helpers valid unmodified, same as 034.
No docs page added — same "direct application of an existing convention" reasoning as
031–034, not a new contract.

`034` extended `world/terrain/block_definition.gd` with a single `is_solid: bool = true`
field — whether the block kind produces collision at all. Deliberately a plain predicate,
not a raw `VoxelBlockyModel.collision_mask` bitmask: `docs/conventions.md` §5 already uses
`is_solid`/`has_collision` as its own worked example of the boolean-naming rule, which
reads as an intentional pointer to this exact field name, so no reference read or extra
design was needed to pick it. Unlike 033's texture fields, `is_solid` is not a direct
1:1 mirror of one `VoxelBlockyModel` property the way `transparent` is — which physics
layer(s) a solid block occupies is left as an engine-integration decision for the
`VoxelBlockyLibrary` bootstrap (037: e.g. `is_solid ? 1 : 0` or similar), not block-kind
data. No `validate()` change: like `transparent`, a bool has no invalid state, so
`is_valid()` stays true regardless of `is_solid`'s value. `docs/reference/traceability.md`
§4 already confirmed no reference matrix cites 031–055, so no reference read was needed,
same as 031–033. Tests extended in `tests/unit/test_block_definition.gd` (13 tests, +2):
default-true check, and an explicit-false-stays-valid check documenting that collision is
engine-integration, not a validity rule. `tests/unit/test_block_registry.gd` needed no
change — `is_solid` defaults to true, so its existing `_grass()`/`_dirt()` helpers stay
valid unmodified. No docs page added — same "direct application of an existing
convention" reasoning as 031–033, not a new contract.

`033` extended `world/terrain/block_definition.gd` with the material fields 031 deferred:
`texture_top` / `texture_side` / `texture_bottom` (plain `res://...` `String` paths, same
"no editor hint" style as `id`/`display_name`) and `transparent: bool = false`. Three
faces, not six or one — matches the top/side/bottom scheme every reference block needs
(grass: green top vs dirt-textured sides) without guessing at a full six-sided model this
early; a uniform block (stone) just repeats one path in all three fields. `transparent`
carries `VoxelBlockyModel`'s own face-culling flag so the `VoxelBlockyLibrary` bootstrap
(037) can set it directly instead of re-deriving it from texture content — recorded on
the definition now because CLAUDE.md §10 calls out preserving exact culling behavior.
`validate()` now rejects any of the three texture fields being empty, same
empty-string-reason convention as `display_name`. No stable-ID domain was added for
textures/materials (`StableId.DOMAINS` unchanged) — texture assignment is a resource
path, not gameplay-content identity, so it doesn't need one. Actual `Texture2D`/
`Material`/`VoxelBlockyLibrary` construction stays out of scope, deferred to 037 per
031's original plan. `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed, same as 031/032. Tests extended in
`tests/unit/test_block_definition.gd` (11 tests, +5): three new missing-texture-field
rejections, one `transparent` default check, and `_valid()` now sets all three texture
fields; `tests/unit/test_block_registry.gd`'s `_grass()`/`_dirt()` helpers updated to stay
valid under the new mandatory fields (no new registry tests needed — the registry only
forwards to `BlockDefinition.validate()`, already covered). No docs page added — same
"direct application of an existing contract" reasoning as 031/032, not a new one.

`032` added `world/terrain/block_registry.gd` (`BlockRegistry extends RefCounted`,
`class_name` — the first live use of `DefinitionRegistry` outside its own tests, per
`docs/ids-and-registries.md` §5: "it does not validate the definition, only the id;
each domain's definition type checks its own fields"). Thin typed wrapper, not a
reimplementation: pins the domain to `"block"`, calls `BlockDefinition.validate()`
before handing anything to the wrapped `DefinitionRegistry.register()`, and returns
`BlockDefinition` instead of `Variant` at every read (`get_block`, `require_block`).
Every other method (`add_alias`, `lock`, `is_locked`, `clear`, `has_block`, `resolve`,
`ids`, `ids_under`, `size`, `network_index`, `id_from_network_index`, `content_hash`)
delegates straight through — the wrapper adds no state of its own beyond the one
`DefinitionRegistry` instance. `docs/reference/traceability.md` §4 already confirms no
reference matrix cites 031–055, so no reference read was needed, same as 031. Tests in
`tests/unit/test_block_registry.gd` (10 tests): valid registration, rejection of a
definition that fails its own `validate()` despite a well-formed id (missing
`display_name`), wrong-domain rejection, duplicate-id rejection, lock/network-index
ordering, post-lock registration refusal, alias resolution, sorted `ids()`/`ids_under()`,
order-independent `content_hash()`, and `clear()` round-trip. No docs page added or
changed — this brick is a direct application of the existing `docs/ids-and-registries.md`
contract, not a new one; `block_definition.gd`'s own doc comment already named this
brick as the intended consumer.

`031` added `world/terrain/block_definition.gd` (`BlockDefinition extends Resource`,
`class_name` — referenced by the registry/schema bricks that follow): `id`,
`display_name`, and a `validate()`/`is_valid()` pair mirroring `StableId.validate()`'s
"empty string = ok, else reason" convention, per `docs/ids-and-registries.md` §5 ("each
domain's definition type checks its own fields"). Deliberately minimal — material,
collision, interaction/destruction and footstep/surface-tag fields are scoped to bricks
033–036, not guessed here; no block-shape/mesh field either, left to 037's
`VoxelBlockyLibrary` bootstrap. `docs/reference/traceability.md` §4 already confirmed no
reference matrix cites 031–055, so no reference read was needed. Tests in
`tests/unit/test_block_definition.gd` (6 tests): valid/invalid shape, malformed id
(reason matches `StableId`'s own, not a reworded copy), wrong domain, missing
`display_name`, and one end-to-end registration into a `DefinitionRegistry.new("block")`.
No docs page added — this brick uses existing contracts (016, 011) rather than
establishing a new one.

`030` built `docs/reference/traceability.md`: a reverse index from backlog brick → matrix
row/concept, read off the `Bricks` column of every §1/§2 row across all 8 matrices
(021–028), organized by backlog phase (D through K — no reference-informed rows exist
before Phase D). §3 consolidates all 23 open questions from the 8 matrices' §4 sections
into one table with their `Blocks`/status, mirroring (not replacing) the "Next N actions"
list below per `confidence.md` §5. §4 records why most of Phase A/C/L have no rows (
original design, Voxel Tools supersedes the reference's own chunk cache) versus "not yet
cross-referenced" (an honest gap, not asserted absence). `matrix-index.md` §6 and
`README.md` §6 now point to it instead of describing the not-yet-built index. No code
changed — docs-only brick, same as 029; `check.ps1`/`test.ps1` not re-run for this reason,
last run stays the one recorded below.

`021` mapped `*/world/` (13 classes: `World`, `Zone`, `Region`, `Dungeon`, `House`,
`Spawn`, `Field`, `Chunk`, `ChunkBuffer`, `LandscapeTile`, `WorldInfo`, `WorldMap`,
`ZoneTile`) into `docs/reference/matrix-world.md`. Notable: `World` is a god-object
whose functions were split by behavior, not kept as one row (see matrix §2); several
classes (`Chunk`, `ChunkBuffer`, block/column accessors, the client per-frame world
tick) are `Placed = NONE` because `VoxelTerrain`/`VoxelMesherBlocky`/Godot's own
process loop supersede them — do not reimplement a parallel chunk cache. Four open
questions recorded (matrix §4), most importantly Q2: the original client re-ran world
generation locally rather than only presenting replicated state — confirm this was a
singleplayer-only pattern before brick 056.

`022` mapped `*/entity/` (6 classes: `Creature`, `Sprite`, `SpriteManager`, `Speech`,
`QuestText`, `QuestTextNode`) into `docs/reference/matrix-entity.md`. Notable:
`Creature`'s own attributed functions are almost entirely ctor/dtor/container plumbing
— actual creature behavior (locomotion, player-controller reset, replicated-state
apply, appearance/equipment defaults) is scattered across `game_misc` and the client
`World`/`Interface` sections and was split out in matrix §2, same pattern as `World` in
brick 021. `QuestText`/`QuestTextNode` are physically in `*/entity/` but reserved for
`matrix-quests.md` (026) per `matrix-index.md` — rows added with `Placed = NONE` so
they aren't silently dropped. Three open questions recorded (matrix §4): Q1 no backlog
brick currently cites this matrix for creature/player locomotion (112/116/128/243); Q2
`*/db/` (`cube::Database`) has no planned matrix at all; Q3 `Sprite`/`SpriteManager`
are stub-only in both binaries, role undetermined.

`023` mapped `*/ai/` (8 classes: `CombatBehavior`, `CompanionBehavior`,
`LookAtPlayerBehavior`, `RandomInteractionBehavior`, `RandomWalkBehavior`,
`SequentialBehavior`, `SpawnLocationBehavior`, `WalkPathBehavior`) into
`docs/reference/matrix-ai.md`. Every leaf shares one tick+clone interface (no separate
`Behavior` base class survived attribution — inferred and recorded in matrix §2, same
"concept with no single class" treatment as 021/022). `CombatBehavior`'s tick is an AI
decision shell but almost all of its named functions are ability timing/resolution math
— that math is `Placed = NONE` here, reserved for `matrix-combat.md` (024), continuing
the split pattern from `matrix-entity.md`. Nav/locomotion primitives
(`NavGraph_*`, `World_getBlockFloat`, `Creature_resolveSeparation`) are called by three
different leaves and owned by none — cross-referenced to `matrix-entity.md`'s Q1
instead of duplicating it. Three open questions recorded (matrix §4): Q1
`SequentialBehavior` executes like a first-success Selector despite its decompiled
name — need to decide if bricks 177/178 need both a true Sequence and a Selector; Q2
`SpawnLocationBehavior`'s location-switch condition reads an unconfirmed `world` field,
possibly the day/night clock (brick 216); Q3 `RandomInteractionBehavior`'s tick body
(773 lines) was not read in full, only GAP-summarized — revisit before brick 189/199 if
the one-line role proves insufficient.

`024` mapped combat resolution/damage/hit-detection into `docs/reference/matrix-combat.md`.
No reference class is named `Combat`/`Damage`/`Hit` — everything is 14 "concepts with no
single class" rows (ability timing table, attack-speed/haste, base-damage formula,
max-health formula, armor mitigation, resist diminishing-returns, ability power/mana
cost, resource regen, equipment stat-bonus plumbing, threat/target selection, hostility
gate, aggro-alert propagation, attack-opcode/animation classification, buff/status-effect
list), gathered from server `game_misc`/`CombatBehavior` GAP rows, `cube_types.h`'s
VERIFIED `cube_Creature_offsets`/`cube_BuffNode_offsets` enums, and client `Interface`
(`stat::calc*`) rows read only for corroboration. Three open questions recorded (matrix
§4): Q1 server `World.cpp`'s `readCombatActionFromStream`/`readHitFromStream` deserialize
fixed-size records from a SQLite-loaded blob (adjacent to `SpeechDb_loadBlobToVector`),
not obviously a live network read despite the name — unresolved whether this is
quest-script trigger data or prefigures the combat-event wire format (blocks 136, 137,
249); Q2 the damage/armor/mana formulas share an unexplained `2^a*2^b[/2^c]` shape across
independent functions in both binaries — shape is corroborated, meaning of the exponents
is not, and per the clean-room policy we may not need to recover it (blocks 141–144); Q3
the two attack-*selection* decision trees (`Combat_selectNextAttackAnim`,
`Combat_selectSpiritAttackId`) were read only via their one-line GAP summary, not their
bodies (blocks 138, 139, 192).

`025` mapped inventory/item/equipment concepts into `docs/reference/matrix-items.md`.
One dedicated class (`InventoryWidget`, client) placed in `client/ui/`; `Database`
cross-referenced as out of scope (same generic SQLite blob store already flagged in
`matrix-entity.md`); 9 "concept with no single class" rows gathered from server
`game_misc` item/equip/loot/currency functions and client `GameController`. Notable:
`attribution.tsv` attributes the actual inventory-grid rebuild/scroll/hover functions
(GAP-named `InventoryWidget_rebuildItemList` etc.) to `GameController`, not
`InventoryWidget` — `GameController` is a 620-function client class with no owning
matrix in 021–028, only its ~10 item-relevant functions were pulled in here, same
"concept with no single class" pattern as 021–024. Three open questions recorded
(matrix §4): Q1 `GameController` itself needs a home (a new matrix before 224/225, or
absorbed by 028); Q2 equipment slot count is contradictory across two server functions
(16 vs 12) with no VERIFIED offset to arbitrate, unlike combat's `cube_Creature_offsets`
— brick 164 must choose independently; Q3 the "rng affix" rolled by
`GameController_onItemPickup` was not read past its GAP one-liner, relevant before
brick 173 if affix mechanics matter for the loot roll service.

`026` mapped quest/NPC concepts into `docs/reference/matrix-quests.md`. Placed the two
classes deferred from `matrix-entity.md` (`QuestText`, `QuestTextNode` — a shared
templating/tree engine with `Speech`) and found no dedicated `NPC`/`Quest`/`Faction`/
`Shop` class in either binary: NPCs are plain `Creature` instances, and all quest/NPC
behavior is 7 "concept with no single class" rows pulled from client `GameController`
(`interactNpc`, `interactSpecialObject`, `computeQuestScore`, `questStateChanged`,
`build_quest_text`) and server `game_misc`/`EntityData` (quest strings stored inline on
the entity record, an opcode-tagged `check_quest_id_match`). Notable: quest progress in
the original is a **polled derived score** (`computeQuestScore` sums 11 unrecovered
counters), not a discrete objective list — the backlog's brick 207 "objective types"
design is judged an acceptable behavioral equivalent, not a reference deviation, since
the exact counters are decompiler data we would not ship anyway (matrix §4 Q1). Faction/
hostility/aggro was **not** re-placed — already fully mapped in `matrix-combat.md` §2,
cross-ref only. Two open questions recorded (matrix §4): Q1 the unrecovered 11-counter
quest score (likely resolvable by design decision alone, see above); Q2 whether
`check_quest_id_match`'s `event type 0x19` is the same opcode-tagged stream as
`matrix-combat.md` Q1's `readCombatActionFromStream`/`readHitFromStream` — re-opens that
question with new evidence, relevant before brick 251. Brick 200 ("NPC shop service")
already covers the `interactNpc` trade-UI branch found here, so no new question was
needed for it. `matrix-items.md` Q1 (`GameController` scoping) gained corroborating
evidence rather than a duplicate question.

`027` mapped `cube/ui/` (24 files, 22 `cube::` classes) into `docs/reference/matrix-ui.md`.
Every widget but one is stub-only (1–2 attributed functions — ctor plus a render/input
vfunc); the exception, `AdaptionWidget` (28 attributed functions), is the shared layout/
scroll/bounds/animation engine every other widget inherits from, same "one real class,
rest are thin leaves" shape as `matrix-ai.md`'s behavior tree. Two files in the directory
(`Button`, `ScrollSlider`) declare only `plasma::` methods — misfiled engine-layer
widgets, moved to §3 out-of-scope, same pattern as the combat functions cross-referenced
out of `matrix-world.md`. `cube::WorldPreviewWidget` (deferred from `matrix-world.md`,
021) was placed here; `cube::InventoryWidget` (already placed in `matrix-items.md`, 025)
was cross-referenced, not re-placed. Notable: `GameController` GAP rows for mouse
routing, hover/focus, widget-tree file deserialization (`.CUB` format), and the
character-select/world-select screen builders (`buildCharacterList`/`buildWorldList`)
confirm — a third and fourth time, after `matrix-items.md` and `matrix-quests.md` — that
the actual client UI framework lives on `GameController`, not on any `Widget` subclass;
folded into `matrix-items.md` Q1 as corroborating evidence rather than a new question.
Two open questions recorded (matrix §4): Q1 several reference UI screens (character
creation, main menu/title screen, merchant/trade dialog) have no corresponding backlog
brick yet; Q2 `GameController`'s widget-framework slice keeps growing across three
matrices with no owning matrix or brick — same underlying question as
`matrix-items.md` Q1, now with UI-framework evidence added.

`028` mapped the client/server split into `docs/reference/matrix-client-server.md` — the
last of the mapping bricks (021–028). Only 2 dedicated networking classes exist
(`cube::Server`, `cube::Connection`, both server-only, both stub-only on their own
attributed functions); the actual protocol logic is 9 "concept with no single class"
rows. Notable finding: the send-loop/recv-dispatch/serialize functions GAP-names after
`Server`/`Connection`/`World`/`EntityData` are physically filed under `Global` (no
owning class) inside `server/_library/crt_stl.cpp` — the automated attribution tool
treats them as library code because they're vtable-less free functions, but GAP naming
and a `std::function`-lambda call-graph read (each wrapped in its own thunk) confirm
send and receive run as two independent per-connection workers. The client binary has
**no networking class or `net/` directory at all** — its socket-facing functions
(`net::Connection::recv_delta_*`, `EntityState_deserializeFromBuffer`/
`recvFromSocket`) are entirely unattributed (`kind=lib,target=other`), invisible to a
class-based read; the one class-attributed touchpoint, `GameController_disconnect`,
continues the same "GameController is the real framework" pattern already seen in
`matrix-items.md`/`matrix-quests.md`/`matrix-ui.md`. Two prior open questions were
**closed** this brick, not just cross-referenced: `matrix-combat.md` Q1 — a wider read
of the `World.cpp` call site (blob key built from `"mission"`/`"monster"` + int IDs)
confirms `readCombatActionFromStream`/`readHitFromStream` are quest-script trigger data,
not a network wire format, so bricks 249/251 must design combat-event replication fresh;
and `matrix-items.md` Q1 / `matrix-ui.md` Q2 (`GameController` scoping) — resolved by
decision, same god-object treatment as `World`/`Creature`/the `Behavior` tree, no new
matrix or brick. One new question recorded (matrix §4 Q3): no connect/login/handshake
function was found in either binary's attributed or GAP-named set — a genuine gap in the
source material (`docs/protocol.md`'s independently-designed `HANDSHAKE` kind has no
reference behaviour to corroborate, and does not need one per the clean-room policy).

`029` formalized the confidence/uncertainty convention sketched in `docs/reference/README.md`
§4 into `docs/reference/confidence.md`: a second axis (read depth — `FULL`/`PARTIAL`/
`GAP-ONLY`/`UNREAD`) alongside claim confidence, a ceiling rule that a `GAP_ANALYSIS.md`
-only claim cannot be recorded `HIGH` unless independently corroborated (with the
existing `matrix-client-server.md` dirty-bit row and `matrix-ai.md` ability-timing row
cited as the two correct patterns already in use), "overall confidence" defined as the
minimum over load-bearing claims rather than an average, and the open-question
resolution lifecycle (`(RESOLVED — brick NNN)` prefix, rewrite "Resolved by" in place,
never delete the row) formalizing the pattern brick 028 already used three times.
`README.md` §4 now points to it instead of restating a growing baseline; `_template.md`
and `_matrix_template.md` gained pointers and a read-depth column (template files only —
the 8 already-committed matrices from 021–028 are not retrofitted, per the brick's own
"decisions apply going forward" scope). No code changed; `check.ps1`/`test.ps1` untouched
and not re-run for this docs-only brick beyond the session-start check already recorded
above.

## Commands

```powershell
tools\scripts\check.ps1      # engine + import + voxel + full GDScript compile + headless boot
tools\scripts\test.ps1       # test suite  (-File / -Filter / -Verbose_ / -NoImport)
tools\scripts\run.ps1        # run the game (-Headless; game args forwarded past --)
tools\scripts\godot.ps1 -e   # open the editor
```

Last run (brick 089): compile probe **OK** (132 scripts) · headless boot **OK** · full suite **OK** — 63 files, 939 tests, 129 034 assertions, 0 failed. Run through the engine binary from `docs/environment.md` directly (`--headless --import`, then `--script res://tests/run_tests.gd`; `--script res://tools/probe/check_scripts.gd` for the compile probe), which is more reliable than the `.ps1` wrappers under a non-interactive shell. The runner reads filters from user args: `--script res://tests/run_tests.gd -- --test-file=<substr>` (the `--` separator is required). The full suite now takes >3 min — run it with a raised tool timeout / in the background, not the 120 s default.

## What exists now

| Area | File | Gives you |
|---|---|---|
| Logging | `autoload/log.gd` | levels, channels, `check()` vs `invariant()`, test capture |
| Scale | `core/math/world_scale.gd` | metres ↔ units ↔ voxels; the only place `0.5`/`2.0` may appear |
| Time | `core/time/simulation_clock.gd` | 60 Hz fixed step, catch-up clamp, snapshot cadence |
| RNG | `core/random/deterministic_rng.gd`, `world_hash.gd` | splitmix64 stream + positional hashing for generation; `world_hash.gd`'s axis folds multiply between axes **and add `_ROUND`** — XOR alone mirrored a quarter of the world through the origin (058), and multiply-alone still mirrored half of all (seed, salt) pairs, because multiplication preserves an exact negation (059) |
| IDs | `core/ids/stable_id.gd`, `definition_registry.gd` | ID grammar, catalogues, aliases, network indices |
| Blocks | `world/terrain/block_definition.gd` | Block-kind schema: `id`, `display_name`, `texture_top`/`texture_side`/`texture_bottom`, `transparent`, `is_solid`, `destructible`, `hardness`, `drop_item_id`, `footstep_tag`, `validate()` |
| Blocks | `world/terrain/block_registry.gd` | Typed `BlockDefinition` catalogue: validates fields, then delegates storage/locking/indices to `DefinitionRegistry` |
| Blocks | `world/terrain/blocky_library_builder.gd` | Builds a real `VoxelBlockyLibrary` from a locked `BlockRegistry`: air at index 0, per-block runtime texture atlas, collision/culling from `is_solid`/`transparent` |
| Blocks | `world/terrain/block_set.gd` | `BlockSet.load_default()`: scans `data/blocks/*.tres`, registers each into a locked `BlockRegistry` |
| Blocks | `data/blocks/*.tres`, `assets/textures/blocks/*.png` | First content: `block.grass`/`block.dirt`/`block.stone` definitions and their placeholder textures, written by `tools/generators/generate_block_set.gd` |
| Terrain | `world/terrain/voxel_terrain_builder.gd` | `VoxelTerrainBuilder.build(registry, stream = null, mesh_block_size = 16)`: a `VoxelTerrain` node with collision on, a placeholder flat-stone `VoxelGeneratorFlat`, and a `VoxelMesherBlocky` sourced from `BlockyLibraryBuilder`; `material_override` explicitly `null` (041 — per-block atlas materials are sufficient, see `docs/voxel-tools.md` §8); `max_view_distance = DEFAULT_VIEW_DISTANCE` (042); `stream` is an optional parameter, `null` unless the caller passes one (048); `bounds = WorldBounds.aabb()` (050); `mesh_block_size` optional, 16 or 32 only (052), default `16` fixed as a measured decision (054 / ADR 0002) |
| Benchmarks | `tools/benchmarks/benchmark_mesh_block_size.gd` + `mesh_block_size_benchmark_runner.gd` | Headless harness measuring `VoxelTerrainBuilder`'s `mesh_block_size` (16 vs 32) against the default block set/view distance; entry/runner split works around a `--script`-vs-autoload compile-order quirk (052/053, `docs/voxel-tools.md` §17-19 — size 16: ~376 ms/52 frames; size 32: ~347 ms/50 frames; identical data-block memory; brick 054 / ADR 0002 kept 16 as the default — the ~7-9% cold-start win for 32 is outweighed by its 8× per-edit re-mesh cost) |
| Persistence | `world/persistence/voxel_stream_builder.gd` | `VoxelStreamBuilder.build(database_path)`: a configured `VoxelStreamSQLite` — deltas-only (`save_generator_output = false`), key cache enabled, unbounded `COORDINATE_FORMAT_STRING_CSD` — a fixed-width format would now fit `WorldBounds`, but switching is a genuinely optional future revisit, not owed by brick 050 (048/050, `docs/voxel-tools.md` §13/§15) |
| World | `world/terrain/world_bounds.gd` | `WorldBounds.aabb()`/`contains(voxel_position)`: the authoritative world extent — `+-524288` voxels horizontal (X/Z), `+-2048` vertical (Y); assigned to `VoxelTerrainBuilder.build()`'s `terrain.bounds` unconditionally (050, `docs/voxel-tools.md` §15) |
| Terrain | `world/terrain/voxel_viewer_builder.gd` | `VoxelViewerBuilder.build()`: a `VoxelViewer` node with `view_distance = VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE`, `requires_visuals`/`requires_collisions` true; not yet parented under a camera (042, `docs/voxel-tools.md` §9 — no player/camera exists yet, Phase F) |
| Terrain | `world/terrain/block_raycast_service.gd`, `block_raycast_hit.gd` | `BlockRaycastService.cast(terrain, registry, origin, direction, max_distance)`: wraps `VoxelTool.raycast()`, resolves the hit voxel value back to a `BlockDefinition` id through the registry (043, `docs/voxel-tools.md` §10) |
| Network | `network/packets/edit_block_command.gd` | `EditBlockCommand`: PLACE/REMOVE intent (`kind`, `position`, `face_normal`, `block_id`, `tick`); `from_hit()` builds one from a `BlockRaycastHit`; `validate()` is structural only (044) |
| Terrain | `world/terrain/block_edit_validator.gd` | `BlockEditValidator.validate(command, terrain, registry)`: layer-2 gameplay validation against `terrain.bounds`/actual voxel content — registered block, empty/occupied target, `destructible` (045, `docs/server-authority.md` §3) |
| Terrain | `world/terrain/block_edit_applicator.gd` | `BlockEditApplicator.apply(command, terrain, registry)`: writes an already-validated command's effect via `VoxelTool.set_voxel()` — `network_index(block_id) + 1` for `PLACE`, `0` for `REMOVE` (046, `docs/voxel-tools.md` §12) |
| Tests | `tests/integration/test_voxel_load_save.gd` | End-to-end proof: an edit survives a real save/reload round trip through `VoxelStreamSQLite`; an untouched voxel still comes from the placeholder generator (049, `docs/voxel-tools.md` §14) |
| Saves | `core/serialization/save_version.gd` | four version numbers, load verdicts, migration steps |
| Generation | `world/generation/world_seed.gd` | `WorldSeed`: world identity as `(value, text, generation_version)` — `from_text()`/`from_value()`/`arbitrary()`/`from_header()`, `validate()` (text must re-hash to value), `display_text()`, `mismatch_reason()`/`matches()` (the client/server parity check), `rng_for(key)`, `to_header(extra)` (writes the world's own generation version over the build's constant) (056, `docs/world-generation.md` §1) |
| Generation | `world/generation/generation_version.gd` | `GenerationVersion`: the version *lifecycle* — `CURRENT`/`SUPPORTED`/`SUMMARIES`, `status()`/`status_of()` (`CURRENT_VERSION`/`LEGACY`/`RETIRED`/`FUTURE`/`INVALID`), `explain()`, `classify_header()`/`can_load_header()`/`explain_header()` (always passing the explicit supported list — never let `SaveVersion` fall back to its range), and `self_check()`, which fails the suite on a half-finished bump (057, `docs/world-generation.md` §2) |
| Generation | `world/generation/generation_grid.gd` | `GenerationGrid`: the five coordinate spaces generation asks questions at (voxel, column, chunk, chunk column, region) and the floor-correct conversions between them; `CHUNK_SIZE_VOXELS = 16` (Voxel Tools' data-block size, *not* `DEFAULT_MESH_BLOCK_SIZE`), `REGION_SIZE_VOXELS = 1024` (a 1024 × 1024 signed grid across `WorldBounds`), public `floor_div()`/`floor_mod()`, `is_region_in_world()` (058, `docs/world-generation.md` §3.1) |
| Generation | `world/generation/generation_hash.gd` | `GenerationHash.for_world(world_seed)`: positional hashing bound to one world — refuses a seed this build cannot reproduce (once, not per call), tags every coordinate space so two grids carrying the same numbers are different places, and exposes `hash_*`/`value01_*`/`chance_*`/`rng_*` per space. The generation version is deliberately *not* mixed into the hash (058, `docs/world-generation.md` §3.2-3.3) |
| Generation | `world/generation/value_noise.gd` | `ValueNoise.layer(hash, cell_size, octaves, gain, salt)`: the coherent-noise primitive every Phase D field stands on — lattice value noise over `GenerationHash`, integer voxel lattice with `floor_div`, quintic fade (never `cos`: libm is not bit-reproducible and both sides generate), octaves separated by a lattice offset, `value()` `[-1, 1]` / `value01()` `[0, 1]`, and a derived `max_slope_per_voxel()` the tests walk the real field against (060, `docs/world-generation.md` §5.2-5.4) |
| Generation | `world/generation/continentalness.gd` | `Continentalness.for_world(hash)`: the macro land/ocean field and the first thing this project generates — `at(column)` in `[0, 1]`, pinned at 8192-voxel (4096 m) cells, 4 octaves (finest = one region), gain 0.5, `SALT_CONTINENTALNESS`. Decides nothing: sea level is 080, height is 061 (060, `docs/world-generation.md` §5.5) |
| Generation | `world/generation/elevation_field.gd` | `ElevationField.for_world(hash)`: signed ground height in voxels from the datum `y = 0` — `base_for(shore) + relief_amplitude_for(shore) * relief01(column)`, range `[-96, +192]`. Relief is **additive-upward**, so the base is a genuine floor. Shore band `[0.42, 0.58]` through `ValueNoise.fade()`; relief layer cell 1024 (exactly where `Continentalness` stops), 6 octaves, `SALT_ELEVATION`. `base_at`/`relief_amplitude_at`/`relief_at` are the terms 062 and 063 recompose (061, `docs/world-generation.md` §6) |
| Generation | `world/generation/erosion_pass.gd` | `ErosionPass.for_world(hash)`: the shaping pass over `ElevationField` — `base <= at <= unshaped_at`, always. Two `[0, 1]` flattening factors on relief and none on the base: a **squared** ruggedness weight (cell 8192, 3 octaves, `SALT_RUGGEDNESS`, floored at 0.1) deciding *where* ground may be rugged, and `valley_shaped(r) = lerp(r, r², 0.5)` deciding *what shape* survives. Inherits 061's range; step bound rises to 2.627 because the valley bias steepens ridges while lowering everything (062, `docs/world-generation.md` §7) |
| Generation | `world/generation/terrace_pass.gd` | `TerracePass.for_world(hash)`: the block world — `at(column) = floor(erosion.at(column) / 8) * 8`, so every height is an exact terrace plane 8 voxels = 4 m apart, anchored to the datum. No salt, no noise layer, no change to anything below it. Keeps the family invariant in terraced form (`terraced(base_at) <= at <= erosion.at`, never more than one terrace lost) because `floor` is monotone; inherits 062's range because both ends are multiples of 8. **`max_step_per_voxel()` does not carry over** — the output is discontinuous on purpose, and `max_riser_voxels()` replaces it: `ceil(2.627 / 8) * 8` = one terrace, so every riser is a single 4 m face. `surface_y()` is the integer plane a generator fills up to; `continuous_at`/`removed_at`/`fraction_at`/`terrace_index_at` are the terms 075/084/085 read (063, `docs/world-generation.md` §8) |
| Generation | `world/generation/temperature_field.gd` | `TemperatureField.for_world(hash)`: the first climate axis — `at(column) = fade(noise01(column))` in `[0, 1]`, `0` coldest and `1` hottest, no unit. Cell 16384 voxels (8192 m), 2 octaves so the finest climate cell is exactly `Continentalness`' coarsest, gain 0.5, `SALT_TEMPERATURE`. `spread()` is the quintic used as a **redistribution**, not a blend: without it the raw layer piles 70% of the world into four middle deciles and reaches neither end, so no biome threshold would select anything. Reads **no** elevation — no lapse rate, that is 085 (064, `docs/world-generation.md` §9) |
| Generation | `world/generation/humidity_field.gd` | `HumidityField.for_world(hash)`: the second climate axis and 064's mirror — `at(column) = fade(noise01(column))` in `[0, 1]`, `0` driest and `1` wettest, no unit. Same cell, octaves and gain as `TemperatureField` (written as its constants, so the two cannot drift to different scales) and `spread()` calls its curve; the **only** difference is `SALT_HUMIDITY`. Reads **no** `Continentalness` — coastal wetness would make it the first climate axis derived from another field, and 066/074 can add it visibly on top instead. Measurably independent of temperature, ground height and continentalness (`|r| < 0.05` on every fixture world) (065, `docs/world-generation.md` §10) |
| Biomes | `world/biomes/biome_classifier.gd` | `BiomeClassifier.for_world(hash)`: which of six biomes a column is in — a six-rule decision list over `(temperature, humidity, ruggedness)`, total by construction, `at()`/`at_voxel()`/`sample_at()` and a static pure `classify()`. `IDS` is the **closed set** every catalog is checked against; `is_biome_id()` is the membership test (066, `docs/world-generation.md` §11) |
| Biomes | `world/biomes/biome_definition.gd` | `BiomeDefinition`: the per-biome record — `id` (domain `biome`), `display_name`, `debug_color`, `surface_block_id` (075), `subsurface_block_id` (076), `vegetation_density` (087, tree candidate density — 0.0 disables), `prop_density` (088, rock/prop candidate density — every shipped biome positive, mountain densest), plus `validate()`. Creature spawns 095/106–107. `debug_color` is an overlay swatch, **not** the terrain tint (067) |
| Generation | `world/generation/tree_mask.gd` | `TreeMask.for_world(hash, biomes, blocks)`: `is_tree_at(column)`/`is_tree_at_voxel(voxel)` — combines `DecorationMask` (086), `SurfaceMaterial`'s winning biome (075) and `SnowlineMaterial` (085): the biome's own `vegetation_density` picks the candidate spacing, a snow-capped column is excluded regardless of biome, `DecorationMask` picks the one eligible anchor per cell at `WorldHash.SALT_TREES` (087, `docs/world-generation.md` §26) |
| Generation | `world/generation/rock_mask.gd` | `RockMask.for_world(hash, biomes, blocks)`: `is_rock_at(column)`/`is_rock_at_voxel(voxel)` — `TreeMask` one pass over, at `WorldHash.SALT_PROPS` and `BiomeDefinition.prop_density`. **No** `SnowlineMaterial` (§27.2 — rocks sit on snow); `DecorationMask`'s water/shoreline exclusion still applies. Mountain ships the highest density rather than `0.0`, so ruggedness reads as "rockier" through the biome the classifier already produced, no second gate (§27.3) (088, `docs/world-generation.md` §27) |
| Structures | `world/structures/structure_seed.gd` | `StructureSeed`: the per-region record a structure generator (091) draws from — `region`, `anchor_column` (always inside `region`), `structure_seed` (opaque 64-bit); `rng()` forks an owned stream, `validate()` guards "anchor is inside its region" (089, `docs/world-generation.md` §28) |
| Structures | `world/structures/structure_seed_field.gd` | `StructureSeedField.for_world(hash)`: one `StructureSeed` per in-world region — `seed_at(region)` draws anchor-X, anchor-Z, then sub-seed from `GenerationHash.rng_region(region, WorldHash.SALT_STRUCTURES)` (fixed order = contract, §28.4); `null` outside `GenerationGrid.is_region_in_world()` (the reference's `INV-2`, first use); `seed_for_column`/`seed_for_voxel` resolve the region. **No** rarity gate, no terrain/biome read — presence and constraints are 090 (089, §28) |
| Biomes | `world/biomes/biome_registry.gd` | `BiomeRegistry`: typed `BiomeDefinition` catalogue over `DefinitionRegistry` — refuses an id `BiomeClassifier` cannot produce, and adds the check an open-set registry has no use for: `coverage_reason()` (the catalog holds exactly `BiomeClassifier.IDS`; `coverage_reason_for()` is the static list-taking form), `palette_reason()` (debug colours ≥ `0.25` apart), `self_check()` (067, §12.1) |
| Biomes | `world/biomes/biome_catalog.gd`, `data/biomes/*.tres` | `BiomeCatalog.load_default()`: scans `data/biomes/*.tres`, registers each, locks, then `self_check()`s the result and logs loudly if the catalog as a whole is unusable — degrades per entry like `BlockSet`, but a *missing* biome is a broken world rather than a missing block. Six records written by `tools/generators/generate_biome_catalog.gd` (thin entry + runner, brick 052's split) (067, §12.3-12.4) |
| Biomes | `world/biomes/biome_transition.gd` | `BiomeTransition.for_world(hash)`: how close a column sits to a different biome, and which one — `neighbor_at()`/`neighbor_weight_at()`/`blend_at()`. `nearest_boundary()` finds the neighbor by nudging one input at a time past each of `classify()`'s five thresholds and calling it again, rather than re-deriving its decision-list precedence. `TRANSITION_WIDTH = 0.15`, half of `BiomeClassifier.narrowest_climate_gap()`, shared across all five thresholds as a stated simplification. Never changes `BiomeClassifier.at()`'s answer; not a generation version bump (074, `docs/world-generation.md` §13) |
| Tests | `tests/fixtures/generation_fixtures.gd` | `GenerationFixtures`: the shared determinism floor every Phase D pass is tested against — four pinned named worlds, five coordinate sample lists (chosen for negatives, cell boundaries, `WorldBounds` corners), `determinism_reason()`/`seed_sensitivity_reason()` (factory-taking, so a visit-order-dependent pass cannot hide), `range_reason()`/`variation_reason()`, `signature()` for golden pinning, `self_check()` (059, `docs/world-generation.md` §4) |
| Protocol | `network/protocol/*.gd` | message kinds, direction rules, handshake compatibility |
| Authority | `network/authority/command_gate.gd` | envelope validation: owner, tick window, replay, rate limit |
| Docs | `docs/architecture.md`, `conventions.md`, `rng.md`, `persistence.md`, `protocol.md`, `server-authority.md`, `simulation-time.md`, `logging-and-errors.md`, `world-generation.md`, `adr/0001`, `adr/0002` | the contracts those files implement |
| Reference | `docs/reference/world-generation-authority.md` | who may generate world content: the reference's client-side generation was a bandwidth design, not a trust model — "the client may generate, the client never decides"; resolves `matrix-world.md` Q2 (056) |
| Reference | `docs/reference/terrain-value-noise.md` | the original's `valueNoise2D`: lattice value noise, **no seed parameter** (per-world variation was a coordinate offset, so every world is a translation of every other), a linear corner key that repeats along a diagonal, cosine interpolation through libm, and a lattice taken by truncation — mirroring the field about the origin. §9 is the divergence table 060 implements (060) |
| Reference | `docs/reference/region-coordinate-hashing.md` | how the original turned coordinates into content: a **linear** seed fed to the process-global `srand()`, first decision from the low bit of an LCG, region grid `0..1023` counted from a corner; §9 is the divergence table 058 implements (058) |
| Reference | `docs/reference/terrain-climate-blend.md` | how the original produced climate: `World_temperatureBlend`/`World_humidityBlend` blend **stored per-region values** over a nearest-site window and sample no noise for the value at all — so climate shares nothing with the height field but the site-jitter noise. Closes `terrain-base-height-field.md` `U2` and contradicts its claim 7; §8 is the divergence table 064 and 065 implement; `U1` checked by 065 and confirmed not to gate a noise-layer climate (064, 065) |
| Perf | `docs/performance-budget.md` | measured baseline per subsystem (`CLAUDE.md` §8 order) + regression thresholds + re-measure triggers; §3 filled from bricks 052-055 (voxel meshing), the rest placeholder rows for Phase L bricks 257-263 |

## Next 10 actions

1. `090` implement structure placement constraints (next task) — dep 089, DONE. `089`
   produced `StructureSeedField` (one `StructureSeed` per region: jittered anchor column +
   owned sub-seed) and deliberately left every "is a structure allowed here" question to
   this brick. Things to carry in: **(a)** the presence roll lives here, not in 089 —
   `StructureSeedField` returns a seed for *every* in-world region; 090 decides which of
   them become real; **(b)** the reference cluster to read: `matrix-world.md` §2's
   `World_featureCountRange`, `World_featureTier`, `World::findNearestFeatureCell`,
   `World::objectFalloffWeight`, `World::falloffSquared` (a per-region feature count and a
   distance-falloff weighting — MEDIUM confidence); **(c)** the terrain reads 090 may now
   make that 089 refused — `TerracePass`/`ErosionPass.ruggedness_at()` for slope,
   `ShorelineMaterial`/`OceanPass` for water, `BiomeClassifier`/`SurfaceMaterial` for biome
   suitability, and spacing between one region's anchor and its neighbours'; **(d)** still
   not a generation version bump until 091's `VoxelGenerator` writes a `VoxelBuffer`
   (`docs/world-generation.md` §28.6, §14.4). The throwaway-probe habit still applies for
   any swept fixture columns: a `tests/unit/test_zzz_scratch_*.gd` file, run with
   `--test-file=` (note: `-- --test-file=`, args after `--`), deleted before the brick
   lands. Still open and carried from Phase C: no `.tscn` exists, no player/camera — a
   Phase F question. `docs/performance-budget.md` §3's benchmark is re-run against the real
   generator once Phase D lands (feeds 257–258); generation's own row there stays empty
   until something is expensive enough to measure.
1b. Git, **resolved at 067**: `origin` is `github.com/KyamiDEV/cube-world-godot` and the
   full per-brick history is intact from brick 001 — the earlier "history is gone"
   conclusion was drawn from a working copy that had lost its `.git`, without checking
   the remote. The throwaway single-commit baseline was discarded and 065–067 replayed
   onto the remote's brick-064 head. Push each brick as it lands; fetch `origin` before
   ever concluding history is missing.
2. Before shipping any exported (non-editor) build: revisit `blocky_library_builder.gd`
   (037)'s `Image.load()`-based texture loading — brick 038 surfaced an engine warning
   ("will not work on export") once real imported `res://` PNGs existed to trigger it.
   Not blocking for editor/headless dev and testing; see Known risks below.
3. Before `096`–`101` (streaming) and `235`/`236`/`248` (session + edit replication): apply `docs/reference/world-generation-authority.md`'s rule — client streaming may drive **local** generation for presentation, but the server keeps its own logical interest and its own generation, and the handshake must refuse a session on `WorldSeed.mismatch_reason()`. (`matrix-world.md` Q2 itself is now **resolved** by brick 056 — client-side generation was a bandwidth design, not a trust model; `matrix-ai.md`'s near-identical AI-tick bodies in both binaries are consistent with the same symmetric-build pattern.)
4. Before `112`/`116`/`128`/`243`: resolve Q1 from `matrix-entity.md` (cite the matrix for creature/player locomotion, or add a dedicated brick) — `matrix-ai.md`'s nav/locomotion-primitives row cross-refs the same question.
5. Before `164`/`165`: resolve Q2 from `matrix-items.md` (contradictory equipment slot count, 16 vs 12, neither VERIFIED). Before `172`/`173`: Q3 (unread "rng affix" roll in `GameController_onItemPickup`). (`matrix-items.md` Q1 / `matrix-ui.md` Q2 — `GameController` scoping — is now **resolved**, see brick 028 above: no new matrix or brick.)
6. Before `177`/`178`: resolve Q1 from `matrix-ai.md` (does the `BehaviorNode` tree need both a true Sequence and a first-success Selector, given `SequentialBehavior` observably behaves as the latter?). Before `190`/`216`: resolve Q2 from `matrix-ai.md` (unconfirmed world-clock field gating `SpawnLocationBehavior`'s location switch).
7. Before `141`–`144`: resolve `matrix-combat.md` Q2 (unexplained `2^a*2^b` formula shape — may not need resolving under clean-room policy). Before `138`/`139`/`192`: Q3 (attack-selection decision-tree bodies unread). (`matrix-combat.md` Q1 is now **resolved** by brick 028 — quest-script trigger data, not a network format; bricks 249/251 design combat-event replication fresh, with no reference wire format to draw on.)
8. Before `206`–`209`: resolve Q1 from `matrix-quests.md` (the unrecovered 11-counter quest-progress score behind `computeQuestScore` — likely resolvable by design decision alone). Q2 (`check_quest_id_match`'s `event type 0x19`) is unaffected by brick 028's Q1 resolution — still open, still relevant before `251`.
9. Before phase J/K UI bricks (224–231) start: resolve Q1 from `matrix-ui.md` (character creation, main menu/title screen, and merchant/trade dialog have no owning backlog brick yet — a scoping pass may need to insert new bricks).
10. Before `235`/`236`: optionally resolve Q3 from `matrix-client-server.md` (no connect/login/handshake function was found in either binary — a targeted raw read of `server/net/Server.cpp`, only if reference corroboration is wanted; not required by clean-room policy).
11. Update this file after every brick.

## Working set

At session start read `CLAUDE.md`, then this file, then only the active backlog row, its
dependency rows, and the files the task names. For a brick appearing in
`docs/reference/traceability.md` §2, also read the cited matrix section before designing
against it. For 021+ also read `docs/reference/README.md` and `matrix-index.md` before
opening the reference tree.

## Human test state

- Last human playtest: `NOT STARTED`. Nothing visual exists yet — the main scene prints a
  boot report to a label. First `HUMAN_REQUIRED` brick is `091`.
- Last reported visual/gameplay issues: `NONE`

## Technical notes worth keeping

- **Class cache.** Headless `--script` runs read `.godot/global_script_class_cache.cfg`
  and never refresh it, so a new `class_name` is invisible until `godot --headless
  --import` runs. `check.ps1`/`test.ps1` do it; a raw `godot --script` does not.
- **Parse checking.** `load()` returns a resource even for a broken script. Validity is
  decided by `can_instantiate()` (runner) or a detached `GDScript` parse
  (`check_scripts.gd`, which renames the `class_name` in its copy because the real file
  is already registered globally).
- **A test with zero assertions fails.** A GDScript runtime error unwinds the method
  without stopping the runner, so that is the only signal the body aborted.
- **Warnings are errors** for integer division, narrowing conversion and shadowed
  variables (`project.godot [debug]`). Intentional cases need `@warning_ignore*`.
  Watch for: `_init(domain)` shadowing a `domain()` method; `var x := something_untyped`.
- **PowerShell 5.1** wraps native stderr in ErrorRecords; `Invoke-Godot` relaxes
  `ErrorActionPreference` around the call only.
- **GDScript int64** wraps two's-complement as needed, but `>>` sign-extends — use the
  masked logical shift in `DeterministicRng`. Literal negative operands in shifts are a
  parse error; only runtime values work.
- `VoxelGeneratorMultipassCB` exists in 1.7 — the route for generation needing neighbour
  context (structures/villages, bricks 089–093).
- `VoxelTerrainMultiplayerSynchronizer` exists but replicates terrain blocks only; it is
  not a gameplay authority mechanism. Evaluated at brick 050 (`docs/voxel-tools.md` §15):
  the 043–046 raycast/command/validate/apply pipeline is already the real edit-authority
  path, so wiring the synchronizer stays deferred to Phase K, where a real multiplayer
  scene/peer set will exist to wire it into.
- **Voxel value = `BlockRegistry.network_index(id) + 1`; voxel `0` is air.**
  `blocky_library_builder.gd` (037) inserts air at library index 0 and appends blocks in
  `registry.ids()` order — `network_index()` itself is unchanged (still 0-based, used by
  packets/saves too). Terrain/edit code (039+, 044–046) must apply the `+1`.
- **`Image.load(path)` reads a raw PNG/etc straight off disk**, bypassing Godot's
  `res://` import pipeline entirely (no `.import` file needed) — this is how
  `blocky_library_builder.gd` and its test both load/generate images at runtime. Different
  from `load(path)` / `ResourceLoader`, which require an imported `Texture2D`.
- **`VoxelMesherBlocky` always bakes ambient occlusion into cube-edge vertex colors**;
  a model's material only needs `vertex_color_use_as_albedo = true` (Godot's own
  `BaseMaterial3D` property) to display it — confirmed against `godot_voxel`'s
  `doc/source/blocky_terrain.md`, brick 040. No mesher-level AO property exists to set;
  it is unconditional. Resolves `matrix-world.md` Q1 — no custom AO shader is needed.
- **`VoxelViewer` is a `Node3D`, not a `VoxelTerrain` property.** Voxel Tools streams
  data around whatever `VoxelViewer`s exist in the scene tree; `VoxelTerrain.
  max_view_distance` only clamps what a `VoxelViewer` may request — confirmed against
  upstream `VoxelViewer.xml`/`VoxelTerrain.xml`, brick 042. `voxel_terrain_builder.gd`'s
  `DEFAULT_VIEW_DISTANCE` constant keeps both properties in sync.
- **`VoxelNode` (base of `VoxelTerrain`) owns `generator`/`stream`/`mesher`**; `VoxelTerrain`
  itself adds `bounds`, `generate_collisions`, `collision_layer`/`collision_mask`,
  `max_view_distance`, `mesh_block_size` (16 or 32 only). An unassigned `stream` makes the
  whole volume regenerate from `generator` — confirmed against upstream
  `VoxelNode.xml`/`VoxelTerrain.xml`, brick 039. `VoxelGeneratorFlat.channel` defaults to
  `CHANNEL_SDF` (1), **not** `CHANNEL_TYPE` (0) — a blocky placeholder generator must set
  `channel` explicitly or it silently produces SDF data a blocky mesher can't read.
- **The `godot_voxel` reference repo's git tag is `v1.7`, not `v1.7.0`** (confirmed via
  its `tags` API, brick 048) — `raw.githubusercontent.com/.../v1.7.0/...` 404s.
  `docs/environment.md`'s verified `1.7.0` *version string* is unaffected; only the tag
  name used to fetch `doc/classes/*.xml` differs.
- **`VoxelTerrain.bounds` is `AABB`, in voxel coordinates**, default effectively
  unbounded (`AABB(-536870900, ..., 1073741800, ...)`) — confirmed against upstream
  `VoxelTerrain.xml` (v1.7 tag), brick 045. `block_edit_validator.gd` (045) reads it
  directly for the layer-2 "in bounds" check rather than inventing a second bounds
  concept. As of brick 050, `voxel_terrain_builder.gd` sets a real value:
  `WorldBounds.aabb()` (`world/terrain/world_bounds.gd`, `+-524288` voxels horizontal,
  `+-2048` vertical). `bounds` itself only clips generator output, not edits — confirmed
  against the same doc page; 045's own check remains the actual edit-authority
  enforcement (`docs/voxel-tools.md` §15).
- **`doc/classes/VoxelTerrain.xml`'s `get_statistics()` entry over-documents its return
  value** — it lists 9 keys, but the actual C++ source
  (`terrain/fixed_lod/voxel_terrain.cpp`'s `_b_get_statistics()`, `godot_voxel` reference
  repo, tag `v1.7`) only ever sets 7; `time_process_update_responses` and
  `remaining_main_thread_blocks` are documented but never written, confirmed both by
  reading the source and empirically (brick 051, `docs/voxel-tools.md` §16). When a doc
  page and the actual behavior disagree, prefer reading the source directly over trusting
  the XML doc — this project's `VoxelTerrainMetrics.KEY_*` constants
  (`world/terrain/voxel_terrain_metrics.gd`) already reflect only the real 7.
- **A `--script` entry file needs the thin-entry/runner split whenever it touches project
  classes** — brick 067 hit this again with `generate_biome_catalog.gd`, which cannot
  statically reference `BiomeClassifier`/`BiomeRegistry`/`BiomeCatalog`.
  `generate_block_set.gd` is a single file only because `BlockDefinition` happens to touch
  nothing; do not copy it as the pattern. Also: **`Color8()` is a call, not a constant
  expression**, so a colour table cannot be a `const` — use a static function.
- **A file passed to `--script` is compiled before project autoloads are registered as
  global identifiers.** A script that statically references a `Log`-touching project class
  at its top level (`VoxelTerrainBuilder`, `BlockSet`, `VoxelTerrainMetrics` all call `Log`
  internally) fails to compile with `Identifier not found: Log` when it *is* the `--script`
  entry file — confirmed empirically, brick 052. `tests/run_tests.gd` avoids this by only
  statically referencing `TestCase` (no `Log` dependency) and reaching every real test file
  through a runtime `load()` call instead. Any future `tools/**/*.gd` entry script needs
  the same split: a thin entry file with no such static references, plus a `load()`ed
  runner that does the real work (`tools/benchmarks/benchmark_mesh_block_size.gd` +
  `mesh_block_size_benchmark_runner.gd`, `docs/voxel-tools.md` §17).
- **`VoxelTerrain.get_statistics()`'s `updated_blocks` (and `time_request_blocks_to_update`)
  read as "this specific tick", not a running total.** Polling `updated_blocks` for a
  stable plateau can report "settled" while the value sits at a constant `0` for an entire
  run that still completed real work — the update burst can land between two polls and
  never be sampled (brick 052). Use `VoxelEngine.get_stats()`'s `memory_pools.block_count`
  (monotonic while streaming) plus every `tasks` queue reading `0` instead, for a direct
  "no more in-flight background work" signal.

## Known risks

- `blocky_library_builder.gd` (037) loads block face textures with `Image.load()` on a
  `res://` path. That bypasses the import pipeline on purpose for runtime-generated
  textures, but now that brick 038 committed real, imported `res://` PNGs
  (`assets/textures/blocks/*.png`), Godot warns `"Loaded resource as image file, this
  will not work on export"`. Harmless for editor/headless dev and the test suite (which
  is all that exists today), but must be resolved (e.g. load as `Texture2D` via
  `ResourceLoader`/`load()` and read `get_image()`, falling back to `Image.load()` only
  for non-project paths) before any exported/packaged build — flagged, not fixed, to keep
  038 scoped to "create a block set".
- Decompiled behavior can be ambiguous.
- Generation determinism can regress accidentally.
- Networking must be designed before late-stage multiplayer integration.
- Heavy voxel generation should not become a large thread-unsafe GDScript loop.
- Visual similarity is not proof of behavioral parity.
- The engine binary is machine-local; only its fingerprint is committed.

## Session handoff rule

At the end of every task, keep this file to: current phase/milestone/task, completed
brick IDs, next 3–10 actions, blockers, changed files, test result, human-test result,
and only important technical notes. Do not paste large logs here.
