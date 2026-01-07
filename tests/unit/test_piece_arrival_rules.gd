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

	# Turn 1 White: Places piece (turn ends)
	game.try_place_piece(4)
	assert_eq(game.current_player, Piece.Side.BLACK, "Placing ends turn")

	# Turn 1 Black: Places piece (turn ends)
	game.try_place_piece(4)
	assert_eq(game.current_player, Piece.Side.WHITE, "Placing ends turn")

	# Turn 2 White: No piece, must move
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(4, 0), Vector2i(4, 1))

	# Turn 2 Black: No piece, must move
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK))
	game.try_move(Vector2i(4, 7), Vector2i(4, 6))

	# Turn 3 White: Should NOT have piece yet (only 1 move made, need 2)
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

	# Turn 1: Both place (placing ends turn)
	game.try_place_piece(4)  # White places, turn ends
	game.try_place_piece(4)  # Black places, turn ends

	# Turn 2: No piece, both move (move 1)
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK))
	game.try_move(Vector2i(4, 7), Vector2i(4, 6))

	# Turn 3: No piece yet (1 move < 2), both move (move 2)
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(4, 1), Vector2i(4, 2))
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK))
	game.try_move(Vector2i(4, 6), Vector2i(4, 5))

	# Turn 4: White made 2 moves, should get new piece!
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

	# === TURN 1 (White) - has piece, places it ===
	assert_eq(game.current_player, Piece.Side.WHITE, "White starts")
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "White has piece")

	game.try_place_piece(4)
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "Piece was placed")
	assert_eq(game.current_player, Piece.Side.BLACK, "Placing ends turn - now Black's turn")

	# === TURN 1 (Black) - has piece, places it ===
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK), "Black has piece")

	game.try_place_piece(4)
	assert_eq(game.current_player, Piece.Side.WHITE, "Placing ends turn - now White's turn")

	# === TURN 2 (White) - no piece, must move ===
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "No piece yet (0 moves)")
	assert_eq(game.arrival_manager.white_moves_made, 0)

	game.try_move(Vector2i(4, 0), Vector2i(4, 2))  # Double pawn move
	assert_eq(game.current_player, Piece.Side.BLACK, "Now Black's turn after move")
	assert_eq(game.arrival_manager.white_moves_made, 1)

	# === TURN 2 (Black) - no piece, must move ===
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK), "No piece yet (0 moves)")

	game.try_move(Vector2i(4, 7), Vector2i(4, 5))  # Double pawn move
	assert_eq(game.current_player, Piece.Side.WHITE, "Now White's turn")

	# === TURN 3 (White) - no piece yet (1 move < 2) ===
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "No piece yet (1 move)")
	assert_eq(game.arrival_manager.white_moves_made, 1)

	game.try_move(Vector2i(4, 2), Vector2i(4, 3))
	assert_eq(game.current_player, Piece.Side.BLACK)
	assert_eq(game.arrival_manager.white_moves_made, 2)

	# === TURN 3 (Black) - no piece yet (1 move < 2) ===
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK), "No piece yet (1 move)")

	game.try_move(Vector2i(4, 5), Vector2i(4, 4))
	assert_eq(game.current_player, Piece.Side.WHITE)

	# === TURN 4 (White) - should have piece! (2 moves >= 1*2) ===
	assert_eq(game.arrival_manager.white_moves_made, 2)
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE), "White gets piece after 2 moves!")


func test_alternating_piece_arrivals() -> void:
	# Test that pieces continue arriving every N moves
	# With new turn logic: placing ends turn, moving ends turn (separate actions)
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	var white_pieces_received := 0
	var black_pieces_received := 0

	# Play until both have received 3 pieces (or max 20 iterations for safety)
	for iteration in range(20):
		var current := game.current_player
		var has_piece := game.arrival_manager.get_current_piece(current) != null

		if has_piece:
			if current == Piece.Side.WHITE:
				white_pieces_received += 1
			else:
				black_pieces_received += 1
			# Place on different columns to avoid collision
			var col := (iteration % 8)
			game.try_place_piece(col)
			# Placing ends the turn, continue to next iteration
			continue

		# No piece to place - make a move (find any piece that can move)
		for r in range(8):
			for c in range(8):
				var pos := Vector2i(c, r)
				var piece := game.board.get_piece(pos)
				if piece and piece.side == current:
					var moves := game.board.get_legal_moves(pos)
					if moves.size() > 0:
						game.try_move(pos, moves[0])
						break
			else:
				continue
			break

		# Check if both have 3 pieces
		if white_pieces_received >= 3 and black_pieces_received >= 3:
			break

	# With frequency=2:
	# Piece 1 arrives immediately (0 moves >= 0*2)
	# Piece 2 arrives after 2 moves (2 >= 1*2)
	# Piece 3 arrives after 4 moves (4 >= 2*2)
	assert_eq(white_pieces_received, 3, "White should receive 3 pieces")
	assert_eq(black_pieces_received, 3, "Black should receive 3 pieces")


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

	# Turn 1: White places (turn ends)
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_place_piece(0)

	# Turn 2: Black places (turn ends)
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK))
	game.try_place_piece(0)

	# Turn 3: White has no piece yet (0 moves, need 1)
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(0, 0), Vector2i(0, 1))

	# Turn 4: Black has no piece yet (0 moves, need 1)
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK))
	game.try_move(Vector2i(0, 7), Vector2i(0, 6))

	# Turn 5: White should have piece (1 move made, frequency=1)
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE),
		"Should have piece every turn with frequency=1")


func test_frequency_3_piece_every_third_turn() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 3,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# Turn 1: Both place (placing ends turn)
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_place_piece(0)  # White places, turn ends
	assert_not_null(game.arrival_manager.get_current_piece(Piece.Side.BLACK))
	game.try_place_piece(0)  # Black places, turn ends

	# Turn 2: no piece (0 moves < 3), both move
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(0, 0), Vector2i(0, 1))
	game.try_move(Vector2i(0, 7), Vector2i(0, 6))

	# Turn 3: no piece (1 move < 3), both move
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(0, 1), Vector2i(0, 2))
	game.try_move(Vector2i(0, 6), Vector2i(0, 5))

	# Turn 4: no piece (2 moves < 3), both move
	assert_null(game.arrival_manager.get_current_piece(Piece.Side.WHITE))
	game.try_move(Vector2i(0, 2), Vector2i(0, 3))
	game.try_move(Vector2i(0, 5), Vector2i(0, 4))

	# Turn 5: piece arrives! (3 moves >= 1*3)
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

	game.try_place_piece(4)  # White places (turn ends)
	assert_eq(game.arrival_manager.white_pieces_given, 1)
	assert_eq(game.current_player, Piece.Side.BLACK, "Turn ended after placement")

	game.try_place_piece(4)  # Black places (turn ends)
	assert_eq(game.arrival_manager.black_pieces_given, 1)
	assert_eq(game.current_player, Piece.Side.WHITE, "Turn ended after placement")


func test_moves_made_increments_on_move_not_placement() -> void:
	var game := GameState.new()
	game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	assert_eq(game.arrival_manager.white_moves_made, 0)

	# Turn 1: White places (placing doesn't count as move, ends turn)
	game.try_place_piece(4)
	assert_eq(game.arrival_manager.white_moves_made, 0, "Placing doesn't count as move")
	assert_eq(game.current_player, Piece.Side.BLACK)

	# Turn 1: Black places (ends turn)
	game.try_place_piece(4)
	assert_eq(game.current_player, Piece.Side.WHITE)

	# Turn 2: White moves (this IS the move)
	game.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_eq(game.arrival_manager.white_moves_made, 1, "Moving increments moves_made")


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
