extends GutTest
## Tests for game flow and piece arrival system
##
## CORRECT TURN LOGIC:
## - If you have a piece to place AND there's space → you MUST place it (turn ends)
## - If you don't have a piece to place OR no space → you move any piece (turn ends)
## - Placing IS the turn, not a precursor to moving


var game_state: GameState


func before_each() -> void:
	game_state = GameState.new()
	game_state.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER  # No AI for testing
	})


# ============================================================================
# CORRECT TURN LOGIC TESTS
# ============================================================================

func test_placing_piece_ends_turn() -> void:
	## Placing a piece should END the turn - no move allowed after
	assert_eq(game_state.current_player, Piece.Side.WHITE)

	# White places piece - turn should END
	var success := game_state.try_place_piece(4)
	assert_true(success, "Should be able to place piece")

	# Should now be BLACK's turn (not still White's!)
	assert_eq(game_state.current_player, Piece.Side.BLACK,
		"Placing a piece should end the turn")


func test_move_ends_turn_when_no_piece_to_place() -> void:
	## When no piece to place, moving should end the turn
	# First, let's get to a state where white has no piece to place
	# White places (ends turn)
	game_state.try_place_piece(4)
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black places (ends turn)
	game_state.try_place_piece(4)
	assert_eq(game_state.current_player, Piece.Side.WHITE)

	# White has no new piece yet (frequency=2, only 0 moves made)
	var arriving := game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_null(arriving, "White should NOT have a piece (0 moves made, need 2)")

	# White moves the placed pawn
	var move_success := game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_true(move_success, "White should be able to move")

	# Turn should end
	assert_eq(game_state.current_player, Piece.Side.BLACK)


func test_cannot_move_after_placing() -> void:
	## After placing a piece, the turn is over - cannot move
	game_state.try_place_piece(4)  # White places, turn ends

	# Now it's Black's turn, so White's move should fail
	var move_success := game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_false(move_success, "White cannot move after placing - turn is over")


func test_alternating_place_turns() -> void:
	## Each player places on their turn, alternating
	# White places (turn 1)
	game_state.try_place_piece(3)  # d1
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black places (turn 2)
	game_state.try_place_piece(3)  # d8
	assert_eq(game_state.current_player, Piece.Side.WHITE)

	# White has no piece yet (0 moves, need 2 for next piece)
	var white_piece := game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_null(white_piece)

	# White moves (turn 3)
	game_state.try_move(Vector2i(3, 0), Vector2i(3, 1))
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black has no piece yet (0 moves, need 2)
	var black_piece := game_state.arrival_manager.get_current_piece(Piece.Side.BLACK)
	assert_null(black_piece)

	# Black moves (turn 4)
	game_state.try_move(Vector2i(3, 7), Vector2i(3, 6))
	assert_eq(game_state.current_player, Piece.Side.WHITE)


func test_new_piece_arrives_after_frequency_moves() -> void:
	## After N moves (frequency), a new piece should arrive
	# White places (turn ends, 0 moves)
	game_state.try_place_piece(4)

	# Black places (turn ends, 0 moves)
	game_state.try_place_piece(4)

	# White moves (1 move)
	game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))

	# Black moves (1 move)
	game_state.try_move(Vector2i(4, 7), Vector2i(4, 6))

	# White moves again (2 moves total)
	game_state.try_move(Vector2i(4, 1), Vector2i(4, 2))

	# Black moves again (2 moves total)
	game_state.try_move(Vector2i(4, 6), Vector2i(4, 5))

	# Now White should have a new piece (2 moves made, frequency=2)
	var white_piece := game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_not_null(white_piece, "White should have new piece after 2 moves")


# ============================================================================
# LEGACY TESTS (updated to match correct behavior)
# ============================================================================


func test_initial_state() -> void:
	# White should have a piece to place
	var arriving := game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_not_null(arriving, "White should have a piece to place initially")
	assert_eq(arriving.type, Piece.Type.PAWN, "First piece should be a pawn")
	assert_eq(game_state.current_player, Piece.Side.WHITE)


func test_place_first_piece() -> void:
	# Place white's first piece
	var success := game_state.try_place_piece(4)  # e1
	assert_true(success, "Should be able to place piece")

	# White's current piece should be cleared
	var white_arriving := game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_null(white_arriving, "White should not have a piece to place after placing")

	# Should be Black's turn now (placing ends the turn!)
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# The pawn should be on the board
	var pawn := game_state.board.get_piece(Vector2i(4, 0))
	assert_not_null(pawn, "Pawn should be on board")


func test_arrival_manager_should_piece_arrive() -> void:
	var manager := PieceArrivalManager.new()
	manager.initialize(PieceArrivalManager.Mode.FIXED, 2)

	# First piece should arrive immediately (pieces_given = 0)
	assert_true(manager.should_piece_arrive(Piece.Side.WHITE, 0),
		"First piece should arrive")

	# Simulate placing the first piece
	manager.queue_next_piece(Piece.Side.WHITE)
	manager.piece_placed(Piece.Side.WHITE)

	# Now pieces_given = 1, moves_made = 0
	# Should NOT arrive yet
	assert_false(manager.should_piece_arrive(Piece.Side.WHITE, 0),
		"Should not arrive with 0 moves")

	# Simulate 1 move
	manager.record_move(Piece.Side.WHITE)
	assert_false(manager.should_piece_arrive(Piece.Side.WHITE, 1),
		"Should not arrive after 1 move (frequency=2)")

	# Simulate 2nd move
	manager.record_move(Piece.Side.WHITE)
	assert_true(manager.should_piece_arrive(Piece.Side.WHITE, 2),
		"SHOULD arrive after 2 moves (frequency=2)")


func test_pieces_given_tracking() -> void:
	assert_eq(game_state.arrival_manager.white_pieces_given, 0)
	assert_eq(game_state.arrival_manager.black_pieces_given, 0)

	# White places (NOW switches turn!)
	game_state.try_place_piece(4)
	assert_eq(game_state.arrival_manager.white_pieces_given, 1)
	assert_eq(game_state.arrival_manager.black_pieces_given, 0)
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black places (switches turn)
	game_state.try_place_piece(4)
	assert_eq(game_state.arrival_manager.white_pieces_given, 1)
	assert_eq(game_state.arrival_manager.black_pieces_given, 1)
	assert_eq(game_state.current_player, Piece.Side.WHITE)


func test_moves_made_tracking() -> void:
	# White places (turn ends)
	game_state.try_place_piece(4)
	assert_eq(game_state.arrival_manager.white_moves_made, 0)

	# Black places (turn ends)
	game_state.try_place_piece(4)
	assert_eq(game_state.arrival_manager.black_moves_made, 0)

	# White moves (no piece to place)
	game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_eq(game_state.arrival_manager.white_moves_made, 1)
	assert_eq(game_state.arrival_manager.black_moves_made, 0)

	# Black moves (no piece to place)
	game_state.try_move(Vector2i(4, 7), Vector2i(4, 6))
	assert_eq(game_state.arrival_manager.white_moves_made, 1)
	assert_eq(game_state.arrival_manager.black_moves_made, 1)


# VS_AI mode tests

func test_vs_ai_mode_initial_state() -> void:
	# Create new game with AI
	var ai_game := GameState.new()
	ai_game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.VS_AI,
		"ai_side": Piece.Side.BLACK,
		"ai_difficulty": 1  # MEDIUM
	})

	# White should start
	assert_eq(ai_game.current_player, Piece.Side.WHITE)

	# White should have piece to place
	var arriving := ai_game.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_not_null(arriving)

	# AI should be initialized
	assert_not_null(ai_game.ai)
	assert_eq(ai_game.ai_side, Piece.Side.BLACK)


func test_vs_ai_after_white_places() -> void:
	var ai_game := GameState.new()
	ai_game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.VS_AI,
		"ai_side": Piece.Side.BLACK,
		"ai_difficulty": 0  # EASY for faster test
	})

	# White places - turn ends, now Black's turn
	ai_game.try_place_piece(4)
	assert_eq(ai_game.current_player, Piece.Side.BLACK, "Black's turn after White places")
	assert_true(ai_game.is_ai_turn())

	# Black should have piece to place
	var black_arriving := ai_game.arrival_manager.get_current_piece(Piece.Side.BLACK)
	assert_not_null(black_arriving, "Black should have piece to place")


func test_vs_ai_full_cycle() -> void:
	var ai_game := GameState.new()
	ai_game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.VS_AI,
		"ai_side": Piece.Side.BLACK,
		"ai_difficulty": 0
	})

	# White places (turn ends)
	ai_game.try_place_piece(4)
	assert_eq(ai_game.current_player, Piece.Side.BLACK, "Black's turn after White places")

	# Black (AI) places (turn ends)
	ai_game.try_place_piece(4)
	assert_eq(ai_game.current_player, Piece.Side.WHITE, "White's turn after Black places")

	# White has no new piece yet (0 moves), so White moves
	var white_arriving := ai_game.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_null(white_arriving, "White should NOT have piece (0 moves)")

	ai_game.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_eq(ai_game.current_player, Piece.Side.BLACK, "Black's turn after White moves")

	# Black has no new piece (0 moves), so Black moves
	var black_arriving := ai_game.arrival_manager.get_current_piece(Piece.Side.BLACK)
	assert_null(black_arriving, "Black should NOT have piece (0 moves)")

	ai_game.try_move(Vector2i(4, 7), Vector2i(4, 6))
	assert_eq(ai_game.current_player, Piece.Side.WHITE, "White's turn after Black moves")
