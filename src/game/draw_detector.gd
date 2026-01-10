class_name DrawDetector
extends RefCounted
## Detects draw conditions: 50-move rule, threefold repetition, insufficient material

enum DrawReason { NONE, FIFTY_MOVE_RULE, THREEFOLD_REPETITION, INSUFFICIENT_MATERIAL }

# Position history for threefold repetition (hash -> count)
var position_history: Dictionary = {}

# Half-move clock for 50-move rule (resets on capture or pawn move)
var halfmove_clock: int = 0

# Position hasher
var _hasher: PositionHash


func _init() -> void:
	_hasher = PositionHash.new()


func reset() -> void:
	## Reset all draw tracking state
	position_history.clear()
	halfmove_clock = 0


func record_position(board: Board, side_to_move: int) -> void:
	## Record the current position for repetition tracking
	var hash := _hasher.compute_hash(board, side_to_move, {}, board.en_passant_target)
	if position_history.has(hash):
		position_history[hash] += 1
	else:
		position_history[hash] = 1


func on_move_made(was_capture: bool, was_pawn_move: bool) -> void:
	## Update state after a move is made
	if was_capture or was_pawn_move:
		halfmove_clock = 0
	else:
		halfmove_clock += 1


func is_fifty_move_rule() -> bool:
	## Returns true if 50-move rule applies (100 half-moves without capture or pawn move)
	return halfmove_clock >= 100


func is_threefold_repetition() -> bool:
	## Returns true if any position has occurred 3+ times
	for count in position_history.values():
		if count >= 3:
			return true
	return false


func get_repetition_count(board: Board, side_to_move: int) -> int:
	## Returns how many times the current position has occurred
	var hash := _hasher.compute_hash(board, side_to_move, {}, board.en_passant_target)
	return position_history.get(hash, 0)


func is_insufficient_material(board: Board) -> bool:
	## Returns true if neither side can checkmate with their remaining pieces
	var white_pieces := _get_pieces_for_side(board, Piece.Side.WHITE)
	var black_pieces := _get_pieces_for_side(board, Piece.Side.BLACK)

	# K vs K
	if white_pieces.size() == 1 and black_pieces.size() == 1:
		return true

	# K+minor vs K (where minor = bishop or knight)
	if _is_king_and_minor_vs_king(white_pieces, black_pieces):
		return true
	if _is_king_and_minor_vs_king(black_pieces, white_pieces):
		return true

	# K+B vs K+B with same-color bishops
	if _is_same_color_bishops_only(white_pieces, black_pieces, board):
		return true

	return false


func _get_pieces_for_side(board: Board, side: int) -> Array[Dictionary]:
	## Returns all pieces for a side with their positions
	## Format: [{type: int, pos: Vector2i}, ...]
	var pieces: Array[Dictionary] = []
	for row in range(8):
		for col in range(8):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece != null and piece.side == side:
				pieces.append({"type": piece.type, "pos": pos})
	return pieces


func _is_king_and_minor_vs_king(side_pieces: Array[Dictionary], opponent_pieces: Array[Dictionary]) -> bool:
	## Returns true if side has K+minor and opponent has only K
	if opponent_pieces.size() != 1:
		return false  # Opponent must have only king

	if side_pieces.size() != 2:
		return false  # Must have exactly 2 pieces

	# Check if one is king and other is minor piece
	var has_king := false
	var has_minor := false
	for p in side_pieces:
		if p["type"] == Piece.Type.KING:
			has_king = true
		elif p["type"] == Piece.Type.BISHOP or p["type"] == Piece.Type.KNIGHT:
			has_minor = true

	return has_king and has_minor


func _is_same_color_bishops_only(white_pieces: Array[Dictionary], black_pieces: Array[Dictionary], board: Board) -> bool:
	## Returns true if both sides have only K+B and bishops are on same color
	if white_pieces.size() != 2 or black_pieces.size() != 2:
		return false

	# Check white has K+B
	var white_bishop_pos: Vector2i = Vector2i(-1, -1)
	var white_has_king := false
	for p in white_pieces:
		if p["type"] == Piece.Type.KING:
			white_has_king = true
		elif p["type"] == Piece.Type.BISHOP:
			white_bishop_pos = p["pos"]
		else:
			return false  # Has other piece type

	if not white_has_king or white_bishop_pos == Vector2i(-1, -1):
		return false

	# Check black has K+B
	var black_bishop_pos: Vector2i = Vector2i(-1, -1)
	var black_has_king := false
	for p in black_pieces:
		if p["type"] == Piece.Type.KING:
			black_has_king = true
		elif p["type"] == Piece.Type.BISHOP:
			black_bishop_pos = p["pos"]
		else:
			return false

	if not black_has_king or black_bishop_pos == Vector2i(-1, -1):
		return false

	# Check if bishops are on same color squares
	var white_bishop_color := (white_bishop_pos.x + white_bishop_pos.y) % 2
	var black_bishop_color := (black_bishop_pos.x + black_bishop_pos.y) % 2

	return white_bishop_color == black_bishop_color


func check_all_draws(board: Board, side_to_move: int) -> DrawReason:
	## Check all draw conditions and return the reason (or NONE)
	if is_fifty_move_rule():
		return DrawReason.FIFTY_MOVE_RULE

	if is_threefold_repetition():
		return DrawReason.THREEFOLD_REPETITION

	if is_insufficient_material(board):
		return DrawReason.INSUFFICIENT_MATERIAL

	return DrawReason.NONE


static func get_draw_reason_string(reason: DrawReason) -> String:
	## Convert draw reason to human-readable string
	match reason:
		DrawReason.FIFTY_MOVE_RULE:
			return "50-move rule"
		DrawReason.THREEFOLD_REPETITION:
			return "threefold repetition"
		DrawReason.INSUFFICIENT_MATERIAL:
			return "insufficient material"
		_:
			return ""


func to_dict() -> Dictionary:
	## Serialize for save/load
	return {
		"position_history": position_history.duplicate(),
		"halfmove_clock": halfmove_clock
	}


static func from_dict(data: Dictionary) -> DrawDetector:
	## Deserialize from save data
	var detector := DrawDetector.new()
	detector.position_history = data.get("position_history", {}).duplicate()
	detector.halfmove_clock = data.get("halfmove_clock", 0)
	return detector
