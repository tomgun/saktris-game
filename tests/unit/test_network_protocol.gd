extends GutTest
## Unit tests for NetworkProtocol

const NetworkProtocol := preload("res://src/network/network_protocol.gd")


func test_generate_room_code_length() -> void:
	var code: String = NetworkProtocol.generate_room_code()
	assert_eq(code.length(), 6, "Room code should be 6 characters")


func test_generate_room_code_valid_chars() -> void:
	# Generate multiple codes and check all chars are valid
	for i in range(10):
		var code: String = NetworkProtocol.generate_room_code()
		for c in code:
			assert_true(c in NetworkProtocol.ROOM_CODE_CHARS, "Character '%s' should be in allowed set" % c)


func test_is_valid_room_code_correct_length() -> void:
	# Note: 1 is not in the allowed character set, so use 2 instead
	assert_true(NetworkProtocol.is_valid_room_code("ABC234"))
	assert_true(NetworkProtocol.is_valid_room_code("XYZABC"))


func test_is_valid_room_code_wrong_length() -> void:
	assert_false(NetworkProtocol.is_valid_room_code("ABC"))
	assert_false(NetworkProtocol.is_valid_room_code("ABC1234"))
	assert_false(NetworkProtocol.is_valid_room_code(""))


func test_is_valid_room_code_invalid_chars() -> void:
	# O, 0, I, 1 are not in the allowed set
	assert_false(NetworkProtocol.is_valid_room_code("ABC0O1"))
	assert_false(NetworkProtocol.is_valid_room_code("ABCIII"))


func test_is_valid_room_code_case_insensitive() -> void:
	assert_true(NetworkProtocol.is_valid_room_code("abc234"))
	assert_true(NetworkProtocol.is_valid_room_code("AbC234"))


func test_encode_decode_ping() -> void:
	var encoded := NetworkProtocol.make_ping()
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_eq(decoded["type"], NetworkProtocol.MessageType.PING)


func test_encode_decode_pong() -> void:
	var encoded := NetworkProtocol.make_pong()
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_eq(decoded["type"], NetworkProtocol.MessageType.PONG)


func test_encode_decode_move() -> void:
	var from := Vector2i(4, 1)
	var to := Vector2i(4, 3)
	var seq := 42

	var encoded := NetworkProtocol.make_move(from, to, seq)
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_eq(decoded["type"], NetworkProtocol.MessageType.MOVE)

	var data: Dictionary = decoded["data"]
	var parsed := NetworkProtocol.parse_move(data)
	assert_eq(parsed["from"], from)
	assert_eq(parsed["to"], to)
	assert_eq(parsed["seq"], seq)


func test_encode_decode_placement() -> void:
	var column := 3
	var seq := 7

	var encoded := NetworkProtocol.make_placement(column, seq)
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_eq(decoded["type"], NetworkProtocol.MessageType.PLACEMENT)

	var data: Dictionary = decoded["data"]
	var parsed := NetworkProtocol.parse_placement(data)
	assert_eq(parsed["column"], column)
	assert_eq(parsed["seq"], seq)


func test_encode_decode_promotion() -> void:
	var piece_type := Piece.Type.QUEEN
	var seq := 15

	var encoded := NetworkProtocol.make_promotion(piece_type, seq)
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_eq(decoded["type"], NetworkProtocol.MessageType.PROMOTION)

	var data: Dictionary = decoded["data"]
	var parsed := NetworkProtocol.parse_promotion(data)
	assert_eq(parsed["piece_type"], piece_type)
	assert_eq(parsed["seq"], seq)


func test_encode_decode_game_start() -> void:
	var seed_val := 12345
	var settings := {"arrival_mode": 2, "arrival_frequency": 3}
	var host_side := Piece.Side.WHITE

	var encoded := NetworkProtocol.make_game_start(seed_val, settings, host_side)
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_eq(decoded["type"], NetworkProtocol.MessageType.GAME_START)

	var data: Dictionary = decoded["data"]
	var parsed := NetworkProtocol.parse_game_start(data)
	assert_eq(parsed["seed"], seed_val)
	assert_eq(parsed["host_side"], host_side)
	assert_eq(parsed["settings"]["arrival_mode"], 2)
	assert_eq(parsed["settings"]["arrival_frequency"], 3)


func test_encode_decode_state_hash() -> void:
	var hash_val := 987654321
	var move_count := 42

	var encoded := NetworkProtocol.make_state_hash(hash_val, move_count)
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_eq(decoded["type"], NetworkProtocol.MessageType.STATE_HASH)

	var data: Dictionary = decoded["data"]
	var parsed := NetworkProtocol.parse_state_hash(data)
	assert_eq(parsed["hash"], hash_val)
	assert_eq(parsed["move_count"], move_count)


func test_encode_decode_ack() -> void:
	var seq := 99

	var encoded := NetworkProtocol.make_ack(seq)
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_eq(decoded["type"], NetworkProtocol.MessageType.ACK)
	assert_eq(decoded["data"]["seq"], seq)


func test_encode_decode_resign() -> void:
	var encoded := NetworkProtocol.make_resign()
	var decoded := NetworkProtocol.decode_message(encoded)
	assert_eq(decoded["type"], NetworkProtocol.MessageType.RESIGN)


func test_encode_decode_draw_offer() -> void:
	var encoded := NetworkProtocol.make_draw_offer()
	var decoded := NetworkProtocol.decode_message(encoded)
	assert_eq(decoded["type"], NetworkProtocol.MessageType.DRAW_OFFER)


func test_encode_decode_draw_accept() -> void:
	var encoded := NetworkProtocol.make_draw_accept()
	var decoded := NetworkProtocol.decode_message(encoded)
	assert_eq(decoded["type"], NetworkProtocol.MessageType.DRAW_ACCEPT)


func test_encode_decode_draw_decline() -> void:
	var encoded := NetworkProtocol.make_draw_decline()
	var decoded := NetworkProtocol.decode_message(encoded)
	assert_eq(decoded["type"], NetworkProtocol.MessageType.DRAW_DECLINE)


func test_decode_invalid_json() -> void:
	var invalid := "not json".to_utf8_buffer()
	var decoded := NetworkProtocol.decode_message(invalid)
	assert_true(decoded.is_empty(), "Invalid JSON should return empty dict")


func test_decode_non_dict_json() -> void:
	var array := "[1, 2, 3]".to_utf8_buffer()
	var decoded := NetworkProtocol.decode_message(array)
	assert_true(decoded.is_empty(), "Non-dict JSON should return empty dict")


func test_message_includes_timestamp() -> void:
	var encoded := NetworkProtocol.make_ping()
	var decoded := NetworkProtocol.decode_message(encoded)

	assert_true(decoded.has("ts"), "Message should include timestamp")
	assert_true(decoded["ts"] > 0, "Timestamp should be positive")
