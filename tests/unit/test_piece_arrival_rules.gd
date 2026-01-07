extends GutTest
## TDD tests for Saktris piece arrival rules
##
## RULES:
## 1. Each player's turn: place piece (if available) → move any piece → turn ends
## 2. First piece arrives immediately at game start
## 3. After first piece, new piece arrives every N moves (arrival_frequency)
## 4. Moves are counted per-player, not globally
## 5. Total 16 pieces per player (8 pawns, 2 knights, 2 bishops, 2 rooks, 1 queen, 1 king)


# =============================================================================
# BASIC ARRIVAL RULES
# =============================================================================

func test_first_piece_arrives_immediately() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# White should have a piece to place on turn 1
	var white_piece := game.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_not_null(white_piece, "White should have first piece immediately")
	assert_eq(white_piece.type, Piece.Type.PAWN, "First piece should be pawn")


func test_no_piece_after_only_one_move() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# Turn 1: White places and moves
	game.try_place_piece(4)
	game.try_move(Vector2i(4, 0), Vector2i(4, 1))

	# Turn 1: Black places and moves
	game.try_place_piece(4)
	game.try_move(Vector2i(4, 7), Vector2i(4, 6))

	# Turn 2: White should NOT have a new piece (only 1 move made, need 2)
	var white_piece := game.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_null(white_piece, "White should NOT have piece after only 1 move (frequency=2)")
	assert_eq(game.arrival_manager.white_moves_made, 1)


func test_piece_arrives_after_frequency_moves() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# Turn 1: Both place and move
	game.try_place_piece(4)  # White
	game.try_move(Vector2i(4, 0), Vector2i(4, 1))
	game.try_place_piece(4)  # Black
	game.try_move(Vector2i(4, 7), Vector2i(4, 6))

	# Turn 2: Both just move (no piece)
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(4, 1), Vector2i(4, 2))
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK))
	game.try_move(Vector2i(4, 6), Vector2i(4, 5))

	# Turn 3: White made 2 moves, should get new piece!
	var white_piece := game.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_not_null(white_piece, "White SHOULD have piece after 2 moves")
	assert_eq(game.arrival_manager.white_moves_made, 2)


# =============================================================================
# FULL GAME FLOW
# =============================================================================

func test_complete_turn_flow() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# === TURN 1 (White) ===
	assert_eq(game.current_player, Piece.Side.WHITE, "White starts")
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "White has piece")

	game.try_place_piece(4)
	assert_eq(game.current_player, Piece.Side.WHITE, "Still White's turn after placing")
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "Piece was placed")

	game.try_move(Vector2i(4, 0), Vector2i(4, 2))  # Double pawn move
	assert_eq(game.current_player, Piece.Side.BLACK, "Now Black's turn after move")

	# === TURN 1 (Black) ===
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK), "Black has piece")

	game.try_place_piece(4)
	assert_eq(game.current_player, Piece.Side.BLACK, "Still Black's turn after placing")

	game.try_move(Vector2i(4, 7), Vector2i(4, 5))  # Double pawn move
	assert_eq(game.current_player, Piece.Side.WHITE, "Now White's turn")

	# === TURN 2 (White) - no new piece yet ===
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "No piece yet (1 move)")
	assert_eq(game.arrival_manager.white_moves_made, 1)

	game.try_move(Vector2i(4, 2), Vector2i(4, 3))
	assert_eq(game.current_player, Piece.Side.BLACK)

	# === TURN 2 (Black) - no new piece yet ===
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK), "No piece yet (1 move)")

	game.try_move(Vector2i(4, 5), Vector2i(4, 4))
	assert_eq(game.current_player, Piece.Side.WHITE)

	# === TURN 3 (White) - should have piece! ===
	assert_eq(game.arrival_manager.white_moves_made, 2)
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "White gets piece after 2 moves!")


func test_alternating_piece_arrivals() -> void:
	# Test that pieces continue arriving every N moves
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	var white_pieces_received := 0
	var black_pieces_received := 0

	# Play 10 turns (5 per player)
	for turn in range(10):
		var current := game.current_player
		var has_piece := game.arrival_manager.get_current_piece(current) != null

		if has_piece:
			if current == Piece.Side.WHITE:
				white_pieces_received += 1
			else:
				black_pieces_received += 1
			# Place on different columns to avoid collision
			var col := (turn % 8)
			var row := 0 if current == Piece.Side.WHITE else 7
			if game.board.is_empty(Vector2i(col, row)):
				game.try_place_piece(col)

		# Make a move (find any piece that can move)
		var moved := false
		for r in range(8):
			for c in range(8):
				var pos := Vector2i(c, r)
				var piece := game.board.get_piece(pos)
				if piece and piece.side == current:
					var moves := game.board.get_legal_moves(pos)
					if moves.size() > 0:
						game.try_move(pos, moves[0])
						moved = true
						break
			if moved:
				break

	# With frequency=2, each player should receive pieces on turns 1, 3, 5...
	# After 5 turns each: turn 1 (piece), turn 2 (no), turn 3 (piece), turn 4 (no), turn 5 (piece)
	# = 3 pieces each
	assert_eq(white_pieces_received, 3, "White should receive 3 pieces in 5 turns (freq=2)")
	assert_eq(black_pieces_received, 3, "Black should receive 3 pieces in 5 turns (freq=2)")


# =============================================================================
# FREQUENCY VARIATIONS
# =============================================================================

func test_frequency_1_piece_every_turn() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 1,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# Turn 1
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_place_piece(0)
	game.try_move(Vector2i(0, 0), Vector2i(0, 1))

	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK))
	game.try_place_piece(0)
	game.try_move(Vector2i(0, 7), Vector2i(0, 6))

	# Turn 2 - should have piece (frequency=1)
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE),
		"Should have piece every turn with frequency=1")


func test_frequency_3_piece_every_third_turn() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 3,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# Turn 1: piece arrives
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_place_piece(0)
	game.try_move(Vector2i(0, 0), Vector2i(0, 1))
	game.try_place_piece(0)
	game.try_move(Vector2i(0, 7), Vector2i(0, 6))

	# Turn 2: no piece (1 move)
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(0, 1), Vector2i(0, 2))
	game.try_move(Vector2i(0, 6), Vector2i(0, 5))

	# Turn 3: no piece (2 moves)
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(0, 2), Vector2i(0, 3))
	game.try_move(Vector2i(0, 5), Vector2i(0, 4))

	# Turn 4: piece arrives! (3 moves)
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE),
		"Should have piece after 3 moves with frequency=3")


# =============================================================================
# PIECES GIVEN TRACKING
# =============================================================================

func test_pieces_given_increments_on_placement() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	assert_eq(game.arrival_manager.white_pieces_given, 0)
	assert_eq(game.arrival_manager.black_pieces_given, 0)

	game.try_place_piece(4)  # White places
	assert_eq(game.arrival_manager.white_pieces_given, 1)

	game.try_move(Vector2i(4, 0), Vector2i(4, 1))  # White moves, turn ends

	game.try_place_piece(4)  # Black places
	assert_eq(game.arrival_manager.black_pieces_given, 1)


func test_moves_made_increments_on_move_not_placement() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	assert_eq(game.arrival_manager.white_moves_made, 0)

	game.try_place_piece(4)  # Place doesn't count as move
	assert_eq(game.arrival_manager.white_moves_made, 0)

	game.try_move(Vector2i(4, 0), Vector2i(4, 1))  # This is the move
	assert_eq(game.arrival_manager.white_moves_made, 1)


# =============================================================================
# EDGE CASES
# =============================================================================

func test_cannot_move_without_placing_first() -> void:
	# If you have a piece to place, you must place it before moving
	# (This is enforced by the UI, but let's verify the state)
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# White has a piece to place
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))

	# White has no pieces on board yet, so can't move anyway
	var all_moves := game.get_legal_moves_for_current_player()
	assert_eq(all_moves.size(), 0, "No moves available without pieces on board")


func test_queue_contains_all_16_pieces() -> void:
	# Verify the queue contains all 16 pieces at start
	var manager := PieceArrivalManager.new()
	manager.initialize(PieceArrivalManager.Mode.FIXED, 2)

	# Count pieces in queue
	var upcoming := manager.get_upcoming_pieces(Piece.Side.WHITE, 100)
	assert_eq(upcoming.size(), 16, "Queue should have 16 pieces")

	# Verify composition: 8 pawns, 2 knights, 2 bishops, 2 rooks, 1 queen, 1 king
	var counts := {}
	for piece_type in upcoming:
		counts[piece_type] = counts.get(piece_type, 0) + 1

	assert_eq(counts.get(Piece.Type.PAWN, 0), 8, "Should have 8 pawns")
	assert_eq(counts.get(Piece.Type.KNIGHT, 0), 2, "Should have 2 knights")
	assert_eq(counts.get(Piece.Type.BISHOP, 0), 2, "Should have 2 bishops")
	assert_eq(counts.get(Piece.Type.ROOK, 0), 2, "Should have 2 rooks")
	assert_eq(counts.get(Piece.Type.QUEEN, 0), 1, "Should have 1 queen")
	assert_eq(counts.get(Piece.Type.KING, 0), 1, "Should have 1 king")
