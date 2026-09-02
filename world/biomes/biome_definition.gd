class_name BiomeDefinition
extends Resource
## Immutable per-biome record (backlog brick 067).
##
## One resource describes one biome *kind* — `biome.grassland`, `biome.desert` — never one
## place. `BiomeClassifier` (066) already answers "which biome is this column in?"; this is
## the record behind that answer, and `BiomeCatalog` (below) is the six of them.
##
## The classifier owns the **set**: `BiomeClassifier.IDS` is closed in code, and a catalog
## is checked against it rather than defining it (`docs/world-generation.md` §12.1). This
## file owns the **shape** of one entry.
##
## ## Three fields, and the argument for stopping there
##
## Almost everything one wants to write on a biome belongs to a later brick, and a field
## nothing fills is worse than a record that grows:
##
## | Tempting field | Owner |
## |---|---|
## | surface block, subsurface layers, depth | 075, 076 |
## | trees, grass, scatter density | 086–088 |
## | creature spawn tables | 095, 106–107 |
## | water, shoreline, snowline, altitude bands | 080, 085 |
## | transition width / blend weights | 074 |
## | terrain tint, vegetation colour | Phase J, and see the note on `debug_color` |
##
## What is left is what a catalog can actually fill today, for all six entries, with
## nothing invented: an id, a name for a human, and a colour to tell one from another.
##
## ## The reference has no catalog at all
##
## Worth recording, because it is a **divergence** rather than a gap: the original has no
## biome enum, table or record. Its notion of a biome is a *continuous colour* —
## `Terrain_computeBiomeColor` blends constants against temperature/humidity/height noise
## into terrain and vegetation RGBA — plus a content-placement routine
## (`WorldInfo_generateBiomeContent`, spawns/features/decoration). Nothing names a biome and
## nothing looks one up. We diverge deliberately: a discrete, addressable id is what a save
## file, a quest condition, a spawn table and a debug log all need (`CLAUDE.md` §9), and it
## is what 066 already committed to. `docs/world-generation.md` §12.5.

## Stable content ID, domain "biome" — e.g. "biome.grassland". Written into save files,
## logs and (as a network index) packets, so it is permanent
## (`docs/ids-and-registries.md`). Must be one `BiomeClassifier` can produce; that half is
## checked by `BiomeRegistry`, which is the layer that knows about the classifier.
@export var id: String = ""

## Editor/tooling/UI display only. Never a key (`docs/conventions.md` §5).
@export var display_name: String = ""

## Flat colour identifying this biome in a **debug** view — a biome-map overlay, a
## generation probe, a screenshot of the partition. Chosen for telling six things apart,
## not for looking like ground.
##
## Explicitly **not** the terrain or vegetation tint. That is a shading decision made from
## the surface material (075) and the renderer (Phase J), and it is the one place the
## original's own `Terrain_computeBiomeColor` would be relevant — a continuous blend, not a
## per-biome constant. Naming this `debug_color` is what keeps the two from being confused
## the first time something needs to tint a chunk.
##
## Filled for all six baseline biomes, and `BiomeRegistry.palette_reason()` requires them to
## stay tellable apart: a debug map on which two biomes look identical is not a debug map.
@export var debug_color: Color = Color.MAGENTA


## Returns an empty string when well-formed, otherwise a human-readable reason — same
## convention as `StableId.validate()` and `BlockDefinition.validate()`, so a bad data file
## logs something a content author can act on.
##
## Grammar and domain only: whether the id is one the *classifier* can produce is
## `BiomeRegistry`'s check, because this schema is deliberately independent of the
## partition it describes.
func validate() -> String:
	var id_problem := StableId.validate(id)
	if not id_problem.is_empty():
		return id_problem
	if StableId.domain_of(id) != "biome":
		return "biome definition id must be in the 'biome' domain, got '%s'" % id
	if display_name.is_empty():
		return "display_name is empty"
	if not is_equal_approx(debug_color.a, 1.0):
		return "debug_color must be opaque, alpha is %s" % debug_color.a
	return ""


func is_valid() -> bool:
	return validate().is_empty()
