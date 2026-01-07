extends GutTest
## Tests for game flow and piece arrival system


var game_state: GameState


func before_each() -> void:
	game_state = GameState.new()
	game_state.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER  # No AI for testing
	})


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

	# Should still be White's turn - they need to make a move
	assert_eq(game_state.current_player, Piece.Side.WHITE)

	# White can now move their placed piece
	var pawn := game_state.board.get_piece(Vector2i(4, 0))
	assert_not_null(pawn, "Pawn should be on board")
	var moves := game_state.board.get_legal_moves(Vector2i(4, 0))
	assert_gt(moves.size(), 0, "Pawn should have legal moves")


func test_place_then_move_full_turn() -> void:
	# White places piece
	game_state.try_place_piece(4)  # e1
	assert_eq(game_state.current_player, Piece.Side.WHITE, "Still White's turn after placing")

	# White moves the placed piece
	var move_success := game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_true(move_success, "White should be able to move pawn")

	# Now it's Black's turn
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black should have a piece to place
	var black_arriving := game_state.arrival_manager.get_current_piece(Piece.Side.BLACK)
	assert_not_null(black_arriving, "Black should have piece to place")

	# Black places
	game_state.try_place_piece(4)  # e8
	assert_eq(game_state.current_player, Piece.Side.BLACK, "Still Black's turn after placing")

	# Black moves
	move_success = game_state.try_move(Vector2i(4, 7), Vector2i(4, 6))
	assert_true(move_success, "Black should be able to move pawn")

	# Now White's turn again
	assert_eq(game_state.current_player, Piece.Side.WHITE)


func test_move_does_not_trigger_immediate_arrival() -> void:
	# White places and moves (full turn)
	game_state.try_place_piece(4)  # White e1
	game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))  # White moves

	# Black places and moves (full turn)
	game_state.try_place_piece(4)  # Black e8
	game_state.try_move(Vector2i(4, 7), Vector2i(4, 6))  # Black moves

	# Now White's turn - should NOT have a new piece (only 1 move made, need 2)
	var white_arriving := game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_null(white_arriving, "White should NOT have a new piece after just 1 move")

	# Check moves made
	assert_eq(game_state.arrival_manager.white_moves_made, 1)
	assert_eq(game_state.arrival_manager.black_moves_made, 1)


func test_arrival_after_frequency_moves() -> void:
	# Turn 1: White places and moves
	game_state.try_place_piece(4)  # White e1
	game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))

	# Turn 1: Black places and moves
	game_state.try_place_piece(4)  # Black e8
	game_state.try_move(Vector2i(4, 7), Vector2i(4, 6))

	# Turn 2: White has no new piece yet (only 1 move), just moves
	var white_arriving := game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_null(white_arriving, "White should NOT have piece after 1 move")
	game_state.try_move(Vector2i(4, 1), Vector2i(4, 2))

	# Turn 2: Black has no new piece yet (only 1 move), just moves
	var black_arriving := game_state.arrival_manager.get_current_piece(Piece.Side.BLACK)
	assert_null(black_arriving, "Black should NOT have piece after 1 move")
	game_state.try_move(Vector2i(4, 6), Vector2i(4, 5))

	# Turn 3: White made 2 moves, should get a new piece!
	white_arriving = game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_not_null(white_arriving, "White SHOULD have piece after 2 moves")


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

	# White places (doesn't switch turn)
	game_state.try_place_piece(4)
	assert_eq(game_state.arrival_manager.white_pieces_given, 1)
	assert_eq(game_state.arrival_manager.black_pieces_given, 0)

	# White moves (switches turn to Black)
	game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))

	# Black places
	game_state.try_place_piece(4)
	assert_eq(game_state.arrival_manager.white_pieces_given, 1)
	assert_eq(game_state.arrival_manager.black_pieces_given, 1)


func test_moves_made_tracking() -> void:
	# White places and moves
	game_state.try_place_piece(4)  # White places
	assert_eq(game_state.arrival_manager.white_moves_made, 0)

	game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))  # White moves
	assert_eq(game_state.arrival_manager.white_moves_made, 1)
	assert_eq(game_state.arrival_manager.black_moves_made, 0)

	# Black places and moves
	game_state.try_place_piece(4)  # Black places
	assert_eq(game_state.arrival_manager.black_moves_made, 0)

	game_state.try_move(Vector2i(4, 7), Vector2i(4, 6))  # Black moves
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


func test_vs_ai_after_white_turn() -> void:
	var ai_game := GameState.new()
	ai_game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.VS_AI,
		"ai_side": Piece.Side.BLACK,
		"ai_difficulty": 0  # EASY for faster test
	})

	# White places - still White's turn
	ai_game.try_place_piece(4)
	assert_eq(ai_game.current_player, Piece.Side.WHITE, "Still White's turn after placing")
	assert_false(ai_game.is_ai_turn())

	# White moves - now Black's turn
	ai_game.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_eq(ai_game.current_player, Piece.Side.BLACK)
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

	# White's turn: place and move
	ai_game.try_place_piece(4)  # Place pawn at e1
	assert_eq(ai_game.current_player, Piece.Side.WHITE, "Still White's turn after placing")

	ai_game.try_move(Vector2i(4, 0), Vector2i(4, 1))  # Move pawn
	assert_eq(ai_game.current_player, Piece.Side.BLACK, "Now Black's turn after move")

	# Black (AI) should have a piece to place
	var black_arriving := ai_game.arrival_manager.get_current_piece(Piece.Side.BLACK)
	assert_not_null(black_arriving, "Black should have piece to place")

	# Simulate AI turn: place and move
	ai_game.try_place_piece(4)  # Black places at e8
	assert_eq(ai_game.current_player, Piece.Side.BLACK, "Still Black's turn after placing")

	ai_game.try_move(Vector2i(4, 7), Vector2i(4, 6))  # Black moves
	assert_eq(ai_game.current_player, Piece.Side.WHITE, "Now White's turn")

	# White should NOT have a new piece yet (only 1 move made, need 2)
	var white_arriving := ai_game.arrival_manager.get_current_piece(Piece.Side.WHITE)
	assert_null(white_arriving, "White should NOT have piece after just 1 move")

	# White can move again (no piece to place)
	var moves := ai_game.board.get_legal_moves(Vector2i(4, 1))
	assert_gt(moves.size(), 0, "White pawn should have moves")


func test_ai_can_move_after_placement() -> void:
	# Verify AI logic handles place+move in same turn
	var ai_game := GameState.new()
	ai_game.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.VS_AI,
		"ai_side": Piece.Side.BLACK,
		"ai_difficulty": 0
	})

	# White's full turn: place + move
	ai_game.try_place_piece(4)  # Place at e1
	ai_game.try_move(Vector2i(4, 0), Vector2i(4, 1))  # Move to e2

	# Now it's Black's turn - Black has piece to place
	assert_eq(ai_game.current_player, Piece.Side.BLACK)
	assert_true(ai_game.is_ai_turn())

	var black_arriving := ai_game.arrival_manager.get_current_piece(Piece.Side.BLACK)
	assert_not_null(black_arriving, "Black should have piece to place")

	# Simulate AI placing
	ai_game.try_place_piece(4)  # Place at e8

	# Still Black's turn - now needs to move
	assert_eq(ai_game.current_player, Piece.Side.BLACK)

	# No more piece to place
	black_arriving = ai_game.arrival_manager.get_current_piece(Piece.Side.BLACK)
	assert_null(black_arriving, "Black already placed, no piece to place")

	# Black's pawn at e8 should have legal moves
	var black_pawn := ai_game.board.get_piece(Vector2i(4, 7))
	assert_not_null(black_pawn, "Black pawn should be at e8")

	var black_moves := ai_game.board.get_legal_moves(Vector2i(4, 7))
	assert_gt(black_moves.size(), 0, "Black pawn should have legal moves")

	# Test that AI returns a valid move (not placement since already placed)
	var ai_move: Dictionary = ai_game.ai.get_best_move(ai_game)
	assert_true(ai_move.has("from"), "AI should return a move with 'from'")
	assert_true(ai_move.has("to"), "AI should return a move with 'to'")
	assert_ne(ai_move["from"], Vector2i(-1, -1), "AI should find a valid move")

	# Execute the AI's move
	var move_success := ai_game.try_move(ai_move["from"], ai_move["to"])
	assert_true(move_success, "AI's move should be valid")

	# Should be White's turn now
	assert_eq(ai_game.current_player, Piece.Side.WHITE)
