# Stable IDs and registries

Brick 016. Implementations: `core/ids/stable_id.gd`, `core/ids/definition_registry.gd`.
Grammar and domain list: `docs/conventions.md` §5.

## 1. Why an ID and not a name or an index

An ID is written into save files, network packets and logs, so whatever keys content has
to survive everything else changing:

| Candidate key | Fails because |
|---|---|
| Display name | localised, and edited for feel until the day of release |
| Array index | shifts the moment content is inserted or removed; a save then points at the wrong thing, silently |
| Resource path | couples content identity to the file layout, so a refactor breaks saves |
| Runtime object | cannot cross a socket or a save file at all |

So: `item.sword.iron`. Lower-case, dotted, permanent.

**An ID is never renamed.** Renaming one invalidates every save and every client that
still holds it. Deprecate it with an alias instead (§3).

## 2. The registry

One `DefinitionRegistry` per domain — blocks, items, creatures, biomes, quests. It owns
four things that would otherwise be reinvented, slightly differently, in each catalogue.

### Validation

Only well-formed IDs of the registry's own domain get in. A rejection is **logged with
its reason and returns false**, so a bad data file costs one missing entry rather than a
crashed load. `StableId.validate()` returns the reason as text: "invalid id" alone tells
a content author nothing.

### Immutability after load

```gdscript
registry.register("item.sword.iron", definition)
...
registry.lock()      # content is now closed
```

A catalogue that can change mid-session cannot be replicated or saved coherently: two
clients would disagree about what index 7 means. `lock()` closes it; registering
afterwards is refused and logged as an error.

`lock()` also returns false when an alias points at nothing — that check has to wait
until every definition is in, because data files load in arbitrary order.

### Aliases

```gdscript
registry.add_alias("item.sword.plain", "item.sword.iron")
```

Old saves and older clients keep resolving. Chains (`A -> B -> C`) are followed;
loops terminate rather than hang. An alias may not shadow a live definition, and a live
definition may not claim a name already used as an alias.

### Network indices

IDs are strings; the wire needs small integers. `lock()` assigns an index to every ID
**in sorted ID order** — not insertion order, which depends on file system enumeration.
Two peers that loaded the same content therefore agree on every index without exchanging
a table.

```gdscript
var index := registry.network_index("item.sword.iron")   # -1 before lock()
var id := registry.id_from_network_index(index)          # "" when out of range
```

`id_from_network_index` returns an empty string for an out-of-range index: a packet from
an incompatible peer must not be able to index out of bounds.

`content_hash()` is an order-independent fingerprint of the whole ID-to-index mapping.
Peers compare it at connection time; equal hashes mean their indices agree, and a
mismatch is a content-version problem to report rather than a desync to discover later.

## 3. Deprecating content

1. Keep the definition and add the new one alongside it, or
2. remove the definition and add an alias from the old ID to its replacement.

Never reuse an ID for different content. A save file holding `item.sword.iron` from last
month must not silently become a different sword.

## 4. Iteration order

`ids()` and `ids_under()` return **sorted** results. Anything derived from iteration
order — network indices, generation order, a UI list — must not depend on which file the
loader happened to read first. Sorting is the cheapest way to make that impossible.

`ids_under("item.sword")` is segment-aware: `item.swordfish` is not a sword.

## 5. What a registry does not do

- It does not load files. A loader parses data and calls `register()`; the registry
  neither knows nor cares about file formats.
- It does not validate the *definition*, only the ID. Each domain's definition type
  checks its own fields (bricks 031+, 107).
- It does not hold runtime state. Definitions are immutable descriptions; per-instance
  state lives in `*State` objects (`docs/architecture.md` §1).
