class_name PositionHash
extends RefCounted
## Zobrist hashing for position comparison (used for threefold repetition detection)

# Random keys for each piece type on each square
# Structure: piece_keys[square_index][piece_key] where piece_key = type * 2 + side
var piece_keys: Array[Array] = []

# Key for side to move (XOR when black to move)
var side_to_move_key: int

# Keys for castling rights (4 possible: white kingside/queenside, black kingside/queenside)
var castling_keys: Array[int] = []

# Keys for en passant files (0-7 for each file)
var en_passant_keys: Array[int] = []

# Random number generator for generating keys
var _rng: RandomNumberGenerator


func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 0x5D588B65  # Fixed seed for reproducibility
	_initialize_keys()


func _initialize_keys() -> void:
	## Generate all random keys for Zobrist hashing
	# 64 squares, 12 piece types (6 types * 2 sides)
	piece_keys.clear()
	for _square in range(64):
		var square_keys: Array[int] = []
		for _piece in range(12):
			square_keys.append(_random_int64())
		piece_keys.append(square_keys)

	# Side to move
	side_to_move_key = _random_int64()

	# Castling rights (4 possibilities)
	castling_keys.clear()
	for _i in range(4):
		castling_keys.append(_random_int64())

	# En passant files (8 files)
	en_passant_keys.clear()
	for _i in range(8):
		en_passant_keys.append(_random_int64())


func _random_int64() -> int:
	## Generate a random 64-bit integer
	var high := _rng.randi()
	var low := _rng.randi()
	return (high << 32) | low


func _get_piece_key_index(piece: Piece) -> int:
	## Convert piece type and side to key index (0-11)
	return piece.type * 2 + piece.side


func _get_square_index(pos: Vector2i) -> int:
	## Convert board position to square index (0-63)
	return pos.y * 8 + pos.x


func compute_hash(board: Board, side_to_move: int, castling_rights: Dictionary = {}, ep_target: Vector2i = Vector2i(-1, -1)) -> int:
	## Compute the full position hash from scratch
	var hash_value: int = 0

	# Hash all pieces
	for row in range(8):
		for col in range(8):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece != null:
				var square_idx := _get_square_index(pos)
				var piece_idx := _get_piece_key_index(piece)
				hash_value ^= piece_keys[square_idx][piece_idx]

	# Hash side to move (only if black)
	if side_to_move == Piece.Side.BLACK:
		hash_value ^= side_to_move_key

	# Hash castling rights
	if castling_rights.get("white_kingside", false):
		hash_value ^= castling_keys[0]
	if castling_rights.get("white_queenside", false):
		hash_value ^= castling_keys[1]
	if castling_rights.get("black_kingside", false):
		hash_value ^= castling_keys[2]
	if castling_rights.get("black_queenside", false):
		hash_value ^= castling_keys[3]

	# Hash en passant file
	if ep_target.x >= 0 and ep_target.x < 8:
		hash_value ^= en_passant_keys[ep_target.x]

	return hash_value


func update_hash_for_move(old_hash: int, from_pos: Vector2i, to_pos: Vector2i, moved_piece: Piece, captured_piece: Piece = null) -> int:
	## Incrementally update hash after a move (XOR is its own inverse)
	var new_hash := old_hash

	# Remove piece from old position
	var from_sq := _get_square_index(from_pos)
	var piece_idx := _get_piece_key_index(moved_piece)
	new_hash ^= piece_keys[from_sq][piece_idx]

	# Add piece to new position
	var to_sq := _get_square_index(to_pos)
	new_hash ^= piece_keys[to_sq][piece_idx]

	# Remove captured piece if any
	if captured_piece != null:
		var captured_idx := _get_piece_key_index(captured_piece)
		new_hash ^= piece_keys[to_sq][captured_idx]

	return new_hash


func toggle_side_to_move(hash_value: int) -> int:
	## Toggle the side to move in the hash
	return hash_value ^ side_to_move_key
