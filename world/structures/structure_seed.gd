class_name StructureSeed
extends RefCounted
## The deterministic seed one region reserves for a structure (backlog brick 089).
##
## This is not a structure, and not a decision that a structure exists here — it is the
## reproducible *input* a later structure generator (091) draws everything else from, plus
## the one thing that input has to fix before any constraint can be checked: **where** in
## the region the candidate sits. `StructureSeedField` (`world/structures/
## structure_seed_field.gd`) produces exactly one of these per in-world region, as a pure,
## order-free function of `(world seed, region coordinates)`.
##
## | Field | What reads it |
## |---|---|
## | `region` | the caller, to know which region grid cell this belongs to |
## | `anchor_column` | brick 090, which checks whether a structure may actually stand at this column (slope, water, biome, spacing) — and 091, which builds outward from it |
## | `structure_seed` | brick 091, as the seed of its **own** owned stream (`rng()`), so a generator drawing a different number of values can never shift a neighbouring region's result (`docs/rng.md` §5) |
##
## ```gdscript
## var field := StructureSeedField.for_world(GenerationHash.for_world(world_seed))
## var candidate := field.seed_at(Vector2i(3, -5))
## if candidate != null and _constraints_allow(candidate.anchor_column):   # brick 090
##     _generate_structure(candidate.anchor_column, candidate.rng())        # brick 091
## ```
##
## ## Why the anchor is here and not in brick 090
##
## The region grid is 1024 voxels across (`GenerationGrid.REGION_SIZE_VOXELS`); a structure
## anchored to the region's own corner would tile the world with a visible 512 m lattice.
## The jitter that breaks that lattice is a property of the seed — it is drawn from the
## region's stream, it is deterministic, and it must be fixed *before* brick 090 can ask
## "is the ground at the anchor buildable". So the anchor column is selected here; whether
## anything is placed there is 090's entire job.
##
## ## Reference
##
## `docs/reference/region-coordinate-hashing.md`: the original seeded a region's content
## with `srand(regX + 0x108a + regZ * 0x400 + worldSeed * 3)` and drew from the process
## global `rand()`. The shape kept — one reproducible seed per region cell, on a 1024×1024
## grid — is in `StructureSeedField`; the linear seed and the global stream are the note's
## §9 divergences, already resolved by `GenerationHash.rng_region()` (058).
##
## Contract: `docs/world-generation.md` §28.

## The region grid cell this seed belongs to, in `GenerationGrid` region coordinates.
var region: Vector2i

## The world column the structure candidate is anchored at — always inside `region`
## (`GenerationGrid.region_origin(region)` plus a per-axis offset in
## `0 .. GenerationGrid.REGION_SIZE_VOXELS - 1`).
var anchor_column: Vector2i

## The 64-bit seed a structure generator (091) builds its own `DeterministicRng` from.
## Treat it as opaque bits: it is the region stream's third draw, not the region hash and
## not either anchor offset, so a generator that consumes it cannot disturb this region's
## anchor or any other region.
var structure_seed: int


func _init(p_region: Vector2i, p_anchor_column: Vector2i, p_structure_seed: int) -> void:
	region = p_region
	anchor_column = p_anchor_column
	structure_seed = p_structure_seed


## A fresh stream owned by this structure candidate, for a generator (091) that needs a
## sequence of related rolls (kind, then rotation, then size...). One stream, one owner
## (`docs/rng.md` §5): the caller takes its own rather than sharing this record's.
func rng() -> DeterministicRng:
	return DeterministicRng.from_seed(structure_seed)


## Empty string when this record is internally coherent, otherwise the reason — the
## project's `validate()` convention. Checks the one invariant a consumer relies on: the
## anchor column actually lies inside the region it is attributed to.
func validate() -> String:
	if not GenerationGrid.is_region_in_world(region):
		return "region %s is outside the region grid" % region
	if GenerationGrid.column_to_region(anchor_column) != region:
		return "anchor column %s is not inside region %s" % [anchor_column, region]
	return ""


func _to_string() -> String:
	return "StructureSeed(region=%s anchor=%s seed=%d)" % [region, anchor_column, structure_seed]
