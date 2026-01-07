extends GutTest
## Tests specifically for game start flow to debug turn logic bug

var game_state: GameState


func before_each() -> void:
	game_state = GameState.new()


func test_game_start_two_player_flow() -> void:
	## Trace through exactly what happens at game start in two-player mode
	print("\n=== GAME START TWO-PLAYER FLOW ===")

	game_state.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	print("After start_new_game:")
	_print_state()

	# White should have a piece to place
	assert_eq(game_state.current_player, Piece.Side.WHITE, "White starts")
	assert_true(game_state.must_place_piece(), "White must place")

	# White places piece at column 4
	print("\n--- White places at column 4 ---")
	var success := game_state.try_place_piece(4)
	assert_true(success, "White placement succeeds")

	print("After White places:")
	_print_state()

	# Now it should be Black's turn with a piece to place
	assert_eq(game_state.current_player, Piece.Side.BLACK, "Black's turn after White places")
	assert_true(game_state.must_place_piece(), "Black must place")

	# Black places piece at column 4
	print("\n--- Black places at column 4 ---")
	success = game_state.try_place_piece(4)
	assert_true(success, "Black placement succeeds")

	print("After Black places:")
	_print_state()

	# Now it should be White's turn with NO piece (frequency=2, 0 moves)
	assert_eq(game_state.current_player, Piece.Side.WHITE, "White's turn after Black places")
	assert_false(game_state.must_place_piece(), "White should NOT have piece (0 moves)")

	# White moves the pawn
	print("\n--- White moves pawn e1 to e2 ---")
	success = game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_true(success, "White move succeeds")

	print("After White moves:")
	_print_state()

	# Now Black's turn with NO piece (frequency=2, 0 moves)
	assert_eq(game_state.current_player, Piece.Side.BLACK, "Black's turn after White moves")
	assert_false(game_state.must_place_piece(), "Black should NOT have piece (0 moves)")

	print("\n=== END FLOW ===")


func test_game_start_vs_ai_flow() -> void:
	## Trace through exactly what happens at game start in VS_AI mode
	print("\n=== GAME START VS_AI FLOW ===")

	game_state.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.VS_AI,
		"ai_side": Piece.Side.BLACK,
		"ai_difficulty": 0  # EASY
	})

	print("After start_new_game:")
	_print_state()

	# White (human) should have a piece to place
	assert_eq(game_state.current_player, Piece.Side.WHITE, "White starts")
	assert_true(game_state.must_place_piece(), "White must place")
	assert_false(game_state.is_ai_turn(), "Not AI's turn")

	# White places piece at column 4
	print("\n--- White places at column 4 ---")
	var success := game_state.try_place_piece(4)
	assert_true(success, "White placement succeeds")

	print("After White places:")
	_print_state()

	# Now it should be Black's (AI) turn with a piece to place
	assert_eq(game_state.current_player, Piece.Side.BLACK, "Black's turn after White places")
	assert_true(game_state.is_ai_turn(), "AI's turn")
	assert_true(game_state.must_place_piece(), "Black (AI) must place")

	# Simulate AI placing
	print("\n--- AI (Black) places ---")
	game_state.request_ai_move()

	print("After AI moves:")
	_print_state()

	# Should now be White's turn again
	assert_eq(game_state.current_player, Piece.Side.WHITE, "White's turn after AI")
	assert_false(game_state.must_place_piece(), "White should NOT have piece")

	print("\n=== END FLOW ===")


func test_no_continuous_placement_after_second_piece() -> void:
	## After placing second piece, should NOT immediately get another
	## This was the bug: pieces kept arriving without moves
	print("\n=== TEST: No continuous placement ===")

	game_state.start_new_game({
		"arrival_mode": PieceArrivalManager.Mode.FIXED,
		"arrival_frequency": 2,
		"game_mode": GameState.GameMode.TWO_PLAYER
	})

	# White places first piece (turn 1)
	game_state.try_place_piece(4)
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black places first piece (turn 2)
	game_state.try_place_piece(4)
	assert_eq(game_state.current_player, Piece.Side.WHITE)

	# White move 1 (turn 3)
	game_state.try_move(Vector2i(4, 0), Vector2i(4, 1))
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black move 1 (turn 4)
	game_state.try_move(Vector2i(4, 7), Vector2i(4, 6))
	assert_eq(game_state.current_player, Piece.Side.WHITE)

	# White move 2 (turn 5)
	game_state.try_move(Vector2i(4, 1), Vector2i(4, 2))
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black move 2 (turn 6) - after this, it's White's turn
	# White has made 2 moves, so White should get a piece
	game_state.try_move(Vector2i(4, 6), Vector2i(4, 5))
	assert_eq(game_state.current_player, Piece.Side.WHITE)

	print("After Black's 2nd move (White's turn):")
	_print_state()

	# White should have a piece (2 moves made since last piece)
	assert_true(game_state.must_place_piece(), "White should have piece after 2 moves")
	assert_eq(game_state.arrival_manager.white_moves_made, 2)
	assert_eq(game_state.arrival_manager.white_pieces_given, 1)

	# White places second piece (turn 7)
	game_state.try_place_piece(3)
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	print("After White places 2nd piece (Black's turn):")
	_print_state()

	# Black should also have a piece now (2 moves made since last piece)
	assert_true(game_state.must_place_piece(),
		"Black should have piece (2 moves made)")
	assert_eq(game_state.arrival_manager.black_moves_made, 2)
	assert_eq(game_state.arrival_manager.black_pieces_given, 1)

	# Black places second piece (turn 8)
	game_state.try_place_piece(3)
	assert_eq(game_state.current_player, Piece.Side.WHITE)

	print("After Black places 2nd piece (White's turn):")
	_print_state()

	# KEY TEST: White should NOT have piece yet!
	# White has 2 moves and 2 pieces_given, needs 4 moves for 3rd piece
	assert_false(game_state.must_place_piece(),
		"White should NOT have piece (2 moves, need 4 for 3rd piece)")
	assert_eq(game_state.arrival_manager.white_pieces_given, 2)
	assert_eq(game_state.arrival_manager.white_moves_made, 2)

	# White move 3 (turn 9)
	game_state.try_move(Vector2i(4, 2), Vector2i(4, 3))
	assert_eq(game_state.current_player, Piece.Side.BLACK)

	# Black should NOT have piece yet (2 moves, 2 pieces_given)
	assert_false(game_state.must_place_piece(),
		"Black should NOT have piece (2 moves, need 4 for 3rd piece)")

	print("=== TEST PASSED ===\n")


func _print_state() -> void:
	var player := "WHITE" if game_state.current_player == Piece.Side.WHITE else "BLACK"
	var white_piece := game_state.arrival_manager.get_current_piece(Piece.Side.WHITE)
	var black_piece := game_state.arrival_manager.get_current_piece(Piece.Side.BLACK)

	print("  current_player: %s" % player)
	print("  must_place_piece: %s" % game_state.must_place_piece())
	print("  is_ai_turn: %s" % game_state.is_ai_turn())
	print("  white_current: %s (pieces_given=%d, moves_made=%d)" % [
		white_piece != null,
		game_state.arrival_manager.white_pieces_given,
		game_state.arrival_manager.white_moves_made
	])
	print("  black_current: %s (pieces_given=%d, moves_made=%d)" % [
		black_piece != null,
		game_state.arrival_manager.black_pieces_given,
		game_state.arrival_manager.black_moves_made
	])
