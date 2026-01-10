class_name GameState
extends RefCounted
## Manages the overall game state, turns, and win conditions

const ChessAIClass := preload("res://src/game/ai.gd")

enum Status { PLAYING, CHECK, CHECKMATE, STALEMATE, DRAW }
enum GameMode { TWO_PLAYER, VS_AI }

var board: Board
var current_player: int = Piece.Side.WHITE
var move_count: int = 0
var status: Status = Status.PLAYING
var game_mode: GameMode = GameMode.TWO_PLAYER

## Piece arrival system
var arrival_manager: PieceArrivalManager

## Draw detection
var draw_detector: DrawDetector
var draw_reason: DrawDetector.DrawReason = DrawDetector.DrawReason.NONE

## AI opponent
var ai = null  # ChessAI instance
var ai_side: int = Piece.Side.BLACK

## Move history for undo/navigation
var move_history: Array[Dictionary] = []
var history_index: int = -1

## Pending promotion state
var pending_promotion_pos: Vector2i = Vector2i(-1, -1)

## Signals
signal turn_changed(player: int)
signal status_changed(new_status: Status)
signal game_over(winner: int, reason: String)
signal move_executed(move_data: Dictionary)
signal promotion_needed(position: Vector2i, side: int)
signal ai_turn_started()
signal ai_move_made(move_data: Dictionary)
signal ai_thinking_started()
signal ai_thinking_finished()
signal ai_progress(percent: float)
signal triplet_clearing(triplet_positions: Array, victim_pos: Vector2i, direction: Vector2i)

## AI calculation state
var _ai_calculating := false


func _init() -> void:
	board = Board.new()
	arrival_manager = PieceArrivalManager.new()
	draw_detector = DrawDetector.new()
	_connect_board_signals()


func _connect_board_signals() -> void:
	board.piece_moved.connect(_on_piece_moved)
	board.piece_captured.connect(_on_piece_captured)


func start_new_game(settings: Dictionary = {}) -> void:
	## Initialize a new game with the given settings
	board = Board.new()
	_connect_board_signals()
	current_player = Piece.Side.WHITE
	move_count = 0
	status = Status.PLAYING
	move_history.clear()
	history_index = -1
	pending_promotion_pos = Vector2i(-1, -1)
	draw_detector.reset()
	draw_reason = DrawDetector.DrawReason.NONE

	# Configure arrival manager
	var arrival_mode: int = settings.get("arrival_mode", PieceArrivalManager.Mode.RANDOM_SAME)
	var arrival_frequency: int = settings.get("arrival_frequency", 1)
	arrival_manager.initialize(arrival_mode, arrival_frequency)

	game_mode = settings.get("game_mode", GameMode.TWO_PLAYER)

	# Initialize AI if playing against computer
	if game_mode == GameMode.VS_AI:
		ai_side = settings.get("ai_side", Piece.Side.BLACK)
		var ai_difficulty: int = settings.get("ai_difficulty", ChessAIClass.Difficulty.MEDIUM)
		ai = ChessAIClass.new(ai_side, ai_difficulty)
	else:
		ai = null

	# Handle initial piece arrivals
	_process_piece_arrival()

	turn_changed.emit(current_player)


func try_move(from: Vector2i, to: Vector2i) -> bool:
	## Attempts to make a move. Returns true if successful.
	if status != Status.PLAYING and status != Status.CHECK:
		return false

	# Can't move while waiting for promotion
	if pending_promotion_pos != Vector2i(-1, -1):
		return false

	var piece := board.get_piece(from)
	if piece == null or piece.side != current_player:
		return false

	# Track piece type before move for draw detection
	var was_pawn_move := (piece.type == Piece.Type.PAWN)

	var result := board.execute_move(from, to)
	if not result["valid"]:
		return false

	# Track capture for draw detection
	var was_capture := (result["captured"] != null)

	# Record move in history
	_record_move(result)

	move_count += 1

	# Record this player's move for arrival frequency tracking
	arrival_manager.record_move(current_player)

	# Check if promotion is needed
	if result["needs_promotion"]:
		pending_promotion_pos = to
		promotion_needed.emit(to, current_player)
		return true  # Move successful, but waiting for promotion choice

	# Check for triplet clear (before finishing turn)
	if Settings.triplet_clear_enabled:
		if _check_and_execute_triplet_clear(to):
			# If game ended due to king capture, don't finish turn
			if status == Status.CHECKMATE:
				return true

	# Finish the turn (check game status and switch)
	_finish_turn(was_capture, was_pawn_move)

	return true


func complete_promotion(piece_type: int) -> bool:
	## Completes a pending pawn promotion with the chosen piece type
	if pending_promotion_pos == Vector2i(-1, -1):
		return false

	if not board.promote_pawn(pending_promotion_pos, piece_type):
		return false

	pending_promotion_pos = Vector2i(-1, -1)

	# Now finish the turn (promotion is always a pawn move)
	_finish_turn(false, true)

	return true


func _finish_turn(was_capture: bool = false, was_pawn_move: bool = false) -> void:
	## Common turn-ending logic after a move (or promotion)
	# Update draw detection
	draw_detector.on_move_made(was_capture, was_pawn_move)

	# Check for game end conditions
	_update_game_status()

	if status == Status.CHECKMATE:
		game_over.emit(current_player, "checkmate")
		return
	elif status == Status.STALEMATE:
		game_over.emit(Piece.Side.WHITE, "stalemate")  # Draw
		return
	elif status == Status.DRAW:
		var reason_str := DrawDetector.get_draw_reason_string(draw_reason)
		game_over.emit(Piece.Side.WHITE, reason_str)  # Draw
		return

	# Record position after the move for repetition tracking
	draw_detector.record_position(board, _get_opponent(current_player))

	# Switch turns
	_switch_turn()


func try_place_piece(column: int) -> bool:
	## Attempts to place the arriving piece in the specified column
	## Placing a piece ENDS the turn (no move allowed after)
	var arriving := arrival_manager.get_current_piece(current_player)
	if arriving == null:
		return false

	# Determine row based on player color
	var row := 0 if current_player == Piece.Side.WHITE else 7
	var pos := Vector2i(column, row)

	if not board.place_piece(pos, arriving):
		return false

	arrival_manager.piece_placed(current_player)

	# Update game status after placement (check detection)
	_update_game_status()

	if status == Status.CHECKMATE:
		game_over.emit(current_player, "checkmate")
		return true
	elif status == Status.STALEMATE:
		game_over.emit(Piece.Side.WHITE, "stalemate")
		return true

	# Placing ends the turn
	_switch_turn()

	return true


func can_place_piece() -> bool:
	## Returns true if the current player has a piece to place AND has valid placement
	var arriving := arrival_manager.get_current_piece(current_player)
	if arriving == null:
		return false

	# Check if any square on back row is valid for this piece (includes bishop rule)
	var row := 0 if current_player == Piece.Side.WHITE else 7
	for col in range(Board.BOARD_SIZE):
		if board.can_place_piece_at(Vector2i(col, row), arriving):
			return true

	return false


func must_place_piece() -> bool:
	## Returns true if the current player must place a piece before moving
	## Returns false if no piece to place OR no space on back row
	return can_place_piece()


func _switch_turn() -> void:
	current_player = Piece.Side.BLACK if current_player == Piece.Side.WHITE else Piece.Side.WHITE

	# Process piece arrival for new player
	_process_piece_arrival()

	turn_changed.emit(current_player)

	# Check if it's AI's turn
	if is_ai_turn():
		ai_turn_started.emit()


func is_ai_turn() -> bool:
	## Returns true if it's the AI's turn to play
	return ai != null and current_player == ai_side


func request_ai_move() -> void:
	## Request the AI to make a move (call this after ai_turn_started)
	## AI will EITHER place a piece OR make a move (not both!)
	## Uses async calculation to keep UI responsive
	if not is_ai_turn():
		print("[DEBUG] request_ai_move: not AI's turn!")
		return

	if _ai_calculating:
		print("[DEBUG] request_ai_move: already calculating!")
		return

	_ai_calculating = true
	ai_thinking_started.emit()

	# Connect progress signal if not already connected
	if not ai.progress_updated.is_connected(_on_ai_progress):
		ai.progress_updated.connect(_on_ai_progress)

	# Use async version to keep UI responsive
	var move: Dictionary = await ai.get_best_move_async(self)

	_ai_calculating = false
	ai_thinking_finished.emit()

	# Execute the move
	if move.has("column") and move["column"] >= 0:
		var column: int = move["column"]
		try_place_piece(column)
		print("[DEBUG] AI placed at column %d" % column)
		ai_move_made.emit({"type": "placement", "column": column})
	elif move.has("from") and move.has("to"):
		var from: Vector2i = move["from"]
		var to: Vector2i = move["to"]
		if from != Vector2i(-1, -1):
			var success := try_move(from, to)
			print("[DEBUG] AI moved %s -> %s, success=%s" % [from, to, success])
			ai_move_made.emit({"type": "move", "from": from, "to": to})
		else:
			print("[DEBUG] AI: No valid move found!")
	else:
		print("[DEBUG] AI: Unexpected move format: %s" % move)


func _on_ai_progress(percent: float) -> void:
	ai_progress.emit(percent)


func _process_piece_arrival() -> void:
	## Check if a piece should arrive this turn
	var player := "WHITE" if current_player == Piece.Side.WHITE else "BLACK"
	var pieces_given := arrival_manager.white_pieces_given if current_player == Piece.Side.WHITE else arrival_manager.black_pieces_given
	var moves_made := arrival_manager.white_moves_made if current_player == Piece.Side.WHITE else arrival_manager.black_moves_made
	var should_arrive := arrival_manager.should_piece_arrive(current_player, move_count)
	print("[DEBUG] _process_piece_arrival for %s: pieces_given=%d, moves_made=%d, should_arrive=%s" % [player, pieces_given, moves_made, should_arrive])
	if should_arrive:
		arrival_manager.queue_next_piece(current_player)
		print("[DEBUG] Queued new piece for %s" % player)


func _update_game_status() -> void:
	var opponent := Piece.Side.BLACK if current_player == Piece.Side.WHITE else Piece.Side.WHITE

	# Check for draw conditions first
	# Note: In Saktris, insufficient material draw only applies when no more pieces can arrive
	var pieces_can_still_arrive := arrival_manager.has_pieces_remaining(Piece.Side.WHITE) or \
		arrival_manager.has_pieces_remaining(Piece.Side.BLACK) or \
		arrival_manager.get_current_piece(Piece.Side.WHITE) != null or \
		arrival_manager.get_current_piece(Piece.Side.BLACK) != null

	draw_reason = draw_detector.check_all_draws(board, opponent)

	# If it's insufficient material, only apply if no more pieces can arrive
	if draw_reason == DrawDetector.DrawReason.INSUFFICIENT_MATERIAL and pieces_can_still_arrive:
		draw_reason = DrawDetector.DrawReason.NONE

	if draw_reason != DrawDetector.DrawReason.NONE:
		status = Status.DRAW
		status_changed.emit(status)
		return

	# In Saktris, if opponent has pieces to place or remaining in queue,
	# they might be able to escape stalemate by placing and then moving
	var opponent_has_pieces_coming := arrival_manager.has_pieces_remaining(opponent) or \
		arrival_manager.get_current_piece(opponent) != null

	# Check if opponent is in check
	if board.is_in_check(opponent):
		# For checkmate: must have no legal moves AND no way to block via placement
		# Placing on back row rarely blocks check, so we check if any placement helps
		var can_escape_via_placement := false
		if opponent_has_pieces_coming:
			can_escape_via_placement = _can_placement_block_check(opponent)

		if _has_no_legal_moves(opponent) and not can_escape_via_placement:
			status = Status.CHECKMATE
		else:
			status = Status.CHECK
	else:
		# Check for stalemate - only if they have no moves AND no pieces to place
		if _has_no_legal_moves(opponent) and not opponent_has_pieces_coming:
			status = Status.STALEMATE
		else:
			status = Status.PLAYING

	status_changed.emit(status)


func _get_opponent(side: int) -> int:
	## Returns the opponent side
	return Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE


func _can_placement_block_check(side: int) -> bool:
	## Returns true if placing a piece on the back row could block check
	var back_row := 0 if side == Piece.Side.WHITE else 7
	var arriving := arrival_manager.get_current_piece(side)
	if arriving == null:
		return false

	# Try each column on back row
	for col in range(Board.BOARD_SIZE):
		var pos := Vector2i(col, back_row)
		if board.can_place_piece_at(pos, arriving):
			# Simulate placing the piece and check if still in check
			board.set_piece(pos, arriving)
			var still_in_check := board.is_in_check(side)
			board.set_piece(pos, null)  # Undo

			if not still_in_check:
				return true

	return false


func _has_no_legal_moves(side: int) -> bool:
	## Returns true if the player has no legal moves
	for row in range(Board.BOARD_SIZE):
		for col in range(Board.BOARD_SIZE):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece and piece.side == side:
				var moves := board.get_legal_moves(pos)
				if moves.size() > 0:
					return false
	return true


func _record_move(move_data: Dictionary) -> void:
	## Records a move for history/undo functionality
	# Truncate future moves if we're not at the end
	if history_index < move_history.size() - 1:
		move_history.resize(history_index + 1)

	move_history.append(move_data)
	history_index = move_history.size() - 1
	move_executed.emit(move_data)


func get_move_order_for_positions(positions: Array[Vector2i]) -> Array[Vector2i]:
	## Return positions sorted by when they were last moved (oldest first)
	## Positions with no move history come first (index = -1)
	var moves_with_time := []
	for pos in positions:
		var move_index := -1
		for i in range(move_history.size() - 1, -1, -1):
			if move_history[i]["to"] == pos:
				move_index = i
				break
		moves_with_time.append({"pos": pos, "index": move_index})

	moves_with_time.sort_custom(func(a, b): return a["index"] < b["index"])

	var result: Array[Vector2i] = []
	for item in moves_with_time:
		result.append(item["pos"])
	return result


# ─────────────────────────────────────────────────────────────────────────────
# Triplet Clear (Three-in-a-row)
# ─────────────────────────────────────────────────────────────────────────────

func _check_and_execute_triplet_clear(moved_to: Vector2i) -> bool:
	## Check if the move created a triplet and execute clearing
	## Returns true if a triplet was cleared
	var triplet_data := board.find_triplet_at(moved_to)
	if triplet_data.is_empty():
		return false

	var positions: Array[Vector2i] = []
	for pos in triplet_data["positions"]:
		positions.append(pos)
	var is_horizontal: bool = triplet_data["direction"] == "horizontal"

	# Determine direction based on last moved piece
	var sorted_by_move := get_move_order_for_positions(positions)
	var pusher_pos: Vector2i = sorted_by_move[-1]  # Last moved

	# If pusher is middle, use second-last
	if positions.size() == 3:
		var middle_pos := positions[1]
		if pusher_pos == middle_pos and sorted_by_move.size() >= 2:
			pusher_pos = sorted_by_move[-2]

	# Calculate movement direction (away from pusher)
	var move_dir: Vector2i
	if is_horizontal:
		# Pusher pushes others in opposite direction
		if pusher_pos.x == positions[0].x:
			move_dir = Vector2i(1, 0)  # Pusher on left, push right
		elif pusher_pos.x == positions[-1].x:
			move_dir = Vector2i(-1, 0)  # Pusher on right, push left
		else:
			# Pusher in middle - use second-last to determine
			move_dir = Vector2i(-1, 0) if pusher_pos.x > positions[0].x else Vector2i(1, 0)
	else:
		if pusher_pos.y == positions[0].y:
			move_dir = Vector2i(0, 1)
		elif pusher_pos.y == positions[-1].y:
			move_dir = Vector2i(0, -1)
		else:
			move_dir = Vector2i(0, -1) if pusher_pos.y > positions[0].y else Vector2i(0, 1)

	# Find first victim in movement direction
	var victim_pos := _find_first_piece_in_direction(positions, move_dir)

	# Check for king capture = win
	if victim_pos != Vector2i(-1, -1):
		var victim := board.get_piece(victim_pos)
		if victim and victim.type == Piece.Type.KING:
			var winner := Piece.Side.WHITE if victim.side == Piece.Side.BLACK else Piece.Side.BLACK
			# Emit signal for animation before ending game
			triplet_clearing.emit(positions, victim_pos, move_dir)
			# Remove pieces
			for pos in positions:
				board.remove_piece(pos)
			board.remove_piece(victim_pos)
			game_over.emit(winner, "triplet clear")
			return true

	# Emit signal for animation
	triplet_clearing.emit(positions, victim_pos, move_dir)

	# Remove pieces from board
	for pos in positions:
		board.remove_piece(pos)
	if victim_pos != Vector2i(-1, -1):
		board.remove_piece(victim_pos)

	return true


func _find_first_piece_in_direction(triplet: Array[Vector2i], dir: Vector2i) -> Vector2i:
	## Find the first piece outside the triplet in the given direction
	var edge_pos: Vector2i
	if dir.x > 0 or dir.y > 0:
		edge_pos = triplet[-1]  # Rightmost or bottommost
	else:
		edge_pos = triplet[0]   # Leftmost or topmost

	var check := edge_pos + dir
	while board.is_valid_position(check):
		if board.get_piece(check) != null:
			return check
		check += dir

	return Vector2i(-1, -1)  # No victim found


func _on_piece_moved(_from: Vector2i, _to: Vector2i, _piece: Piece) -> void:
	# Additional logic when piece moves (e.g., for UI updates)
	pass


func _on_piece_captured(_position: Vector2i, piece: Piece, _attacker_from: Vector2i) -> void:
	# If king is captured, game ends immediately (shouldn't happen in proper chess, but safety check)
	if piece.type == Piece.Type.KING:
		status = Status.CHECKMATE
		status_changed.emit(status)
		# The capturer wins
		var winner := Piece.Side.BLACK if piece.side == Piece.Side.WHITE else Piece.Side.WHITE
		game_over.emit(winner, "king captured")


func get_legal_moves_for_current_player() -> Dictionary:
	## Returns all legal moves for the current player
	## Format: { Vector2i: Array[Vector2i] } (from_pos: [to_positions])
	var all_moves := {}
	for row in range(Board.BOARD_SIZE):
		for col in range(Board.BOARD_SIZE):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece and piece.side == current_player:
				var moves := board.get_legal_moves(pos)
				if moves.size() > 0:
					all_moves[pos] = moves
	return all_moves


func to_dict() -> Dictionary:
	## Serialize game state for save/load
	return {
		"board": board.to_dict(),
		"current_player": current_player,
		"move_count": move_count,
		"status": status,
		"game_mode": game_mode,
		"arrival_manager": arrival_manager.to_dict(),
		"move_history": move_history,
		"history_index": history_index,
		"draw_detector": draw_detector.to_dict(),
		"draw_reason": draw_reason
	}


static func from_dict(data: Dictionary) -> GameState:
	## Deserialize game state from save data
	var state := GameState.new()
	state.board = Board.from_dict(data["board"])
	state.current_player = data["current_player"]
	state.move_count = data["move_count"]
	state.status = data["status"]
	state.game_mode = data.get("game_mode", GameMode.TWO_PLAYER)
	state.arrival_manager = PieceArrivalManager.from_dict(data["arrival_manager"])
	state.move_history = data.get("move_history", [])
	state.history_index = data.get("history_index", -1)
	if data.has("draw_detector"):
		state.draw_detector = DrawDetector.from_dict(data["draw_detector"])
	state.draw_reason = data.get("draw_reason", DrawDetector.DrawReason.NONE)
	state._connect_board_signals()
	return state
