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


func _init() -> void:
	board = Board.new()
	arrival_manager = PieceArrivalManager.new()
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

	# Configure arrival manager
	var arrival_mode: int = settings.get("arrival_mode", PieceArrivalManager.Mode.RANDOM_SAME)
	var arrival_frequency: int = settings.get("arrival_frequency", 2)
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

	var result := board.execute_move(from, to)
	if not result["valid"]:
		return false

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

	# Finish the turn (check game status and switch)
	_finish_turn()

	return true


func complete_promotion(piece_type: int) -> bool:
	## Completes a pending pawn promotion with the chosen piece type
	if pending_promotion_pos == Vector2i(-1, -1):
		return false

	if not board.promote_pawn(pending_promotion_pos, piece_type):
		return false

	pending_promotion_pos = Vector2i(-1, -1)

	# Now finish the turn
	_finish_turn()

	return true


func _finish_turn() -> void:
	## Common turn-ending logic after a move (or promotion)
	# Check for game end conditions
	_update_game_status()

	if status == Status.CHECKMATE:
		game_over.emit(current_player, "checkmate")
		return
	elif status == Status.STALEMATE:
		game_over.emit(Piece.Side.WHITE, "stalemate")  # Draw
		return

	# Switch turns
	_switch_turn()


func try_place_piece(column: int) -> bool:
	## Attempts to place the arriving piece in the specified column
	## After placing, the player can still make a move (turn doesn't end)
	var arriving := arrival_manager.get_current_piece(current_player)
	if arriving == null:
		return false

	# Determine row based on player color
	var row := 0 if current_player == Piece.Side.WHITE else 7
	var pos := Vector2i(column, row)

	if not board.place_piece(pos, arriving):
		return false

	arrival_manager.piece_placed(current_player)

	# Don't switch turns - player can still make a move
	return true


func can_place_piece() -> bool:
	## Returns true if the current player has a piece to place AND has space on back row
	var arriving := arrival_manager.get_current_piece(current_player)
	if arriving == null:
		return false

	# Check if any square on back row is empty
	var row := 0 if current_player == Piece.Side.WHITE else 7
	for col in range(Board.BOARD_SIZE):
		if board.is_empty(Vector2i(col, row)):
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
	## AI will place a piece (if needed) AND make a move in the same turn
	if not is_ai_turn():
		print("[DEBUG] request_ai_move: not AI's turn!")
		return

	# Step 1: Place piece if we have one AND there's space
	if must_place_piece():
		var placement: Dictionary = ai.get_best_move(self)
		print("[DEBUG] AI placement decision: %s" % placement)
		if placement.has("column") and placement["column"] >= 0:
			var column: int = placement["column"]
			try_place_piece(column)
			print("[DEBUG] AI placed at column %d" % column)
			ai_move_made.emit({"type": "placement", "column": column})
		else:
			print("[DEBUG] AI: No valid placement found, skipping")
	else:
		var arriving := arrival_manager.get_current_piece(current_player)
		if arriving != null:
			print("[DEBUG] AI has piece but no space to place - skipping placement")

	# Step 2: Make a regular move
	var move: Dictionary = ai.get_best_move(self)
	print("[DEBUG] AI move decision: %s" % move)

	if move.has("from") and move.has("to"):
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

	# In Saktris, if opponent has pieces to place or remaining in queue,
	# they can't be in stalemate (they'll place and then move)
	var opponent_has_pieces_coming := arrival_manager.has_pieces_remaining(opponent) or \
		arrival_manager.get_current_piece(opponent) != null

	# Check if opponent is in check
	if board.is_in_check(opponent):
		# Check for checkmate - only if they have no moves AND no pieces to place
		if _has_no_legal_moves(opponent) and not opponent_has_pieces_coming:
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


func _on_piece_moved(from: Vector2i, to: Vector2i, piece: Piece) -> void:
	# Additional logic when piece moves (e.g., for UI updates)
	pass


func _on_piece_captured(position: Vector2i, piece: Piece, _attacker_from: Vector2i) -> void:
	# Additional logic when piece captured (e.g., for scoring, animations)
	pass


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
		"history_index": history_index
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
	state._connect_board_signals()
	return state
