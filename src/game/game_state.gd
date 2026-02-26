class_name GameState
extends RefCounted
## Manages the overall game state, turns, and win conditions

const ChessAIClass := preload("res://src/game/ai.gd")

enum Status { PLAYING, CHECK, CHECKMATE, STALEMATE, DRAW, TIMEOUT }
enum GameMode { TWO_PLAYER, VS_AI, ACTION }

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

## Chess clock (optional, null if untimed)
var chess_clock: ChessClock = null
var time_control_preset: String = ""

## AI opponent
var ai = null  # ChessAI instance
var ai_side: int = Piece.Side.BLACK
var _ai_thread: Thread = null
var _ai_result: Dictionary = {}

## Move history for undo/navigation
var move_history: Array[Dictionary] = []
var history_index: int = -1

## Pending promotion state
var pending_promotion_pos: Vector2i = Vector2i(-1, -1)
var _promoting_side: int = -1  ## Side of the pawn being promoted (for action mode)

## Action mode configuration
var action_move_cooldown: float = 3.0      ## Seconds between moves per player
var action_arrival_interval: float = 8.0   ## Seconds between piece arrivals
var action_ai_reaction_min: float = 0.4    ## Minimum AI reaction time after cooldown ready
var action_ai_reaction_max: float = 1.0    ## Maximum AI reaction time after cooldown ready

## Action mode timers (counts down to 0)
var _white_move_timer: float = 0.0
var _black_move_timer: float = 0.0
var _arrival_timer: float = 0.0
var _next_arrival_side: int = Piece.Side.WHITE
var _cached_arrival_column: int = -1  ## Cached target column for arrival indicator
var _ai_reaction_timer: float = 0.0   ## AI waits this long after cooldown before moving
var _ai_reaction_pending: bool = false  ## True when AI cooldown ready but waiting on reaction

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
signal clock_time_updated(white_time: float, black_time: float)
signal clock_low_time(side: int, seconds: float)

## Action mode signals
signal action_cooldown_updated(side: int, remaining: float, max_cooldown: float)
signal action_arrival_warning(side: int, seconds: float)
signal action_piece_auto_placed(side: int, column: int, piece: Piece)
signal action_piece_bumped_off(position: Vector2i, piece: Piece)

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


func _connect_clock_signals() -> void:
	if chess_clock:
		chess_clock.time_expired.connect(_on_clock_time_expired)
		chess_clock.time_updated.connect(_on_clock_time_updated)
		chess_clock.low_time_warning.connect(_on_clock_low_time_warning)


func _on_clock_time_expired(side: int) -> void:
	## Handle clock time expiry - the player who ran out of time loses
	status = Status.TIMEOUT
	status_changed.emit(status)
	var winner := Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE
	game_over.emit(winner, "timeout")


func _on_clock_time_updated(white_time: float, black_time: float) -> void:
	clock_time_updated.emit(white_time, black_time)


func _on_clock_low_time_warning(side: int, seconds: float) -> void:
	clock_low_time.emit(side, seconds)


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
	_promoting_side = -1
	draw_detector.reset()
	draw_reason = DrawDetector.DrawReason.NONE

	# Configure arrival manager
	var arrival_mode: int = settings.get("arrival_mode", PieceArrivalManager.Mode.RANDOM_SAME)
	var arrival_frequency: int = settings.get("arrival_frequency", 1)
	arrival_manager.initialize(arrival_mode, arrival_frequency)

	game_mode = settings.get("game_mode", GameMode.TWO_PLAYER)

	# Initialize chess clock if time control specified
	time_control_preset = settings.get("time_control", "")
	if time_control_preset != "":
		chess_clock = ChessClock.new()
		if not chess_clock.setup_from_preset(time_control_preset):
			# Custom time control
			var custom_time: float = settings.get("time_seconds", 300.0)
			var custom_increment: float = settings.get("increment_seconds", 0.0)
			chess_clock.setup(custom_time, custom_increment)
		_connect_clock_signals()
		chess_clock.start()
	else:
		chess_clock = null

	# Initialize AI if playing against computer (VS_AI or ACTION with AI)
	var use_ai: bool = settings.get("use_ai", game_mode == GameMode.VS_AI)
	if use_ai or game_mode == GameMode.VS_AI:
		ai_side = settings.get("ai_side", Piece.Side.BLACK)
		var ai_difficulty: int = settings.get("ai_difficulty", ChessAIClass.Difficulty.MEDIUM)
		ai = ChessAIClass.new(ai_side, ai_difficulty)
	else:
		ai = null

	# Initialize action mode settings
	if game_mode == GameMode.ACTION:
		action_move_cooldown = settings.get("action_move_cooldown", 3.0)
		action_arrival_interval = settings.get("action_arrival_interval", 8.0)
		action_ai_reaction_min = settings.get("action_ai_reaction_min", 0.4)
		action_ai_reaction_max = settings.get("action_ai_reaction_max", 1.0)
		_white_move_timer = 0.0
		_black_move_timer = 0.0
		_arrival_timer = action_arrival_interval
		_next_arrival_side = Piece.Side.WHITE
		_ai_reaction_timer = 0.0
		_ai_reaction_pending = false

	# Handle initial piece arrivals (not for action mode - uses timer-based arrivals)
	if game_mode != GameMode.ACTION:
		_process_piece_arrival()

	turn_changed.emit(current_player)


# ─────────────────────────────────────────────────────────────────────────────
# Action Mode (Real-time gameplay)
# ─────────────────────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	## Update action mode timers - call this from game loop
	if game_mode != GameMode.ACTION:
		return
	if not is_game_in_progress():
		return
	_tick_action_mode(delta)


func _tick_action_mode(delta: float) -> void:
	## Update move cooldowns and piece arrival timer
	# Update move cooldowns
	if _white_move_timer > 0:
		_white_move_timer = maxf(0, _white_move_timer - delta)
		action_cooldown_updated.emit(Piece.Side.WHITE, _white_move_timer, action_move_cooldown)
	if _black_move_timer > 0:
		_black_move_timer = maxf(0, _black_move_timer - delta)
		action_cooldown_updated.emit(Piece.Side.BLACK, _black_move_timer, action_move_cooldown)

	# Update arrival timer
	_arrival_timer -= delta
	if _arrival_timer <= 3.0 and _arrival_timer > 0:
		action_arrival_warning.emit(_next_arrival_side, _arrival_timer)
	if _arrival_timer <= 0:
		_auto_place_piece()
		_arrival_timer = action_arrival_interval
		_cached_arrival_column = -1  # Invalidate cache after placement

	# AI auto-move in action mode (with reaction delay to be fair to humans)
	if ai != null and not _ai_calculating:
		if can_player_move(ai_side):
			if not _ai_reaction_pending:
				# Cooldown just became ready - start reaction timer
				_ai_reaction_pending = true
				_ai_reaction_timer = randf_range(action_ai_reaction_min, action_ai_reaction_max)
			else:
				# Waiting on reaction timer
				_ai_reaction_timer -= delta
				if _ai_reaction_timer <= 0:
					_ai_reaction_pending = false
					_request_action_ai_move()


func can_player_move(side: int) -> bool:
	## Returns true if the player can make a move right now
	if game_mode != GameMode.ACTION:
		return side == current_player
	var timer := _white_move_timer if side == Piece.Side.WHITE else _black_move_timer
	return timer <= 0


func _reset_move_cooldown(side: int) -> void:
	## Reset the move cooldown for a side after they make a move
	if side == Piece.Side.WHITE:
		_white_move_timer = action_move_cooldown
	else:
		_black_move_timer = action_move_cooldown
	action_cooldown_updated.emit(side, action_move_cooldown, action_move_cooldown)


func _auto_place_piece() -> void:
	## Automatically place the next piece for the current arrival side
	## If back row is full, bumps pieces forward to make room
	var side := _next_arrival_side

	# Queue a piece if needed (only if there isn't one already waiting)
	var piece := arrival_manager.get_current_piece(side)
	if piece == null:
		arrival_manager.queue_next_piece(side)
		piece = arrival_manager.get_current_piece(side)
	if piece == null:
		# No more pieces available - alternate and try again next interval
		_next_arrival_side = Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE
		return

	# Find valid placement column
	var row := 0 if side == Piece.Side.WHITE else 7
	var valid_cols: Array[int] = []
	for col in range(Board.BOARD_SIZE):
		if board.can_place_piece_at(Vector2i(col, row), piece):
			valid_cols.append(col)

	# Use the cached target column (same one shown in UI indicator)
	var col := get_arrival_target_column()
	if col < 0:
		# Can't place anywhere - skip
		arrival_manager.piece_placed(side)
		_next_arrival_side = Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE
		return

	if valid_cols.is_empty():
		# Back row is full - bump pieces to make room at the target column
		_bump_column_forward(col, side)

	# Place the piece
	board.place_piece(Vector2i(col, row), piece)
	arrival_manager.piece_placed(side)

	action_piece_auto_placed.emit(side, col, piece)

	# Alternate sides for next arrival
	_next_arrival_side = Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE

	# Check if placement causes checkmate (rare but possible)
	_update_game_status()


func _pick_bump_column(side: int, piece: Piece) -> int:
	## Pick which column to bump when back row is full
	## Prefers center columns that can accept the piece after bumping
	var row := 0 if side == Piece.Side.WHITE else 7
	var direction := 1 if side == Piece.Side.WHITE else -1

	var candidates: Array = []
	for col in range(Board.BOARD_SIZE):
		# Check if this column can be bumped (at least one empty space or edge)
		var can_bump := _can_bump_column(col, side)
		if can_bump:
			var dist := absf(col - 3.5)
			candidates.append({"col": col, "dist": dist})

	if candidates.is_empty():
		return -1  # No column can be bumped

	# Sort by distance from center
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	return candidates[0]["col"]


func _can_bump_column(col: int, side: int) -> bool:
	## Check if a column can be bumped (pieces can move forward)
	var row := 0 if side == Piece.Side.WHITE else 7
	var direction := 1 if side == Piece.Side.WHITE else -1
	var far_row := 7 if side == Piece.Side.WHITE else 0

	# Column can always be bumped - worst case, far piece falls off
	return true


func _bump_column_forward(col: int, side: int) -> void:
	## Bump all pieces in a column forward by one square
	## If column is full, the furthest piece is captured (falls off)
	var back_row := 0 if side == Piece.Side.WHITE else 7
	var far_row := 7 if side == Piece.Side.WHITE else 0
	var direction := 1 if side == Piece.Side.WHITE else -1

	# Find all pieces in this column, from far end to back row
	var pieces_to_move: Array = []
	var current_row := far_row
	var guard := 0
	while current_row != back_row + direction:
		guard += 1
		if guard > Board.BOARD_SIZE + 1:
			push_warning("_bump_column_forward: iteration guard hit")
			break
		var pos := Vector2i(col, current_row)
		var p := board.get_piece(pos)
		if p != null:
			pieces_to_move.append({"pos": pos, "piece": p})
		current_row -= direction

	if pieces_to_move.is_empty():
		return

	# Check if the furthest piece will fall off
	var furthest: Dictionary = pieces_to_move[0]
	var furthest_pos: Vector2i = furthest["pos"]
	var furthest_new_row: int = furthest_pos.y + direction
	if furthest_new_row < 0 or furthest_new_row > 7:
		# Piece falls off the board - it's captured!
		var captured_piece: Piece = furthest["piece"]
		board.remove_piece(furthest_pos)
		action_piece_bumped_off.emit(furthest_pos, captured_piece)

		# Check if king was captured
		if captured_piece.type == Piece.Type.KING:
			var winner := Piece.Side.WHITE if captured_piece.side == Piece.Side.BLACK else Piece.Side.BLACK
			status = Status.CHECKMATE
			status_changed.emit(status)
			game_over.emit(winner, "king bumped off")
			return

		pieces_to_move.remove_at(0)

	# Move remaining pieces forward (from far to near to avoid collisions)
	for item in pieces_to_move:
		var old_pos: Vector2i = item["pos"]
		var new_pos := Vector2i(col, old_pos.y + direction)
		var p: Piece = item["piece"]
		board.remove_piece(old_pos)
		board.set_piece(new_pos, p)


func get_arrival_target_position() -> Vector2i:
	## Get the target position (column, row) for the next arrival (for UI display)
	## Returns Vector2i(-1, -1) if no valid position
	var col := get_arrival_target_column()
	if col < 0:
		return Vector2i(-1, -1)
	var row := 0 if _next_arrival_side == Piece.Side.WHITE else 7
	return Vector2i(col, row)


func get_arrival_target_column() -> int:
	## Get the cached target column for the next arrival (for UI display)
	## Returns -1 if no valid column
	if _cached_arrival_column >= 0:
		return _cached_arrival_column

	# Calculate and cache
	var side := _next_arrival_side
	var piece := arrival_manager.get_current_piece(side)
	if piece == null:
		var next_type := arrival_manager.get_next_piece_preview(side)
		if next_type >= 0:
			piece = Piece.new(next_type, side)

	if piece == null:
		return -1

	var row := 0 if side == Piece.Side.WHITE else 7
	var valid_cols: Array[int] = []
	for col in range(Board.BOARD_SIZE):
		if board.can_place_piece_at(Vector2i(col, row), piece):
			valid_cols.append(col)

	if valid_cols.is_empty():
		# Row is full - pick a bump column instead
		_cached_arrival_column = _pick_bump_column(side, piece)
	else:
		_cached_arrival_column = _pick_placement_column(valid_cols)

	return _cached_arrival_column


func _pick_placement_column(valid_cols: Array[int]) -> int:
	## Pick a placement column, preferring center columns
	if valid_cols.is_empty():
		return 0

	# Sort by distance from center (columns 3 and 4 are center)
	var scored: Array = []
	for col in valid_cols:
		var dist := absf(col - 3.5)
		scored.append({"col": col, "dist": dist})

	scored.sort_custom(func(a, b): return a["dist"] < b["dist"])

	# Pick from the closest 2-3 options randomly for some variation
	var top_count := mini(3, scored.size())
	var choice := randi() % top_count
	return scored[choice]["col"]


func try_move(from: Vector2i, to: Vector2i) -> bool:
	## Attempts to make a move. Returns true if successful.
	if status != Status.PLAYING and status != Status.CHECK:
		return false

	# Can't move while waiting for promotion
	if pending_promotion_pos != Vector2i(-1, -1):
		return false

	var piece := board.get_piece(from)
	if piece == null:
		return false

	# Action mode: check cooldown instead of turn
	if game_mode == GameMode.ACTION:
		if not can_player_move(piece.side):
			return false
	else:
		if piece.side != current_player:
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
	var moving_side := piece.side
	arrival_manager.record_move(moving_side)

	# Check if promotion is needed
	if result["needs_promotion"]:
		# In action mode, pawns reaching the back row are captured (fall off the board)
		# This prevents overpowered instant promotions in the chaotic fast-paced mode
		if game_mode == GameMode.ACTION:
			var captured_pawn := board.get_piece(to)
			board.remove_piece(to)
			action_piece_bumped_off.emit(to, captured_pawn)
			_finish_turn(false, true, moving_side)
			return true

		# Normal mode: wait for player to choose promotion piece
		pending_promotion_pos = to
		_promoting_side = moving_side
		promotion_needed.emit(to, moving_side)
		return true  # Move successful, but waiting for promotion choice

	# Check if game already ended from king capture (signal handler sets this)
	if status == Status.CHECKMATE:
		if chess_clock:
			chess_clock.pause()
		return true

	# Check for triplet clear (before finishing turn)
	if Settings.triplet_clear_enabled:
		if _check_and_execute_triplet_clear(to):
			# If game ended due to king capture in triplet, don't finish turn
			if status == Status.CHECKMATE:
				return true

	# Finish the turn (check game status and switch)
	_finish_turn(was_capture, was_pawn_move, moving_side)

	return true


func complete_promotion(piece_type: int) -> bool:
	## Completes a pending pawn promotion with the chosen piece type
	if pending_promotion_pos == Vector2i(-1, -1):
		return false

	if not board.promote_pawn(pending_promotion_pos, piece_type):
		return false

	var promoting_side := _promoting_side
	pending_promotion_pos = Vector2i(-1, -1)
	_promoting_side = -1

	# Now finish the turn (promotion is always a pawn move)
	_finish_turn(false, true, promoting_side)

	return true


func _finish_turn(was_capture: bool = false, was_pawn_move: bool = false, moving_side: int = -1) -> void:
	## Common turn-ending logic after a move (or promotion)
	## moving_side: which side made the move (used in action mode)
	# Update draw detection
	draw_detector.on_move_made(was_capture, was_pawn_move)

	# Check for game end conditions
	_update_game_status()

	# Determine winner based on game mode
	var winner := current_player if game_mode != GameMode.ACTION else moving_side

	if status == Status.CHECKMATE:
		if chess_clock:
			chess_clock.pause()
		game_over.emit(winner, "checkmate")
		return
	elif status == Status.STALEMATE:
		if chess_clock:
			chess_clock.pause()
		game_over.emit(Piece.Side.WHITE, "stalemate")  # Draw
		return
	elif status == Status.DRAW:
		if chess_clock:
			chess_clock.pause()
		var reason_str := DrawDetector.get_draw_reason_string(draw_reason)
		game_over.emit(Piece.Side.WHITE, reason_str)  # Draw
		return

	# Record position after the move for repetition tracking
	var opponent := _get_opponent(moving_side) if moving_side >= 0 else _get_opponent(current_player)
	draw_detector.record_position(board, opponent)

	# Action mode: reset cooldown instead of switching turns
	if game_mode == GameMode.ACTION:
		if moving_side >= 0:
			_reset_move_cooldown(moving_side)
		return

	# Switch chess clock (adds increment to player who just moved)
	if chess_clock:
		chess_clock.switch_side()

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


func _request_action_ai_move() -> void:
	## Request AI to make a move in action mode (doesn't check turn)
	if ai == null or _ai_calculating:
		return

	_ai_calculating = true
	ai_thinking_started.emit()

	# Calculate and execute AI move (simplified for action mode)
	var move := _calculate_action_ai_move()

	_ai_calculating = false
	ai_thinking_finished.emit()

	# Execute the move
	if move.has("from") and move.has("to"):
		var from: Vector2i = move["from"]
		var to: Vector2i = move["to"]
		if from != Vector2i(-1, -1):
			var success := try_move(from, to)
			if success:
				ai_move_made.emit({"type": "move", "from": from, "to": to})


func _calculate_action_ai_move() -> Dictionary:
	## Quick AI move calculation for action mode (no threading for responsiveness)
	var all_moves := []
	for row in range(8):
		for col in range(8):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece and piece.side == ai_side:
				var piece_moves := board.get_legal_moves(pos)
				for target in piece_moves:
					all_moves.append({"from": pos, "to": target})

	if all_moves.is_empty():
		return {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1)}

	# Simple evaluation: prioritize captures, then center control
	var best_move: Dictionary = all_moves[0]
	var best_score := -INF

	for move in all_moves:
		var score := 0.0
		var target_piece := board.get_piece(move["to"])
		if target_piece:
			# Capture bonus based on piece value
			score += _get_piece_value(target_piece.type) * 10
		# Center control bonus
		var center_dist := absf(move["to"].x - 3.5) + absf(move["to"].y - 3.5)
		score -= center_dist

		if score > best_score:
			best_score = score
			best_move = move

	return best_move


func _get_piece_value(piece_type: int) -> float:
	## Get relative piece value for AI evaluation
	match piece_type:
		Piece.Type.PAWN: return 1.0
		Piece.Type.KNIGHT: return 3.0
		Piece.Type.BISHOP: return 3.0
		Piece.Type.ROOK: return 5.0
		Piece.Type.QUEEN: return 9.0
		Piece.Type.KING: return 100.0
	return 0.0


func request_ai_move() -> void:
	## Request the AI to make a move (call this after ai_turn_started)
	## AI will EITHER place a piece OR make a move (not both!)
	## Uses background thread on native platforms, async on web
	if not is_ai_turn():
		print("[DEBUG] request_ai_move: not AI's turn!")
		return

	if _ai_calculating:
		print("[DEBUG] request_ai_move: already calculating!")
		return

	_ai_calculating = true
	ai_thinking_started.emit()

	var move: Dictionary

	# Web builds don't support threads reliably - use async approach
	if OS.has_feature("web"):
		move = await ai.get_best_move_async(self)
	else:
		# Native: use background thread to keep UI completely responsive
		# Create a snapshot of the game state for the thread
		var board_data := board.to_dict()
		var arrival_data := arrival_manager.to_dict()
		var ai_side_copy := ai_side

		# Start AI calculation in background thread
		var ai_difficulty_copy: int = ai.difficulty
		var ai_max_depth_copy: int = ai.max_depth
		_ai_thread = Thread.new()
		_ai_thread.start(_calculate_ai_move_threaded.bind(board_data, arrival_data, ai_side_copy, ai_difficulty_copy, ai_max_depth_copy))

		# Poll for completion without blocking (with watchdog)
		var watchdog_frames := 0
		while _ai_thread.is_alive():
			await Engine.get_main_loop().process_frame
			watchdog_frames += 1
			if watchdog_frames > 600:  # ~10s at 60fps
				push_warning("[AI] Watchdog: thread still alive after 10s, breaking poll loop")
				break

		# Get result and clean up thread
		_ai_thread.wait_to_finish()
		_ai_thread = null
		move = _ai_result

	_ai_calculating = false
	ai_thinking_finished.emit()

	# Fallback if AI returned empty or invalid result
	if move.is_empty() \
			or (move.has("from") and move["from"] == Vector2i(-1, -1) and not move.has("column")) \
			or (move.has("column") and move["column"] < 0 and not move.has("from")):
		push_warning("[AI] Empty or invalid result, using fallback move")
		move = _get_fallback_move()

	# Execute the move
	if move.has("column") and move["column"] >= 0:
		var column: int = move["column"]
		var placed := try_place_piece(column)
		if placed:
			print("[DEBUG] AI placed at column %d" % column)
			ai_move_made.emit({"type": "placement", "column": column})
		else:
			push_warning("[AI] Placement at column %d failed, trying fallback move" % column)
			move = _get_fallback_move()
			if move.has("from") and move["from"] != Vector2i(-1, -1):
				try_move(move["from"], move["to"])
				ai_move_made.emit({"type": "move", "from": move["from"], "to": move["to"]})
	elif move.has("from") and move.has("to"):
		var from: Vector2i = move["from"]
		var to: Vector2i = move["to"]
		if from != Vector2i(-1, -1):
			var success := try_move(from, to)
			if success:
				print("[DEBUG] AI moved %s -> %s" % [from, to])
				ai_move_made.emit({"type": "move", "from": from, "to": to})
			else:
				push_warning("[AI] Move %s -> %s failed, trying fallback" % [from, to])
				move = _get_fallback_move()
				if move.has("column") and move["column"] >= 0:
					try_place_piece(move["column"])
					ai_move_made.emit({"type": "placement", "column": move["column"]})
				elif move.has("from") and move["from"] != Vector2i(-1, -1):
					try_move(move["from"], move["to"])
					ai_move_made.emit({"type": "move", "from": move["from"], "to": move["to"]})
		else:
			push_warning("[AI] No valid move found!")
	else:
		push_warning("[AI] Unexpected move format: %s" % move)


func _calculate_ai_move_threaded(board_data: Dictionary, arrival_data: Dictionary, ai_side_val: int, ai_difficulty_val: int, ai_max_depth_val: int) -> void:
	## Runs in background thread - calculates AI move using copied data
	# Reconstruct board and arrival manager from snapshots
	var thread_board := Board.from_dict(board_data)
	var thread_arrival := PieceArrivalManager.from_dict(arrival_data)

	# Create AI for this thread with copied settings
	var thread_ai := ChessAIClass.new(ai_side_val, ai_difficulty_val)
	thread_ai.max_depth = ai_max_depth_val

	# Check for piece placement first
	var arriving := thread_arrival.get_current_piece(ai_side_val)
	if arriving != null:
		_ai_result = _calculate_placement_threaded(thread_board, thread_arrival, thread_ai, ai_side_val)
		# If placement failed (back row full), fall back to regular move
		if _ai_result.get("column", -1) < 0:
			_ai_result = _calculate_move_threaded(thread_board, thread_ai)
	else:
		_ai_result = _calculate_move_threaded(thread_board, thread_ai)


func _calculate_placement_threaded(thread_board: Board, thread_arrival: PieceArrivalManager, thread_ai: ChessAI, ai_side_val: int) -> Dictionary:
	## Calculate best placement column (runs in thread)
	var best_column := -1
	var best_score := -INF
	var back_row := 0 if ai_side_val == Piece.Side.WHITE else 7
	var arriving := thread_arrival.get_current_piece(ai_side_val)

	for col in range(8):
		var pos := Vector2i(col, back_row)
		# Use can_place_piece_at for proper bishop rule check
		if not thread_board.can_place_piece_at(pos, arriving):
			continue

		# Simple placement evaluation
		var score := _evaluate_placement_pos(thread_board, pos, arriving, ai_side_val)
		if score > best_score:
			best_score = score
			best_column = col

	return {"column": best_column}


func _evaluate_placement_pos(thread_board: Board, pos: Vector2i, piece: Piece, ai_side_val: int) -> float:
	## Simple placement evaluation for threaded calculation
	var score := 0.0
	var center_dist: float = abs(pos.x - 3.5)

	# Prefer center for most pieces
	score -= center_dist * 10

	# Piece-specific bonuses
	match piece.type:
		Piece.Type.ROOK:
			if pos.x == 0 or pos.x == 7:
				score += 20  # Corners for rooks
		Piece.Type.KING:
			if pos.x >= 2 and pos.x <= 5:
				score += 30  # Protected area for king

	# Penalty if square is attacked
	var opponent := Piece.Side.BLACK if ai_side_val == Piece.Side.WHITE else Piece.Side.WHITE
	if thread_board.is_square_attacked(pos, ai_side_val):
		score -= piece.type * 50  # Use type as rough value proxy

	return score


func _calculate_move_threaded(thread_board: Board, thread_ai: ChessAI) -> Dictionary:
	## Calculate best move using minimax (runs in thread)
	var all_moves := []
	for row in range(8):
		for col in range(8):
			var pos := Vector2i(col, row)
			var piece := thread_board.get_piece(pos)
			if piece and piece.side == thread_ai.side:
				var piece_moves := thread_board.get_legal_moves(pos)
				for target in piece_moves:
					all_moves.append({"from": pos, "to": target})

	if all_moves.is_empty():
		return {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1)}

	all_moves.shuffle()

	var best_move: Dictionary = all_moves[0]
	var best_score := -INF
	var alpha := -INF
	var beta := INF

	for move in all_moves:
		var score := thread_ai._minimax(thread_board, move["from"], move["to"],
									   thread_ai.max_depth - 1, alpha, beta, false)
		if score > best_score:
			best_score = score
			best_move = move
		alpha = max(alpha, score)

	return best_move


func _get_fallback_move() -> Dictionary:
	## Returns a simple legal move for the AI side when the main search fails
	# Check placement first
	var arriving := arrival_manager.get_current_piece(ai_side)
	if arriving != null:
		var back_row := 0 if ai_side == Piece.Side.WHITE else 7
		for col in range(Board.BOARD_SIZE):
			if board.can_place_piece_at(Vector2i(col, back_row), arriving):
				return {"column": col}

	# Return first legal move
	for row in range(Board.BOARD_SIZE):
		for col in range(Board.BOARD_SIZE):
			var pos := Vector2i(col, row)
			var piece := board.get_piece(pos)
			if piece and piece.side == ai_side:
				var moves := board.get_legal_moves(pos)
				if moves.size() > 0:
					return {"from": pos, "to": moves[0]}

	return {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1)}


func _on_ai_progress(percent: float) -> void:
	ai_progress.emit(percent)


func _process_piece_arrival() -> void:
	## Check if a piece should arrive this turn
	var should_arrive := arrival_manager.should_piece_arrive(current_player, move_count)
	if should_arrive:
		arrival_manager.queue_next_piece(current_player)


func _update_game_status() -> void:
	var opponent := Piece.Side.BLACK if current_player == Piece.Side.WHITE else Piece.Side.WHITE

	# In Action mode, skip draw detection - game continues until king is captured
	# (pieces keep arriving, so repetition/50-move draws don't apply)
	if game_mode != GameMode.ACTION:
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
	var guard := 0
	while board.is_valid_position(check):
		guard += 1
		if guard > Board.BOARD_SIZE:
			push_warning("_find_first_piece_in_direction: iteration guard hit")
			break
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


# ─────────────────────────────────────────────────────────────────────────────
# Chess Clock Management
# ─────────────────────────────────────────────────────────────────────────────

func has_clock() -> bool:
	## Returns true if game has time control
	return chess_clock != null


func tick_clock(delta: float) -> void:
	## Update clock - call this from game loop
	if chess_clock and is_game_in_progress():
		chess_clock.tick(delta)


func is_game_in_progress() -> bool:
	## Returns true if game is still being played
	return status == Status.PLAYING or status == Status.CHECK


func get_time_remaining(side: int) -> float:
	## Get remaining time for a side (returns -1 if no clock)
	if chess_clock:
		return chess_clock.get_time_remaining(side)
	return -1.0


func pause_clock() -> void:
	## Pause the chess clock
	if chess_clock:
		chess_clock.pause()


func resume_clock() -> void:
	## Resume the chess clock
	if chess_clock:
		chess_clock.resume()


func to_dict() -> Dictionary:
	## Serialize game state for save/load
	var data := {
		"board": board.to_dict(),
		"current_player": current_player,
		"move_count": move_count,
		"status": status,
		"game_mode": game_mode,
		"arrival_manager": arrival_manager.to_dict(),
		"move_history": move_history,
		"history_index": history_index,
		"draw_detector": draw_detector.to_dict(),
		"draw_reason": draw_reason,
		"time_control_preset": time_control_preset
	}
	if chess_clock:
		data["chess_clock"] = chess_clock.to_dict()
	return data


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
	state.time_control_preset = data.get("time_control_preset", "")
	if data.has("chess_clock"):
		state.chess_clock = ChessClock.from_dict(data["chess_clock"])
		state._connect_clock_signals()
	state._connect_board_signals()
	return state
