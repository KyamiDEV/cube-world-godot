class_name ProtocolVersion
extends RefCounted
## Wire compatibility between a client and a server (backlog brick 018).
##
## The protocol version is **not** the save version. A save is read once by one process
## that can migrate it; a connection is a live agreement between two processes that
## cannot migrate each other. So the rule is stricter: versions must match exactly.
##
## Matching versions is necessary but not sufficient. Two peers also have to agree on
## content, because IDs travel as registry indices (`docs/ids-and-registries.md` §2): if
## the server's index 7 is a steel sword and the client's is a healing potion, every
## packet parses cleanly and means the wrong thing. The content hash catches that at
## connect time instead of during play.
##
## Static-only: never instantiate.

## Bump on **any** change to message layout, field order, kind numbering, or the meaning
## of an existing field. There is no partial compatibility: a peer either speaks this
## protocol or it does not.
const PROTOCOL_VERSION := 1

## Rejection reasons, reported to the peer so it can tell the player what to do.
enum Rejection {
	NONE,
	## Version numbers differ; one side must update.
	VERSION_MISMATCH,
	## Versions match but the content catalogues do not.
	CONTENT_MISMATCH,
	## The handshake was missing fields or had wrong types.
	MALFORMED,
}

const REQUIRED_FIELDS: PackedStringArray = ["protocol_version", "content_hash"]


## Handshake payload this build sends. `content_hash` is the combined fingerprint of
## every locked registry (`DefinitionRegistry.content_hash()`).
static func make_handshake(content_hash: int, extra: Dictionary = {}) -> Dictionary:
	var handshake := {
		"protocol_version": PROTOCOL_VERSION,
		"content_hash": content_hash,
	}
	for key in extra:
		handshake[key] = extra[key]
	return handshake


## Checks a peer's handshake against this build. `NONE` means the connection may proceed.
static func check(handshake: Dictionary, local_content_hash: int) -> Rejection:
	for field in REQUIRED_FIELDS:
		if not handshake.has(field) or typeof(handshake[field]) != TYPE_INT:
			return Rejection.MALFORMED

	if int(handshake["protocol_version"]) != PROTOCOL_VERSION:
		return Rejection.VERSION_MISMATCH
	if int(handshake["content_hash"]) != local_content_hash:
		return Rejection.CONTENT_MISMATCH
	return Rejection.NONE


static func accepts(handshake: Dictionary, local_content_hash: int) -> bool:
	return check(handshake, local_content_hash) == Rejection.NONE


## Text for the log and for the player. "Connection refused" with no reason produces a
## bug report that cannot be acted on.
static func explain(handshake: Dictionary, local_content_hash: int) -> String:
	match check(handshake, local_content_hash):
		Rejection.NONE:
			return "protocol and content match"
		Rejection.VERSION_MISMATCH:
			return "protocol version %s does not match this build's %d" % [
					str(handshake.get("protocol_version", "?")), PROTOCOL_VERSION]
		Rejection.CONTENT_MISMATCH:
			return "content does not match: the client and server have different definitions loaded"
		_:
			return "handshake is malformed"


## Combines several registry fingerprints into the one hash exchanged at connect time.
## Order-independent, so the two peers need not agree on registry ordering — only on
## content.
static func combine_content_hashes(hashes: PackedInt64Array) -> int:
	var combined := 0
	for value in hashes:
		combined ^= value
	return combined
