class_name NetworkProtocol
extends RefCounted
## Defines message types and serialization for network play

enum MessageType {
	# Connection/Room
	PING,
	PONG,

	# Game setup
	GAME_START,      # Host sends: {seed, settings, host_side}
	GAME_READY,      # Guest acknowledges ready

	# Gameplay
	MOVE,            # {from, to, seq}
	PLACEMENT,       # {column, seq}
	PROMOTION,       # {piece_type, seq}
	ACK,             # {seq}

	# State sync
	STATE_HASH,      # {hash, move_count}
	FULL_STATE,      # {state_data}
	RESYNC_REQUEST,  # Request full state from host

	# Game end
	RESIGN,
	DRAW_OFFER,
	DRAW_ACCEPT,
	DRAW_DECLINE,
	REMATCH_OFFER,
	REMATCH_ACCEPT,
	REMATCH_DECLINE,
}

## Room code character set - no ambiguous chars (0/O, 1/I)
const ROOM_CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH := 6


static func generate_room_code() -> String:
	var code := ""
	for i in range(ROOM_CODE_LENGTH):
		code += ROOM_CODE_CHARS[randi() % ROOM_CODE_CHARS.length()]
	return code


static func is_valid_room_code(code: String) -> bool:
	if code.length() != ROOM_CODE_LENGTH:
		return false
	for c in code.to_upper():
		if c not in ROOM_CODE_CHARS:
			return false
	return true


static func encode_message(msg_type: MessageType, data: Dictionary = {}) -> PackedByteArray:
	## Encode a message for transmission
	var msg := {
		"type": msg_type,
		"data": data,
		"ts": Time.get_unix_time_from_system()
	}
	var json := JSON.stringify(msg)
	return json.to_utf8_buffer()


static func decode_message(bytes: PackedByteArray) -> Dictionary:
	## Decode a received message. Returns empty dict on error.
	var json := bytes.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json)
	if parsed == null or not parsed is Dictionary:
		push_warning("NetworkProtocol: Failed to parse message")
		return {}
	return parsed as Dictionary


# ─────────────────────────────────────────────────────────────────────────────
# Message Builders
# ─────────────────────────────────────────────────────────────────────────────

static func make_ping() -> PackedByteArray:
	return encode_message(MessageType.PING)


static func make_pong() -> PackedByteArray:
	return encode_message(MessageType.PONG)


static func make_game_start(seed: int, settings: Dictionary, host_side: int) -> PackedByteArray:
	return encode_message(MessageType.GAME_START, {
		"seed": seed,
		"settings": settings,
		"host_side": host_side
	})


static func make_game_ready() -> PackedByteArray:
	return encode_message(MessageType.GAME_READY)


static func make_move(from: Vector2i, to: Vector2i, seq: int) -> PackedByteArray:
	return encode_message(MessageType.MOVE, {
		"from": [from.x, from.y],
		"to": [to.x, to.y],
		"seq": seq
	})


static func make_placement(column: int, seq: int) -> PackedByteArray:
	return encode_message(MessageType.PLACEMENT, {
		"column": column,
		"seq": seq
	})


static func make_promotion(piece_type: int, seq: int) -> PackedByteArray:
	return encode_message(MessageType.PROMOTION, {
		"piece_type": piece_type,
		"seq": seq
	})


static func make_ack(seq: int) -> PackedByteArray:
	return encode_message(MessageType.ACK, {"seq": seq})


static func make_state_hash(hash_val: int, move_count: int) -> PackedByteArray:
	return encode_message(MessageType.STATE_HASH, {
		"hash": hash_val,
		"move_count": move_count
	})


static func make_full_state(state_data: Dictionary) -> PackedByteArray:
	return encode_message(MessageType.FULL_STATE, {"state": state_data})


static func make_resync_request() -> PackedByteArray:
	return encode_message(MessageType.RESYNC_REQUEST)


static func make_resign() -> PackedByteArray:
	return encode_message(MessageType.RESIGN)


static func make_draw_offer() -> PackedByteArray:
	return encode_message(MessageType.DRAW_OFFER)


static func make_draw_accept() -> PackedByteArray:
	return encode_message(MessageType.DRAW_ACCEPT)


static func make_draw_decline() -> PackedByteArray:
	return encode_message(MessageType.DRAW_DECLINE)


static func make_rematch_offer() -> PackedByteArray:
	return encode_message(MessageType.REMATCH_OFFER)


static func make_rematch_accept() -> PackedByteArray:
	return encode_message(MessageType.REMATCH_ACCEPT)


static func make_rematch_decline() -> PackedByteArray:
	return encode_message(MessageType.REMATCH_DECLINE)


# ─────────────────────────────────────────────────────────────────────────────
# Message Parsers (convenience methods to extract typed data)
# ─────────────────────────────────────────────────────────────────────────────

static func parse_move(data: Dictionary) -> Dictionary:
	## Parse MOVE message data. Returns {from: Vector2i, to: Vector2i, seq: int}
	var from_arr: Array = data.get("from", [0, 0])
	var to_arr: Array = data.get("to", [0, 0])
	return {
		"from": Vector2i(from_arr[0], from_arr[1]),
		"to": Vector2i(to_arr[0], to_arr[1]),
		"seq": data.get("seq", 0)
	}


static func parse_placement(data: Dictionary) -> Dictionary:
	## Parse PLACEMENT message data. Returns {column: int, seq: int}
	return {
		"column": data.get("column", 0),
		"seq": data.get("seq", 0)
	}


static func parse_promotion(data: Dictionary) -> Dictionary:
	## Parse PROMOTION message data. Returns {piece_type: int, seq: int}
	return {
		"piece_type": data.get("piece_type", Piece.Type.QUEEN),
		"seq": data.get("seq", 0)
	}


static func parse_game_start(data: Dictionary) -> Dictionary:
	## Parse GAME_START message data
	return {
		"seed": data.get("seed", 0),
		"settings": data.get("settings", {}),
		"host_side": data.get("host_side", Piece.Side.WHITE)
	}


static func parse_state_hash(data: Dictionary) -> Dictionary:
	## Parse STATE_HASH message data
	return {
		"hash": data.get("hash", 0),
		"move_count": data.get("move_count", 0)
	}


static func compute_state_hash(game_state: GameState) -> int:
	## Compute a hash of the current game state for verification
	var state_dict := game_state.to_dict()
	# Remove non-deterministic fields
	state_dict.erase("chess_clock")  # Clock times will differ slightly
	var json := JSON.stringify(state_dict)
	return json.hash()
