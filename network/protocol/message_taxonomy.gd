class_name MessageTaxonomy
extends RefCounted
## The kinds of message the protocol carries, and the rules about who may send each
## (backlog brick 018).
##
## Every message belongs to exactly one kind. The kind decides three things a
## networking layer otherwise decides ad hoc, differently each time:
##
## 1. **Direction** — who is allowed to send it. A server that accepts an `EVENT` from a
##    client has handed the client authority over what happened, which is the whole
##    class of "the client says it killed the boss" exploit.
## 2. **Delivery** — reliable/ordered or unreliable. Snapshots are unreliable because a
##    late one is worse than a lost one; events are reliable because a lost one is a
##    story the client never hears.
## 3. **Validation** — whether the payload is untrusted input that must be re-checked
##    against authoritative state before anything is applied.
##
## Taxonomy and rationale: `docs/protocol.md`.
##
## Static-only: never instantiate.

enum Kind {
	## Client -> server intent: "I want to move / attack / use this". Untrusted, always
	## validated, may be rejected. Carries the tick it was produced for.
	COMMAND,
	## Server -> client: something that already happened and is authoritative. Reliable,
	## because a missed event is a hole in the client's story of the world.
	EVENT,
	## Server -> client: full authoritative state for the receiver's interest area, at a
	## tick. Unreliable: a newer one supersedes it.
	SNAPSHOT,
	## Server -> client: change since an acknowledged snapshot. Unreliable but
	## sequence-checked; a gap forces a fresh snapshot rather than a guess.
	DELTA,
	## Either direction, connection setup: versions, content hashes, identity.
	HANDSHAKE,
	## Either direction, connection management: ping, ack, disconnect reason.
	CONTROL,
}

enum Direction {
	CLIENT_TO_SERVER,
	SERVER_TO_CLIENT,
}

enum Delivery {
	## Arrives, and in order. Costs latency on loss.
	RELIABLE_ORDERED,
	## Arrives, order not guaranteed.
	RELIABLE_UNORDERED,
	## May be lost. Never used for anything that is not superseded by the next one.
	UNRELIABLE,
}

## Kinds a client is allowed to send. Anything else arriving from a client is either a
## bug or an attack, and is dropped and logged — never applied.
const CLIENT_SENDABLE: Array[Kind] = [Kind.COMMAND, Kind.HANDSHAKE, Kind.CONTROL]

## Kinds a server is allowed to send.
const SERVER_SENDABLE: Array[Kind] = [
	Kind.EVENT, Kind.SNAPSHOT, Kind.DELTA, Kind.HANDSHAKE, Kind.CONTROL,
]


## True when `kind` may legitimately travel in `direction`.
static func is_allowed(kind: Kind, direction: Direction) -> bool:
	if direction == Direction.CLIENT_TO_SERVER:
		return CLIENT_SENDABLE.has(kind)
	return SERVER_SENDABLE.has(kind)


## True when the payload came from a client and must be validated against authoritative
## state before anything is applied. This is the single most important bit in the
## protocol: it is what separates intent from truth.
static func is_untrusted(kind: Kind, direction: Direction) -> bool:
	return direction == Direction.CLIENT_TO_SERVER


static func delivery_for(kind: Kind) -> Delivery:
	match kind:
		Kind.COMMAND:
			# A dropped command is an input the player made and the world ignored.
			return Delivery.RELIABLE_ORDERED
		Kind.EVENT:
			return Delivery.RELIABLE_ORDERED
		Kind.SNAPSHOT:
			# Resending a stale snapshot would fight the newer one that already arrived.
			return Delivery.UNRELIABLE
		Kind.DELTA:
			return Delivery.UNRELIABLE
		Kind.HANDSHAKE:
			return Delivery.RELIABLE_ORDERED
		_:
			return Delivery.RELIABLE_UNORDERED


## True when losing one message of this kind is recoverable without special handling,
## because a later message supersedes it.
static func is_superseded_by_later(kind: Kind) -> bool:
	return kind == Kind.SNAPSHOT or kind == Kind.DELTA


## True when the message must carry the simulation tick it belongs to. Anything the
## server has to place in time — or re-evaluate a client's claim against — needs one
## (`docs/simulation-time.md`).
static func requires_tick(kind: Kind) -> bool:
	return kind == Kind.COMMAND or kind == Kind.EVENT \
			or kind == Kind.SNAPSHOT or kind == Kind.DELTA


static func kind_name(kind: Kind) -> String:
	return Kind.keys()[kind]


static func direction_name(direction: Direction) -> String:
	return Direction.keys()[direction]
