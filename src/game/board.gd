class_name Board
extends RefCounted
## Represents the chess board state and handles move validation

const BOARD_SIZE := 8

## 2D array of Piece objects (null = empty square)
var squares: Array[Array]

## En passant target square (set when pawn moves 2 squares, cleared after next move)
var en_passant_target: Vector2i = Vector2i(-1, -1)

## Signals for game events
signal piece_moved(from: Vector2i, to: Vector2i, piece: Piece)
signal piece_captured(position: Vector2i, piece: Piece, attacker_from: Vector2i)
signal piece_placed(position: Vector2i, piece: Piece)
signal promotion_required(position: Vector2i, piece: Piece)


func _init() -> void:
	_initialize_empty_board()


func _initialize_empty_board() -> void:
	squares = []
	for row in range(BOARD_SIZE):
		var row_array: Array[Piece] = []
		row_array.resize(BOARD_SIZE)
		squares.append(row_array)


func get_piece(pos: Vector2i) -> Piece:
	## Returns the piece at the given position, or null if empty
	if not is_valid_position(pos):
		return null
	return squares[pos.y][pos.x]


func set_piece(pos: Vector2i, piece: Piece) -> void:
	## Places a piece at the given position
	if is_valid_position(pos):
		squares[pos.y][pos.x] = piece


func remove_piece(pos: Vector2i) -> Piece:
	## Removes and returns the piece at the given position
	var piece := get_piece(pos)
	if piece:
		squares[pos.y][pos.x] = null
	return piece


func is_valid_position(pos: Vector2i) -> bool:
	## Checks if a position is within board bounds
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE


func is_empty(pos: Vector2i) -> bool:
	## Checks if a position is empty
	return get_piece(pos) == null


func is_enemy(pos: Vector2i, side: int) -> bool:
	## Checks if position contains an enemy piece
	var piece := get_piece(pos)
	return piece != null and piece.side != side


func is_friendly(pos: Vector2i, side: int) -> bool:
	## Checks if position contains a friendly piece
	var piece := get_piece(pos)
	return piece != null and piece.side == side


func get_legal_moves(pos: Vector2i) -> Array[Vector2i]:
	## Returns all legal moves for the piece at the given position
	var piece := get_piece(pos)
	if piece == null:
		return []

	var moves: Array[Vector2i] = []
	var potential_moves := _get_potential_moves(pos, piece)

	# Filter out moves that would leave own king in check
	for move in potential_moves:
		if not _would_be_in_check_after_move(pos, move, piece.side):
			moves.append(move)

	return moves


func _get_potential_moves(pos: Vector2i, piece: Piece) -> Array[Vector2i]:
	## Returns all potential moves without considering check
	match piece.type:
		Piece.Type.KING:
			return _get_king_moves(pos, piece.side)
		Piece.Type.QUEEN:
			return _get_queen_moves(pos, piece.side)
		Piece.Type.ROOK:
			return _get_rook_moves(pos, piece.side)
		Piece.Type.BISHOP:
			return _get_bishop_moves(pos, piece.side)
		Piece.Type.KNIGHT:
			return _get_knight_moves(pos, piece.side)
		Piece.Type.PAWN:
			return _get_pawn_moves(pos, piece.side, piece.has_moved)
	return []


func _get_king_moves(pos: Vector2i, side: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0),                   Vector2i(1, 0),
		Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
	]
	for dir in directions:
		var target: Vector2i = pos + dir
		if is_valid_position(target) and not is_friendly(target, side):
			moves.append(target)

	# Castling - king must be on starting square and not moved
	var king := get_piece(pos)
	if king and not king.has_moved:
		var back_row := 0 if side == Piece.Side.WHITE else 7
		if pos.y == back_row and pos.x == 4:  # King on e-file
			# Kingside castling (O-O)
			if _can_castle_kingside(side, back_row):
				moves.append(Vector2i(6, back_row))
			# Queenside castling (O-O-O)
			if _can_castle_queenside(side, back_row):
				moves.append(Vector2i(2, back_row))

	return moves


func _can_castle_kingside(side: int, row: int) -> bool:
	## Check if kingside castling is legal
	# Rook must be on h-file and not moved
	var rook := get_piece(Vector2i(7, row))
	if rook == null or rook.type != Piece.Type.ROOK or rook.side != side or rook.has_moved:
		return false

	# Squares between king and rook must be empty (f and g files)
	if not is_empty(Vector2i(5, row)) or not is_empty(Vector2i(6, row)):
		return false

	# King must not be in check
	if is_in_check(side):
		return false

	# King must not pass through or land on attacked squares
	if is_square_attacked(Vector2i(5, row), side) or is_square_attacked(Vector2i(6, row), side):
		return false

	return true


func _can_castle_queenside(side: int, row: int) -> bool:
	## Check if queenside castling is legal
	# Rook must be on a-file and not moved
	var rook := get_piece(Vector2i(0, row))
	if rook == null or rook.type != Piece.Type.ROOK or rook.side != side or rook.has_moved:
		return false

	# Squares between king and rook must be empty (b, c, d files)
	if not is_empty(Vector2i(1, row)) or not is_empty(Vector2i(2, row)) or not is_empty(Vector2i(3, row)):
		return false

	# King must not be in check
	if is_in_check(side):
		return false

	# King must not pass through or land on attacked squares (c and d files)
	if is_square_attacked(Vector2i(2, row), side) or is_square_attacked(Vector2i(3, row), side):
		return false

	return true


func _get_queen_moves(pos: Vector2i, side: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	moves.append_array(_get_rook_moves(pos, side))
	moves.append_array(_get_bishop_moves(pos, side))
	return moves


func _get_rook_moves(pos: Vector2i, side: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for dir in directions:
		moves.append_array(_get_sliding_moves(pos, dir, side))
	return moves


func _get_bishop_moves(pos: Vector2i, side: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for dir in directions:
		moves.append_array(_get_sliding_moves(pos, dir, side))
	return moves


func _get_sliding_moves(pos: Vector2i, direction: Vector2i, side: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var current := pos + direction
	var guard := 0
	while is_valid_position(current):
		guard += 1
		if guard > BOARD_SIZE:
			push_warning("_get_sliding_moves: iteration guard hit")
			break
		if is_empty(current):
			moves.append(current)
		elif is_enemy(current, side):
			moves.append(current)
			break
		else:
			break
		current += direction
	return moves


func _get_knight_moves(pos: Vector2i, side: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [
		Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(2, -1),
		Vector2i(2, 1), Vector2i(1, 2), Vector2i(-1, 2), Vector2i(-2, 1)
	]
	for offset in offsets:
		var target: Vector2i = pos + offset
		if is_valid_position(target) and not is_friendly(target, side):
			moves.append(target)
	return moves


func _get_pawn_moves(pos: Vector2i, side: int, has_moved: bool) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	# White moves up (positive Y), Black moves down (negative Y)
	var direction := 1 if side == Piece.Side.WHITE else -1

	# Forward move
	var forward := pos + Vector2i(0, direction)
	if is_valid_position(forward) and is_empty(forward):
		moves.append(forward)
		# Double move from starting position
		if not has_moved:
			var double_forward := pos + Vector2i(0, direction * 2)
			if is_valid_position(double_forward) and is_empty(double_forward):
				moves.append(double_forward)

	# Captures
	for dx in [-1, 1]:
		var capture_pos := pos + Vector2i(dx, direction)
		if is_valid_position(capture_pos) and is_enemy(capture_pos, side):
			moves.append(capture_pos)

	# En passant
	if en_passant_target != Vector2i(-1, -1):
		for dx in [-1, 1]:
			var ep_capture := pos + Vector2i(dx, direction)
			if ep_capture == en_passant_target:
				# Verify the enemy pawn is adjacent
				var enemy_pawn_pos := pos + Vector2i(dx, 0)
				if is_enemy(enemy_pawn_pos, side):
					var enemy_pawn := get_piece(enemy_pawn_pos)
					if enemy_pawn and enemy_pawn.type == Piece.Type.PAWN:
						moves.append(ep_capture)

	return moves


func _would_be_in_check_after_move(from: Vector2i, to: Vector2i, side: int) -> bool:
	## Simulates a move and checks if the king would be in check
	# Save state
	var moving_piece := get_piece(from)
	var captured_piece := get_piece(to)

	# Make temporary move
	set_piece(from, null)
	set_piece(to, moving_piece)

	# Check if in check
	var in_check := is_in_check(side)

	# Restore state
	set_piece(from, moving_piece)
	set_piece(to, captured_piece)

	return in_check


func is_in_check(side: int) -> bool:
	## Returns true if the given side's king is in check
	var king_pos := find_king(side)
	if king_pos == Vector2i(-1, -1):
		return false  # No king on board yet (Saktris-specific)
	return is_square_attacked(king_pos, side)


func is_square_attacked(pos: Vector2i, defending_side: int) -> bool:
	## Returns true if the square is attacked by the opposing side
	var attacking_side := Piece.Side.BLACK if defending_side == Piece.Side.WHITE else Piece.Side.WHITE

	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var attacker_pos := Vector2i(col, row)
			var attacker := get_piece(attacker_pos)
			if attacker and attacker.side == attacking_side:
				var potential_moves := _get_potential_moves(attacker_pos, attacker)
				if pos in potential_moves:
					return true
	return false


func find_king(side: int) -> Vector2i:
	## Finds and returns the position of the king, or (-1, -1) if not found
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var piece := get_piece(Vector2i(col, row))
			if piece and piece.type == Piece.Type.KING and piece.side == side:
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func execute_move(from: Vector2i, to: Vector2i) -> Dictionary:
	## Executes a move and returns the result
	var piece := get_piece(from)
	var captured := get_piece(to)
	var result := {
		"valid": false,
		"piece": piece,
		"from": from,
		"to": to,
		"captured": captured,
		"special": "",  # For castling, en passant, promotion
		"needs_promotion": false
	}

	if piece == null:
		return result

	var legal_moves := get_legal_moves(from)
	if to not in legal_moves:
		return result

	# Store previous en passant target for this move
	var prev_ep_target := en_passant_target

	# Clear en passant target (will be set again if this is a double pawn move)
	en_passant_target = Vector2i(-1, -1)

	# Execute the move
	set_piece(from, null)
	set_piece(to, piece)
	piece.has_moved = true

	result["valid"] = true

	# Handle en passant capture
	if piece.type == Piece.Type.PAWN and to == prev_ep_target:
		# The captured pawn is behind the target square
		var direction := 1 if piece.side == Piece.Side.WHITE else -1
		var captured_pawn_pos := to - Vector2i(0, direction)
		captured = get_piece(captured_pawn_pos)
		if captured:
			set_piece(captured_pawn_pos, null)
			result["captured"] = captured
			result["special"] = "en_passant"
			result["captured_pos"] = captured_pawn_pos
			piece_captured.emit(captured_pawn_pos, captured, from)

	if captured and result["special"] != "en_passant":
		piece_captured.emit(to, captured, from)

	piece_moved.emit(from, to, piece)

	# Set en passant target if pawn moved 2 squares
	if piece.type == Piece.Type.PAWN and abs(to.y - from.y) == 2:
		var direction := 1 if piece.side == Piece.Side.WHITE else -1
		en_passant_target = from + Vector2i(0, direction)
		result["en_passant_target"] = en_passant_target

	# Handle castling - move the rook too
	if piece.type == Piece.Type.KING and abs(to.x - from.x) == 2:
		var rook_from: Vector2i
		var rook_to: Vector2i
		if to.x == 6:  # Kingside
			rook_from = Vector2i(7, to.y)
			rook_to = Vector2i(5, to.y)
			result["special"] = "castling_kingside"
		else:  # Queenside (to.x == 2)
			rook_from = Vector2i(0, to.y)
			rook_to = Vector2i(3, to.y)
			result["special"] = "castling_queenside"

		var rook := get_piece(rook_from)
		if rook:
			set_piece(rook_from, null)
			set_piece(rook_to, rook)
			rook.has_moved = true
			result["rook_from"] = rook_from
			result["rook_to"] = rook_to
			piece_moved.emit(rook_from, rook_to, rook)

	# Check for pawn promotion
	if piece.type == Piece.Type.PAWN:
		var promotion_row := 7 if piece.side == Piece.Side.WHITE else 0
		if to.y == promotion_row:
			result["needs_promotion"] = true
			result["special"] = "promotion"
			promotion_required.emit(to, piece)

	return result


func promote_pawn(pos: Vector2i, new_type: int) -> bool:
	## Promotes a pawn at the given position to a new piece type
	var piece := get_piece(pos)
	if piece == null or piece.type != Piece.Type.PAWN:
		return false

	# Valid promotion types: Queen, Rook, Bishop, Knight
	if new_type not in [Piece.Type.QUEEN, Piece.Type.ROOK, Piece.Type.BISHOP, Piece.Type.KNIGHT]:
		return false

	# Create the new piece
	var promoted := Piece.new(new_type, piece.side)
	promoted.has_moved = true
	set_piece(pos, promoted)

	# Emit signal for UI update
	piece_placed.emit(pos, promoted)
	return true


func place_piece(pos: Vector2i, piece: Piece) -> bool:
	## Places a new piece on the board (for Saktris arrival system)
	if not is_valid_position(pos) or not is_empty(pos):
		return false

	# Bishop placement rule: can't place on same color square as existing bishop
	if piece.type == Piece.Type.BISHOP:
		var target_color := (pos.x + pos.y) % 2
		if _has_bishop_on_color(piece.side, target_color):
			return false

	set_piece(pos, piece)
	piece_placed.emit(pos, piece)
	return true


func _has_bishop_on_color(side: int, square_color: int) -> bool:
	## Returns true if the player has a bishop on a square of the given color
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var p := get_piece(Vector2i(col, row))
			if p and p.side == side and p.type == Piece.Type.BISHOP:
				var color := (col + row) % 2
				if color == square_color:
					return true
	return false


func can_place_piece_at(pos: Vector2i, piece: Piece) -> bool:
	## Returns true if the piece can be placed at this position
	if not is_valid_position(pos) or not is_empty(pos):
		return false

	# Bishop placement rule
	if piece.type == Piece.Type.BISHOP:
		var target_color := (pos.x + pos.y) % 2
		if _has_bishop_on_color(piece.side, target_color):
			return false

	return true


# ─────────────────────────────────────────────────────────────────────────────
# Triplet Detection (Three-in-a-row)
# ─────────────────────────────────────────────────────────────────────────────

func find_triplet_at(pos: Vector2i) -> Dictionary:
	## Check if position is part of a triplet (3 same-type pieces in row/column)
	## Returns {positions: Array[Vector2i], direction: "horizontal"|"vertical"} or empty
	var piece := get_piece(pos)
	if piece == null:
		return {}

	var piece_type := piece.type

	# Check horizontal
	var h_positions := _find_consecutive_same_type(pos, Vector2i(1, 0), piece_type)
	if h_positions.size() >= 3:
		return {"positions": h_positions.slice(0, 3), "direction": "horizontal"}

	# Check vertical
	var v_positions := _find_consecutive_same_type(pos, Vector2i(0, 1), piece_type)
	if v_positions.size() >= 3:
		return {"positions": v_positions.slice(0, 3), "direction": "vertical"}

	return {}


func _find_consecutive_same_type(center: Vector2i, dir: Vector2i, piece_type: int) -> Array[Vector2i]:
	## Find all consecutive pieces of same type in both directions from center
	var positions: Array[Vector2i] = [center]

	# Search in positive direction
	var check := center + dir
	var guard := 0
	while is_valid_position(check):
		guard += 1
		if guard > BOARD_SIZE:
			push_warning("_find_consecutive_same_type: positive direction guard hit")
			break
		var p := get_piece(check)
		if p and p.type == piece_type:
			positions.append(check)
			check += dir
		else:
			break

	# Search in negative direction
	check = center - dir
	guard = 0
	while is_valid_position(check):
		guard += 1
		if guard > BOARD_SIZE:
			push_warning("_find_consecutive_same_type: negative direction guard hit")
			break
		var p := get_piece(check)
		if p and p.type == piece_type:
			positions.insert(0, check)
			check -= dir
		else:
			break

	return positions


# ─────────────────────────────────────────────────────────────────────────────
# Fast Move/Undo for AI (avoids board copying in minimax)
# ─────────────────────────────────────────────────────────────────────────────

func make_move(from: Vector2i, to: Vector2i) -> Dictionary:
	## Makes a move and returns data needed for undo_move()
	## This is optimized for AI minimax - no signals, no validation
	## Returns empty dict if move is invalid (no piece at from)
	var piece := get_piece(from)
	if piece == null:
		return {}

	var move_data := {
		"from": from,
		"to": to,
		"moved_piece": piece,
		"captured_piece": null,
		"captured_pos": to,
		"prev_en_passant": en_passant_target,
		"prev_has_moved": piece.has_moved,
		"special": "",
		"rook_from": Vector2i(-1, -1),
		"rook_to": Vector2i(-1, -1),
		"rook": null,
		"rook_prev_has_moved": false,
		"promoted_from_type": -1  # Store original type if promotion
	}

	# Store captured piece (may be null)
	move_data["captured_piece"] = get_piece(to)

	# Clear en passant target (will be set if this is a double pawn move)
	var prev_ep := en_passant_target
	en_passant_target = Vector2i(-1, -1)

	# Handle en passant capture
	if piece.type == Piece.Type.PAWN and to == prev_ep:
		var direction := 1 if piece.side == Piece.Side.WHITE else -1
		var captured_pawn_pos := to - Vector2i(0, direction)
		move_data["captured_piece"] = get_piece(captured_pawn_pos)
		move_data["captured_pos"] = captured_pawn_pos
		move_data["special"] = "en_passant"
		set_piece(captured_pawn_pos, null)

	# Execute the basic move
	set_piece(from, null)
	set_piece(to, piece)
	piece.has_moved = true

	# Set en passant target if pawn moved 2 squares
	if piece.type == Piece.Type.PAWN and abs(to.y - from.y) == 2:
		var direction := 1 if piece.side == Piece.Side.WHITE else -1
		en_passant_target = from + Vector2i(0, direction)

	# Handle castling
	if piece.type == Piece.Type.KING and abs(to.x - from.x) == 2:
		var rook_from: Vector2i
		var rook_to: Vector2i
		if to.x == 6:  # Kingside
			rook_from = Vector2i(7, to.y)
			rook_to = Vector2i(5, to.y)
			move_data["special"] = "castling_kingside"
		else:  # Queenside (to.x == 2)
			rook_from = Vector2i(0, to.y)
			rook_to = Vector2i(3, to.y)
			move_data["special"] = "castling_queenside"

		var rook := get_piece(rook_from)
		if rook:
			move_data["rook_from"] = rook_from
			move_data["rook_to"] = rook_to
			move_data["rook"] = rook
			move_data["rook_prev_has_moved"] = rook.has_moved
			set_piece(rook_from, null)
			set_piece(rook_to, rook)
			rook.has_moved = true

	# Handle pawn promotion - auto-promote to queen for AI
	if piece.type == Piece.Type.PAWN:
		var promotion_row := 7 if piece.side == Piece.Side.WHITE else 0
		if to.y == promotion_row:
			move_data["special"] = "promotion"
			move_data["promoted_from_type"] = Piece.Type.PAWN
			piece.type = Piece.Type.QUEEN

	return move_data


func undo_move(move_data: Dictionary) -> void:
	## Undoes a move made by make_move()
	if move_data.is_empty():
		return

	var from: Vector2i = move_data["from"]
	var to: Vector2i = move_data["to"]
	var piece: Piece = move_data["moved_piece"]

	# Handle promotion - restore original piece type
	if move_data["promoted_from_type"] >= 0:
		piece.type = move_data["promoted_from_type"]

	# Restore piece to original position
	set_piece(from, piece)
	piece.has_moved = move_data["prev_has_moved"]

	# Restore captured piece (or clear destination)
	var captured_pos: Vector2i = move_data["captured_pos"]
	var captured_piece = move_data["captured_piece"]

	if captured_pos == to:
		# Normal capture or no capture
		set_piece(to, captured_piece)
	else:
		# En passant - captured piece was not on destination square
		set_piece(to, null)
		set_piece(captured_pos, captured_piece)

	# Restore castling rook
	if move_data["rook"] != null:
		var rook: Piece = move_data["rook"]
		var rook_from: Vector2i = move_data["rook_from"]
		var rook_to: Vector2i = move_data["rook_to"]
		set_piece(rook_to, null)
		set_piece(rook_from, rook)
		rook.has_moved = move_data["rook_prev_has_moved"]

	# Restore en passant target
	en_passant_target = move_data["prev_en_passant"]


func to_dict() -> Dictionary:
	## Serialize board state for save/load
	var data := {
		"squares": [],
		"en_passant_target": [en_passant_target.x, en_passant_target.y]
	}
	for row in range(BOARD_SIZE):
		var row_data := []
		for col in range(BOARD_SIZE):
			var piece := get_piece(Vector2i(col, row))
			if piece:
				row_data.append(piece.to_dict())
			else:
				row_data.append(null)
		data["squares"].append(row_data)
	return data


static func from_dict(data: Dictionary) -> Board:
	## Deserialize board from save data
	var board := Board.new()
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var piece_data = data["squares"][row][col]
			if piece_data:
				board.set_piece(Vector2i(col, row), Piece.from_dict(piece_data))
	# Load en passant target
	if data.has("en_passant_target"):
		var ep = data["en_passant_target"]
		board.en_passant_target = Vector2i(ep[0], ep[1])
	return board
