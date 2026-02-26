class_name ChessAI
extends RefCounted
## Simple chess AI using minimax with alpha-beta pruning

enum Difficulty { EASY, MEDIUM, HARD }

## Signal for progress updates during async calculation
signal progress_updated(percent: float)

## Piece values for evaluation
const PIECE_VALUES := {
	Piece.Type.PAWN: 100,
	Piece.Type.KNIGHT: 320,
	Piece.Type.BISHOP: 330,
	Piece.Type.ROOK: 500,
	Piece.Type.QUEEN: 900,
	Piece.Type.KING: 20000
}

## Position bonuses for pieces (encourages central control)
const CENTER_BONUS := 10
const ADVANCED_PAWN_BONUS := 5

## Async evaluation settings
const YIELD_EVERY_N_NODES := 50  # Yield to UI every N nodes evaluated
var _nodes_evaluated: int = 0
var _total_nodes_estimate: int = 0

## Search abort guards
const MAX_NODES := 10000  # Hard ceiling on minimax nodes
const TIMEOUT_WEB_MS := 3000  # Max search time on web
const TIMEOUT_NATIVE_MS := 5000  # Max search time on native
var _search_start_time: int = 0
var _search_aborted: bool = false

var difficulty: Difficulty = Difficulty.MEDIUM
var max_depth: int = 3
var side: int = Piece.Side.BLACK


func _init(ai_side: int = Piece.Side.BLACK, ai_difficulty: Difficulty = Difficulty.MEDIUM) -> void:
	side = ai_side
	difficulty = ai_difficulty
	match difficulty:
		Difficulty.EASY:
			max_depth = 1
		Difficulty.MEDIUM:
			max_depth = 3
		Difficulty.HARD:
			max_depth = 4


func get_best_move(game_state: GameState) -> Dictionary:
	## Returns the best move as {from: Vector2i, to: Vector2i} or {column: int} for placement

	# Check if we need to place a piece first
	var arriving := game_state.arrival_manager.get_current_piece(side)
	if arriving != null:
		var placement := _get_best_placement(game_state)
		if placement.get("column", -1) >= 0:
			return placement
		# Can't place (back row full) — fall through to regular move

	# Find best move using minimax
	return _get_best_regular_move(game_state)


func get_best_move_async(game_state: GameState) -> Dictionary:
	## Async version - yields periodically to keep UI responsive
	## Works on all platforms including Web, iOS, Android

	# Check if we need to place a piece first (fast, no async needed)
	var arriving := game_state.arrival_manager.get_current_piece(side)
	if arriving != null:
		var placement := _get_best_placement(game_state)
		if placement.get("column", -1) >= 0:
			return placement
		# Can't place (back row full) — fall through to regular move

	# Find best move using async minimax
	return await _get_best_regular_move_async(game_state)


func _get_best_regular_move_async(game_state: GameState) -> Dictionary:
	## Async version that yields periodically to keep UI responsive
	var best_move := {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1)}
	var best_score := -INF
	var alpha := -INF
	var beta := INF

	var all_moves := _get_all_moves(game_state.board, side)

	# Shuffle for variety when moves have equal scores
	all_moves.shuffle()

	var total := all_moves.size()
	if total == 0:
		return best_move

	# Reset node counter for progress tracking
	_nodes_evaluated = 0
	_search_start_time = Time.get_ticks_msec()
	_search_aborted = false
	# Rough estimate: each top-level move explores ~30^depth nodes (with pruning ~10^depth)
	_total_nodes_estimate = total * int(pow(10, max_depth - 1))

	for i in range(total):
		var move = all_moves[i]

		# Use async minimax that yields periodically
		var score: float = await _minimax_async(game_state.board, move["from"], move["to"],
							  max_depth - 1, alpha, beta, false)

		if score > best_score:
			best_score = score
			best_move = move

		alpha = max(alpha, score)

		if _search_aborted:
			break

	# Fallback if aborted before finding any move
	if _search_aborted and best_move["from"] == Vector2i(-1, -1) and all_moves.size() > 0:
		push_warning("[AI] Search aborted, using random fallback move")
		best_move = all_moves[0]  # Already shuffled = effectively random

	progress_updated.emit(1.0)
	return best_move


func _minimax_async(board: Board, from: Vector2i, to: Vector2i,
			  depth: int, alpha: float, beta: float, is_maximizing: bool) -> float:
	## Async minimax with alpha-beta pruning - yields periodically to keep UI responsive

	# Yield periodically to let animations run
	_nodes_evaluated += 1
	if _nodes_evaluated % YIELD_EVERY_N_NODES == 0:
		var progress := clampf(float(_nodes_evaluated) / _total_nodes_estimate, 0.0, 0.99)
		progress_updated.emit(progress)
		await Engine.get_main_loop().process_frame

	# Abort check — hard ceiling on nodes and wall-clock time
	if _search_aborted:
		return 0.0
	var timeout_ms := TIMEOUT_WEB_MS if OS.has_feature("web") else TIMEOUT_NATIVE_MS
	if _nodes_evaluated >= MAX_NODES or (Time.get_ticks_msec() - _search_start_time) > timeout_ms:
		_search_aborted = true
		push_warning("[AI] Search aborted: nodes=%d, elapsed=%dms" % [_nodes_evaluated, Time.get_ticks_msec() - _search_start_time])
		return 0.0

	# Make the move on the board (will be undone before returning)
	var move_data := board.make_move(from, to)

	if move_data.is_empty():
		return -INF if is_maximizing else INF

	# Terminal conditions
	var current_side := side if is_maximizing else _opponent(side)
	var opponent_side := _opponent(current_side)

	var result: float
	if board.is_in_check(opponent_side):
		if _has_no_legal_moves(board, opponent_side):
			# Checkmate!
			result = INF if is_maximizing else -INF
			board.undo_move(move_data)
			return result
	elif _has_no_legal_moves(board, opponent_side):
		# Stalemate
		board.undo_move(move_data)
		return 0.0

	if depth == 0:
		result = _evaluate_board(board)
		board.undo_move(move_data)
		return result

	if is_maximizing:
		var max_eval := -INF
		var moves := _get_all_moves(board, side)
		for move in moves:
			var eval: float = await _minimax_async(board, move["from"], move["to"],
								 depth - 1, alpha, beta, false)
			max_eval = max(max_eval, eval)
			alpha = max(alpha, eval)
			if beta <= alpha:
				break  # Beta cutoff
		board.undo_move(move_data)
		return max_eval
	else:
		var min_eval := INF
		var moves := _get_all_moves(board, _opponent(side))
		for move in moves:
			var eval: float = await _minimax_async(board, move["from"], move["to"],
								 depth - 1, alpha, beta, true)
			min_eval = min(min_eval, eval)
			beta = min(beta, eval)
			if beta <= alpha:
				break  # Alpha cutoff
		board.undo_move(move_data)
		return min_eval


func _get_best_placement(game_state: GameState) -> Dictionary:
	## Find the best column to place an arriving piece
	var best_column := -1
	var best_score := -INF
	var back_row := 0 if side == Piece.Side.WHITE else 7
	var arriving := game_state.arrival_manager.get_current_piece(side)

	if arriving == null:
		return {"column": -1}

	for col in range(Board.BOARD_SIZE):
		var pos := Vector2i(col, back_row)
		# Must check can_place_piece_at which includes bishop rule check
		if game_state.board.can_place_piece_at(pos, arriving):
			# Simulate placement and evaluate
			var score := _evaluate_placement(game_state, col)

			# Add some randomness for variety (especially on easy)
			if difficulty == Difficulty.EASY:
				score += randf() * 50

			if score > best_score:
				best_score = score
				best_column = col

	return {"column": best_column}


func _evaluate_placement(game_state: GameState, column: int) -> float:
	## Evaluate how good a placement column is
	var score: float = 0.0
	var back_row: int = 0 if side == Piece.Side.WHITE else 7
	var arriving: Piece = game_state.arrival_manager.get_current_piece(side)

	if arriving == null:
		return 0.0

	# Prefer central columns for most pieces
	var center_dist: float = abs(column - 3.5)
	score -= center_dist * 5

	# Knights and bishops prefer center
	if arriving.type in [Piece.Type.KNIGHT, Piece.Type.BISHOP]:
		score -= center_dist * 10

	# Rooks prefer corners/edges
	if arriving.type == Piece.Type.ROOK:
		if column == 0 or column == 7:
			score += 20

	# King prefers to be protected (not on edges early)
	if arriving.type == Piece.Type.KING:
		if column >= 2 and column <= 5:
			score += 30

	# Check if placement would be immediately attacked
	var pos := Vector2i(column, back_row)
	if game_state.board.is_square_attacked(pos, side):
		score -= PIECE_VALUES[arriving.type] * 0.5

	return score


func _get_best_regular_move(game_state: GameState) -> Dictionary:
	## Find the best move using minimax
	var best_move := {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1)}
	var best_score := -INF
	var alpha := -INF
	var beta := INF

	var all_moves := _get_all_moves(game_state.board, side)

	# Shuffle for variety when moves have equal scores
	all_moves.shuffle()

	# Initialize search guards
	_nodes_evaluated = 0
	_search_start_time = Time.get_ticks_msec()
	_search_aborted = false

	for move in all_moves:
		var score := _minimax(game_state.board, move["from"], move["to"],
							  max_depth - 1, alpha, beta, false)

		if score > best_score:
			best_score = score
			best_move = move

		alpha = max(alpha, score)

		if _search_aborted:
			break

	# Fallback if aborted before finding any move
	if _search_aborted and best_move["from"] == Vector2i(-1, -1) and all_moves.size() > 0:
		push_warning("[AI] Sync search aborted, using random fallback move")
		best_move = all_moves[0]

	return best_move


func _minimax(board: Board, from: Vector2i, to: Vector2i,
			  depth: int, alpha: float, beta: float, is_maximizing: bool) -> float:
	## Minimax with alpha-beta pruning
	## Uses make_move/undo_move pattern for efficiency (no board copying)

	# Abort check — hard ceiling on nodes and wall-clock time
	_nodes_evaluated += 1
	if _search_aborted:
		return 0.0
	if _nodes_evaluated >= MAX_NODES or (Time.get_ticks_msec() - _search_start_time) > TIMEOUT_NATIVE_MS:
		_search_aborted = true
		push_warning("[AI] Sync search aborted: nodes=%d, elapsed=%dms" % [_nodes_evaluated, Time.get_ticks_msec() - _search_start_time])
		return 0.0

	# Make the move on the board (will be undone before returning)
	var move_data := board.make_move(from, to)

	if move_data.is_empty():
		return -INF if is_maximizing else INF

	# Terminal conditions
	var current_side := side if is_maximizing else _opponent(side)
	var opponent_side := _opponent(current_side)

	var result: float
	if board.is_in_check(opponent_side):
		if _has_no_legal_moves(board, opponent_side):
			# Checkmate!
			result = INF if is_maximizing else -INF
			board.undo_move(move_data)
			return result
	elif _has_no_legal_moves(board, opponent_side):
		# Stalemate
		board.undo_move(move_data)
		return 0.0

	if depth == 0:
		result = _evaluate_board(board)
		board.undo_move(move_data)
		return result

	if is_maximizing:
		var max_eval := -INF
		var moves := _get_all_moves(board, side)
		for move in moves:
			var eval := _minimax(board, move["from"], move["to"],
								 depth - 1, alpha, beta, false)
			max_eval = max(max_eval, eval)
			alpha = max(alpha, eval)
			if beta <= alpha:
				break  # Beta cutoff
		board.undo_move(move_data)
		return max_eval
	else:
		var min_eval := INF
		var moves := _get_all_moves(board, _opponent(side))
		for move in moves:
			var eval := _minimax(board, move["from"], move["to"],
								 depth - 1, alpha, beta, true)
			min_eval = min(min_eval, eval)
			beta = min(beta, eval)
			if beta <= alpha:
				break  # Alpha cutoff
		board.undo_move(move_data)
		return min_eval


func _evaluate_board(board: Board) -> float:
	## Evaluate the board position from AI's perspective
	var score: float = 0.0

	for row in range(Board.BOARD_SIZE):
		for col in range(Board.BOARD_SIZE):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece == null:
				continue

			var piece_value: float = PIECE_VALUES[piece.type]

			# Position bonuses
			var center_dist: float = abs(col - 3.5) + abs(row - 3.5)
			piece_value += (7 - center_dist) * CENTER_BONUS * 0.1

			# Pawn advancement bonus
			if piece.type == Piece.Type.PAWN:
				var advancement: float
				if piece.side == Piece.Side.WHITE:
					advancement = row
				else:
					advancement = 7 - row
				piece_value += advancement * ADVANCED_PAWN_BONUS

			# Add or subtract based on side
			if piece.side == side:
				score += piece_value
			else:
				score -= piece_value

	# Bonus for having the opponent in check
	if board.is_in_check(_opponent(side)):
		score += 50

	# Penalty for being in check
	if board.is_in_check(side):
		score -= 50

	return score


func _get_all_moves(board: Board, for_side: int) -> Array:
	## Get all legal moves for a side
	var moves := []
	for row in range(Board.BOARD_SIZE):
		for col in range(Board.BOARD_SIZE):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece and piece.side == for_side:
				var piece_moves := board.get_legal_moves(pos)
				for target in piece_moves:
					moves.append({"from": pos, "to": target})
	return moves


func _has_no_legal_moves(board: Board, for_side: int) -> bool:
	## Check if a side has no legal moves
	for row in range(Board.BOARD_SIZE):
		for col in range(Board.BOARD_SIZE):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece and piece.side == for_side:
				if board.get_legal_moves(pos).size() > 0:
					return false
	return true


func _opponent(s: int) -> int:
	return Piece.Side.BLACK if s == Piece.Side.WHITE else Piece.Side.WHITE


func _copy_board(board: Board) -> Board:
	## Create a deep copy of the board for simulation
	return Board.from_dict(board.to_dict())
