extends TestCase
## Covers network/protocol/protocol_version.gd (brick 018).

const LOCAL_CONTENT := 123456789


func test_handshake_carries_version_and_content() -> void:
	var handshake := ProtocolVersion.make_handshake(LOCAL_CONTENT)
	assert_eq(int(handshake["protocol_version"]), ProtocolVersion.PROTOCOL_VERSION)
	assert_eq(int(handshake["content_hash"]), LOCAL_CONTENT)


func test_extra_handshake_fields_are_carried() -> void:
	var handshake := ProtocolVersion.make_handshake(LOCAL_CONTENT, {"client_name": "test"})
	assert_eq(handshake["client_name"], "test")


func test_matching_peers_are_accepted() -> void:
	assert_true(ProtocolVersion.accepts(
			ProtocolVersion.make_handshake(LOCAL_CONTENT), LOCAL_CONTENT))
	assert_eq(ProtocolVersion.check(
			ProtocolVersion.make_handshake(LOCAL_CONTENT), LOCAL_CONTENT),
			ProtocolVersion.Rejection.NONE)


func test_a_version_mismatch_is_refused_in_both_directions() -> void:
	# Unlike a save, a connection cannot be migrated: neither peer can rewrite the other.
	var older := {"protocol_version": ProtocolVersion.PROTOCOL_VERSION - 1,
			"content_hash": LOCAL_CONTENT}
	var newer := {"protocol_version": ProtocolVersion.PROTOCOL_VERSION + 1,
			"content_hash": LOCAL_CONTENT}
	assert_eq(ProtocolVersion.check(older, LOCAL_CONTENT),
			ProtocolVersion.Rejection.VERSION_MISMATCH)
	assert_eq(ProtocolVersion.check(newer, LOCAL_CONTENT),
			ProtocolVersion.Rejection.VERSION_MISMATCH)


func test_a_content_mismatch_is_caught_at_connect_time() -> void:
	# The failure this prevents: index 7 is a steel sword on the server and a healing
	# potion on the client. Every packet parses cleanly and means the wrong thing.
	var handshake := ProtocolVersion.make_handshake(LOCAL_CONTENT)
	assert_eq(ProtocolVersion.check(handshake, LOCAL_CONTENT + 1),
			ProtocolVersion.Rejection.CONTENT_MISMATCH)
	assert_false(ProtocolVersion.accepts(handshake, LOCAL_CONTENT + 1))


func test_version_is_checked_before_content() -> void:
	# With a different protocol, the content hash may not even mean the same thing, so
	# reporting the content as the problem would send the player down the wrong path.
	var both_wrong := {"protocol_version": ProtocolVersion.PROTOCOL_VERSION + 1,
			"content_hash": LOCAL_CONTENT + 1}
	assert_eq(ProtocolVersion.check(both_wrong, LOCAL_CONTENT),
			ProtocolVersion.Rejection.VERSION_MISMATCH)


func test_malformed_handshakes_are_refused_not_guessed() -> void:
	assert_eq(ProtocolVersion.check({}, LOCAL_CONTENT), ProtocolVersion.Rejection.MALFORMED)
	assert_eq(ProtocolVersion.check({"protocol_version": 1}, LOCAL_CONTENT),
			ProtocolVersion.Rejection.MALFORMED)
	assert_eq(ProtocolVersion.check(
			{"protocol_version": "1", "content_hash": LOCAL_CONTENT}, LOCAL_CONTENT),
			ProtocolVersion.Rejection.MALFORMED, "a string version is not a version")


func test_every_rejection_explains_itself() -> void:
	for handshake in [ProtocolVersion.make_handshake(LOCAL_CONTENT),
			{"protocol_version": 99, "content_hash": LOCAL_CONTENT},
			ProtocolVersion.make_handshake(LOCAL_CONTENT + 1), {}]:
		assert_true(ProtocolVersion.explain(handshake, LOCAL_CONTENT).length() > 10)


func test_content_hashes_combine_order_independently() -> void:
	# The two peers need not agree on registry ordering, only on content.
	var a := ProtocolVersion.combine_content_hashes(PackedInt64Array([11, 22, 33]))
	var b := ProtocolVersion.combine_content_hashes(PackedInt64Array([33, 11, 22]))
	assert_eq(a, b)
	assert_ne(a, ProtocolVersion.combine_content_hashes(PackedInt64Array([11, 22])),
			"a missing registry changes the combined hash")


func test_combined_hash_of_real_registries_detects_content_drift() -> void:
	Log.set_channel_level(Log.CH_CORE, Log.Level.SILENT)
	var items := DefinitionRegistry.new("item")
	items.register("item.sword.iron", {})
	items.lock()
	var blocks := DefinitionRegistry.new("block")
	blocks.register("block.stone", {})
	blocks.lock()

	var server_hash := ProtocolVersion.combine_content_hashes(
			PackedInt64Array([items.content_hash(), blocks.content_hash()]))

	var client_blocks := DefinitionRegistry.new("block")
	client_blocks.register("block.stone", {})
	client_blocks.register("block.dirt", {})  # client has content the server does not
	client_blocks.lock()
	var client_hash := ProtocolVersion.combine_content_hashes(
			PackedInt64Array([items.content_hash(), client_blocks.content_hash()]))

	assert_ne(server_hash, client_hash)
	assert_false(ProtocolVersion.accepts(
			ProtocolVersion.make_handshake(client_hash), server_hash))
	Log.clear_channel_levels()
