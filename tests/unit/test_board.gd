extends GutTest
## Unit tests for Board class


var board: Board


func before_each() -> void:
	board = Board.new()


func test_board_starts_empty() -> void:
	for row in range(8):
		for col in range(8):
			assert_null(board.get_piece(Vector2i(col, row)))


func test_place_and_get_piece() -> void:
	var piece := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var pos := Vector2i(4, 0)

	board.set_piece(pos, piece)

	assert_eq(board.get_piece(pos), piece)


func test_is_valid_position() -> void:
	assert_true(board.is_valid_position(Vector2i(0, 0)))
	assert_true(board.is_valid_position(Vector2i(7, 7)))
	assert_true(board.is_valid_position(Vector2i(4, 4)))

	assert_false(board.is_valid_position(Vector2i(-1, 0)))
	assert_false(board.is_valid_position(Vector2i(8, 0)))
	assert_false(board.is_valid_position(Vector2i(0, -1)))
	assert_false(board.is_valid_position(Vector2i(0, 8)))


func test_is_empty() -> void:
	var pos := Vector2i(3, 3)
	assert_true(board.is_empty(pos))

	board.set_piece(pos, Piece.new(Piece.Type.PAWN, Piece.Side.WHITE))
	assert_false(board.is_empty(pos))


func test_is_enemy_and_friendly() -> void:
	var pos := Vector2i(4, 4)
	var white_piece := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	board.set_piece(pos, white_piece)

	assert_true(board.is_friendly(pos, Piece.Side.WHITE))
	assert_false(board.is_friendly(pos, Piece.Side.BLACK))

	assert_true(board.is_enemy(pos, Piece.Side.BLACK))
	assert_false(board.is_enemy(pos, Piece.Side.WHITE))


func test_remove_piece() -> void:
	var pos := Vector2i(2, 2)
	var piece := Piece.new(Piece.Type.BISHOP, Piece.Side.BLACK)
	board.set_piece(pos, piece)

	var removed := board.remove_piece(pos)

	assert_eq(removed, piece)
	assert_null(board.get_piece(pos))


# Movement tests

func test_king_moves() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 4), king)

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# King should have 8 moves from center
	assert_eq(moves.size(), 8)
	assert_has(moves, Vector2i(3, 3))
	assert_has(moves, Vector2i(4, 3))
	assert_has(moves, Vector2i(5, 3))
	assert_has(moves, Vector2i(3, 4))
	assert_has(moves, Vector2i(5, 4))
	assert_has(moves, Vector2i(3, 5))
	assert_has(moves, Vector2i(4, 5))
	assert_has(moves, Vector2i(5, 5))


func test_king_blocked_by_friendly() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 4), king)
	board.set_piece(Vector2i(5, 4), pawn)

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# King should have 7 moves (blocked by friendly pawn)
	assert_eq(moves.size(), 7)
	assert_does_not_have(moves, Vector2i(5, 4))


func test_knight_moves() -> void:
	var knight := Piece.new(Piece.Type.KNIGHT, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 4), knight)

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# Knight should have 8 moves from center
	assert_eq(moves.size(), 8)
	assert_has(moves, Vector2i(2, 3))
	assert_has(moves, Vector2i(3, 2))
	assert_has(moves, Vector2i(5, 2))
	assert_has(moves, Vector2i(6, 3))
	assert_has(moves, Vector2i(6, 5))
	assert_has(moves, Vector2i(5, 6))
	assert_has(moves, Vector2i(3, 6))
	assert_has(moves, Vector2i(2, 5))


func test_knight_corner_moves() -> void:
	var knight := Piece.new(Piece.Type.KNIGHT, Piece.Side.WHITE)
	board.set_piece(Vector2i(0, 0), knight)

	var moves := board.get_legal_moves(Vector2i(0, 0))

	# Knight in corner should have 2 moves
	assert_eq(moves.size(), 2)
	assert_has(moves, Vector2i(1, 2))
	assert_has(moves, Vector2i(2, 1))


func test_rook_moves() -> void:
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 4), rook)

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# Rook should have 14 moves (7 horizontal + 7 vertical)
	assert_eq(moves.size(), 14)


func test_rook_blocked() -> void:
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	var blocker := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 4), rook)
	board.set_piece(Vector2i(4, 2), blocker)

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# Should not be able to move past or onto blocker
	assert_does_not_have(moves, Vector2i(4, 2))
	assert_does_not_have(moves, Vector2i(4, 1))
	assert_does_not_have(moves, Vector2i(4, 0))


func test_bishop_moves() -> void:
	var bishop := Piece.new(Piece.Type.BISHOP, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 4), bishop)

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# Bishop should have 13 moves from e5
	assert_eq(moves.size(), 13)


func test_queen_moves() -> void:
	var queen := Piece.new(Piece.Type.QUEEN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 4), queen)

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# Queen should have 27 moves (14 rook + 13 bishop)
	assert_eq(moves.size(), 27)


func test_pawn_initial_moves() -> void:
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), pawn)  # White's back row

	var moves := board.get_legal_moves(Vector2i(4, 0))

	# Pawn on starting position can move 1 or 2 squares (forward = +Y for white)
	assert_eq(moves.size(), 2)
	assert_has(moves, Vector2i(4, 1))
	assert_has(moves, Vector2i(4, 2))


func test_pawn_after_moving() -> void:
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	pawn.has_moved = true
	board.set_piece(Vector2i(4, 2), pawn)

	var moves := board.get_legal_moves(Vector2i(4, 2))

	# Pawn that has moved can only move 1 square (forward = +Y for white)
	assert_eq(moves.size(), 1)
	assert_has(moves, Vector2i(4, 3))


func test_pawn_capture() -> void:
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	var black_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.BLACK)
	board.set_piece(Vector2i(4, 4), white_pawn)
	board.set_piece(Vector2i(5, 5), black_pawn)  # Diagonal forward (+Y) for white

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# Should be able to capture diagonally forward
	assert_has(moves, Vector2i(5, 5))


func test_find_king() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	board.set_piece(Vector2i(3, 5), king)

	var pos := board.find_king(Piece.Side.WHITE)
	assert_eq(pos, Vector2i(3, 5))

	# No black king
	var black_king_pos := board.find_king(Piece.Side.BLACK)
	assert_eq(black_king_pos, Vector2i(-1, -1))


func test_check_detection() -> void:
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var black_rook := Piece.new(Piece.Type.ROOK, Piece.Side.BLACK)
	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(4, 7), black_rook)

	assert_true(board.is_in_check(Piece.Side.WHITE))
	assert_false(board.is_in_check(Piece.Side.BLACK))


func test_cannot_move_into_check() -> void:
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var black_rook := Piece.new(Piece.Type.ROOK, Piece.Side.BLACK)
	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(5, 7), black_rook)

	var moves := board.get_legal_moves(Vector2i(4, 0))

	# King should not be able to move to e-file (would be check)
	assert_does_not_have(moves, Vector2i(5, 0))
	assert_does_not_have(moves, Vector2i(5, 1))


func test_pawn_promotion_detection() -> void:
	# White pawn on row 6 (one move from promotion)
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	white_pawn.has_moved = true
	board.set_piece(Vector2i(4, 6), white_pawn)

	var result := board.execute_move(Vector2i(4, 6), Vector2i(4, 7))

	assert_true(result["valid"])
	assert_true(result["needs_promotion"])
	assert_eq(result["special"], "promotion")


func test_promote_pawn() -> void:
	# White pawn on promotion row
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 7), white_pawn)

	# Promote to queen
	var success := board.promote_pawn(Vector2i(4, 7), Piece.Type.QUEEN)
	assert_true(success)

	var piece := board.get_piece(Vector2i(4, 7))
	assert_eq(piece.type, Piece.Type.QUEEN)
	assert_eq(piece.side, Piece.Side.WHITE)


func test_promote_pawn_invalid_type() -> void:
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 7), white_pawn)

	# Cannot promote to pawn or king
	var success := board.promote_pawn(Vector2i(4, 7), Piece.Type.PAWN)
	assert_false(success)

	success = board.promote_pawn(Vector2i(4, 7), Piece.Type.KING)
	assert_false(success)


# Castling tests

func test_kingside_castling_available() -> void:
	# Set up king and rook in starting positions
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(7, 0), rook)

	var moves := board.get_legal_moves(Vector2i(4, 0))

	# Should include kingside castling (g1)
	assert_has(moves, Vector2i(6, 0))


func test_queenside_castling_available() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(0, 0), rook)

	var moves := board.get_legal_moves(Vector2i(4, 0))

	# Should include queenside castling (c1)
	assert_has(moves, Vector2i(2, 0))


func test_castling_blocked_by_piece() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	var blocker := Piece.new(Piece.Type.BISHOP, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(7, 0), rook)
	board.set_piece(Vector2i(5, 0), blocker)  # f1 blocks kingside

	var moves := board.get_legal_moves(Vector2i(4, 0))

	# Should NOT include kingside castling
	assert_does_not_have(moves, Vector2i(6, 0))


func test_castling_not_allowed_if_king_moved() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	king.has_moved = true
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(7, 0), rook)

	var moves := board.get_legal_moves(Vector2i(4, 0))

	assert_does_not_have(moves, Vector2i(6, 0))


func test_castling_not_allowed_if_rook_moved() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	rook.has_moved = true
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(7, 0), rook)

	var moves := board.get_legal_moves(Vector2i(4, 0))

	assert_does_not_have(moves, Vector2i(6, 0))


func test_castling_not_allowed_in_check() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	var enemy_rook := Piece.new(Piece.Type.ROOK, Piece.Side.BLACK)
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(7, 0), rook)
	board.set_piece(Vector2i(4, 7), enemy_rook)  # Puts king in check

	var moves := board.get_legal_moves(Vector2i(4, 0))

	assert_does_not_have(moves, Vector2i(6, 0))


func test_castling_executes_rook_move() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(7, 0), rook)

	var result := board.execute_move(Vector2i(4, 0), Vector2i(6, 0))

	assert_true(result["valid"])
	assert_eq(result["special"], "castling_kingside")
	# King should be on g1
	assert_eq(board.get_piece(Vector2i(6, 0)).type, Piece.Type.KING)
	# Rook should be on f1
	assert_eq(board.get_piece(Vector2i(5, 0)).type, Piece.Type.ROOK)
	# Original positions empty
	assert_null(board.get_piece(Vector2i(4, 0)))
	assert_null(board.get_piece(Vector2i(7, 0)))


# En passant tests

func test_en_passant_target_set_on_double_move() -> void:
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), pawn)  # e1 (starting position)

	var result := board.execute_move(Vector2i(4, 0), Vector2i(4, 2))

	assert_true(result["valid"])
	assert_eq(board.en_passant_target, Vector2i(4, 1))


func test_en_passant_capture_available() -> void:
	# White pawn on e5, black pawn just moved d7-d5
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	white_pawn.has_moved = true
	var black_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.BLACK)
	board.set_piece(Vector2i(4, 4), white_pawn)  # e5
	board.set_piece(Vector2i(3, 4), black_pawn)  # d5 (just arrived)
	board.en_passant_target = Vector2i(3, 5)  # d6

	var moves := board.get_legal_moves(Vector2i(4, 4))

	# Should include en passant capture on d6
	assert_has(moves, Vector2i(3, 5))


func test_en_passant_capture_removes_pawn() -> void:
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	white_pawn.has_moved = true
	var black_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.BLACK)
	board.set_piece(Vector2i(4, 4), white_pawn)  # e5
	board.set_piece(Vector2i(3, 4), black_pawn)  # d5
	board.en_passant_target = Vector2i(3, 5)  # d6

	var result := board.execute_move(Vector2i(4, 4), Vector2i(3, 5))

	assert_true(result["valid"])
	assert_eq(result["special"], "en_passant")
	# White pawn should be on d6
	assert_eq(board.get_piece(Vector2i(3, 5)).side, Piece.Side.WHITE)
	# Black pawn on d5 should be gone
	assert_null(board.get_piece(Vector2i(3, 4)))


func test_en_passant_cleared_after_move() -> void:
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), white_pawn)
	board.execute_move(Vector2i(4, 0), Vector2i(4, 2))  # Sets en passant target

	# Make another move
	var other_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	other_pawn.has_moved = true
	board.set_piece(Vector2i(0, 3), other_pawn)
	board.execute_move(Vector2i(0, 3), Vector2i(0, 4))

	# En passant target should be cleared
	assert_eq(board.en_passant_target, Vector2i(-1, -1))
