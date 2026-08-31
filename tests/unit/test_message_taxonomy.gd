extends TestCase
## Covers network/protocol/message_taxonomy.gd (brick 018).
##
## These are authority assertions, not formatting ones: the direction rules are what
## stop a client from telling the server what happened.


func test_a_client_may_only_send_intent_and_connection_traffic() -> void:
	var to_server := MessageTaxonomy.Direction.CLIENT_TO_SERVER
	assert_true(MessageTaxonomy.is_allowed(MessageTaxonomy.Kind.COMMAND, to_server))
	assert_true(MessageTaxonomy.is_allowed(MessageTaxonomy.Kind.HANDSHAKE, to_server))
	assert_true(MessageTaxonomy.is_allowed(MessageTaxonomy.Kind.CONTROL, to_server))


func test_a_client_may_never_send_authoritative_kinds() -> void:
	# The exploit this forbids: "the client says the boss died".
	var to_server := MessageTaxonomy.Direction.CLIENT_TO_SERVER
	assert_false(MessageTaxonomy.is_allowed(MessageTaxonomy.Kind.EVENT, to_server),
			"a client cannot declare that something happened")
	assert_false(MessageTaxonomy.is_allowed(MessageTaxonomy.Kind.SNAPSHOT, to_server),
			"a client cannot declare world state")
	assert_false(MessageTaxonomy.is_allowed(MessageTaxonomy.Kind.DELTA, to_server))


func test_a_server_never_sends_commands() -> void:
	# The server does not ask the client for permission; it tells it what happened.
	assert_false(MessageTaxonomy.is_allowed(MessageTaxonomy.Kind.COMMAND,
			MessageTaxonomy.Direction.SERVER_TO_CLIENT))


func test_a_server_sends_state_and_events() -> void:
	var to_client := MessageTaxonomy.Direction.SERVER_TO_CLIENT
	for kind in [MessageTaxonomy.Kind.EVENT, MessageTaxonomy.Kind.SNAPSHOT,
			MessageTaxonomy.Kind.DELTA, MessageTaxonomy.Kind.HANDSHAKE,
			MessageTaxonomy.Kind.CONTROL]:
		assert_true(MessageTaxonomy.is_allowed(kind, to_client),
				"server may send %s" % MessageTaxonomy.kind_name(kind))


func test_every_kind_has_a_direction_rule() -> void:
	# A kind allowed in neither direction is dead; one allowed in both without reason is
	# an authority hole. Each kind is checked explicitly above; this guards additions.
	for kind in MessageTaxonomy.Kind.values():
		var allowed_anywhere := MessageTaxonomy.is_allowed(
				kind, MessageTaxonomy.Direction.CLIENT_TO_SERVER) \
				or MessageTaxonomy.is_allowed(kind, MessageTaxonomy.Direction.SERVER_TO_CLIENT)
		assert_true(allowed_anywhere,
				"%s is sendable by someone" % MessageTaxonomy.kind_name(kind))


func test_everything_from_a_client_is_untrusted() -> void:
	for kind in MessageTaxonomy.Kind.values():
		assert_true(MessageTaxonomy.is_untrusted(kind,
				MessageTaxonomy.Direction.CLIENT_TO_SERVER),
				"%s from a client is untrusted" % MessageTaxonomy.kind_name(kind))
		assert_false(MessageTaxonomy.is_untrusted(kind,
				MessageTaxonomy.Direction.SERVER_TO_CLIENT),
				"the server is the authority for %s" % MessageTaxonomy.kind_name(kind))


func test_state_kinds_are_unreliable_because_a_newer_one_supersedes_them() -> void:
	assert_eq(MessageTaxonomy.delivery_for(MessageTaxonomy.Kind.SNAPSHOT),
			MessageTaxonomy.Delivery.UNRELIABLE)
	assert_eq(MessageTaxonomy.delivery_for(MessageTaxonomy.Kind.DELTA),
			MessageTaxonomy.Delivery.UNRELIABLE)
	assert_true(MessageTaxonomy.is_superseded_by_later(MessageTaxonomy.Kind.SNAPSHOT))
	assert_true(MessageTaxonomy.is_superseded_by_later(MessageTaxonomy.Kind.DELTA))


func test_commands_and_events_are_reliable_and_ordered() -> void:
	# A dropped command is player input the world ignored; a dropped event is a hole in
	# the client's story. Neither is superseded by anything later.
	assert_eq(MessageTaxonomy.delivery_for(MessageTaxonomy.Kind.COMMAND),
			MessageTaxonomy.Delivery.RELIABLE_ORDERED)
	assert_eq(MessageTaxonomy.delivery_for(MessageTaxonomy.Kind.EVENT),
			MessageTaxonomy.Delivery.RELIABLE_ORDERED)
	assert_false(MessageTaxonomy.is_superseded_by_later(MessageTaxonomy.Kind.COMMAND))
	assert_false(MessageTaxonomy.is_superseded_by_later(MessageTaxonomy.Kind.EVENT))


func test_handshake_is_reliable_and_ordered() -> void:
	assert_eq(MessageTaxonomy.delivery_for(MessageTaxonomy.Kind.HANDSHAKE),
			MessageTaxonomy.Delivery.RELIABLE_ORDERED)


func test_simulation_kinds_carry_a_tick() -> void:
	for kind in [MessageTaxonomy.Kind.COMMAND, MessageTaxonomy.Kind.EVENT,
			MessageTaxonomy.Kind.SNAPSHOT, MessageTaxonomy.Kind.DELTA]:
		assert_true(MessageTaxonomy.requires_tick(kind),
				"%s is placed in time" % MessageTaxonomy.kind_name(kind))
	for kind in [MessageTaxonomy.Kind.HANDSHAKE, MessageTaxonomy.Kind.CONTROL]:
		assert_false(MessageTaxonomy.requires_tick(kind),
				"%s is outside the simulation" % MessageTaxonomy.kind_name(kind))


func test_names_are_available_for_logging() -> void:
	assert_eq(MessageTaxonomy.kind_name(MessageTaxonomy.Kind.COMMAND), "COMMAND")
	assert_eq(MessageTaxonomy.direction_name(
			MessageTaxonomy.Direction.CLIENT_TO_SERVER), "CLIENT_TO_SERVER")
