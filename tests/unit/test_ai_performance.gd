extends GutTest
## Unit tests for AI performance optimization (make_move/undo_move pattern)


var board: Board


func before_each() -> void:
	board = Board.new()


# ─────────────────────────────────────────────────────────────────────────────
# make_move/undo_move Basic Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_make_move_basic() -> void:
	## Test that make_move correctly moves a piece
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 1), pawn)

	var move_data := board.make_move(Vector2i(4, 1), Vector2i(4, 2))

	assert_false(move_data.is_empty())
	assert_null(board.get_piece(Vector2i(4, 1)))
	assert_eq(board.get_piece(Vector2i(4, 2)), pawn)


func test_undo_move_basic() -> void:
	## Test that undo_move restores board state
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 1), pawn)

	var move_data := board.make_move(Vector2i(4, 1), Vector2i(4, 2))
	board.undo_move(move_data)

	assert_eq(board.get_piece(Vector2i(4, 1)), pawn)
	assert_null(board.get_piece(Vector2i(4, 2)))


func test_make_undo_restores_has_moved() -> void:
	## Test that has_moved state is properly saved and restored
	var knight := Piece.new(Piece.Type.KNIGHT, Piece.Side.WHITE)
	assert_false(knight.has_moved)
	board.set_piece(Vector2i(1, 0), knight)

	var move_data := board.make_move(Vector2i(1, 0), Vector2i(2, 2))
	assert_true(knight.has_moved)

	board.undo_move(move_data)
	assert_false(knight.has_moved)


# ─────────────────────────────────────────────────────────────────────────────
# Capture Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_make_undo_capture() -> void:
	## Test that captures are properly restored
	var white_rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	var black_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.BLACK)
	board.set_piece(Vector2i(4, 4), white_rook)
	board.set_piece(Vector2i(4, 6), black_pawn)

	var move_data := board.make_move(Vector2i(4, 4), Vector2i(4, 6))

	# After move: rook captured pawn
	assert_eq(board.get_piece(Vector2i(4, 6)), white_rook)
	assert_null(board.get_piece(Vector2i(4, 4)))

	board.undo_move(move_data)

	# After undo: both pieces restored
	assert_eq(board.get_piece(Vector2i(4, 4)), white_rook)
	assert_eq(board.get_piece(Vector2i(4, 6)), black_pawn)


# ─────────────────────────────────────────────────────────────────────────────
# En Passant Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_make_move_sets_en_passant_target() -> void:
	## Test that double pawn move sets en passant target
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 1), pawn)

	board.make_move(Vector2i(4, 1), Vector2i(4, 3))

	assert_eq(board.en_passant_target, Vector2i(4, 2))


func test_undo_move_restores_en_passant_target() -> void:
	## Test that en passant target is restored on undo
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 1), pawn)
	board.en_passant_target = Vector2i(2, 5)  # Some previous en passant target

	var move_data := board.make_move(Vector2i(4, 1), Vector2i(4, 3))
	assert_eq(board.en_passant_target, Vector2i(4, 2))

	board.undo_move(move_data)
	assert_eq(board.en_passant_target, Vector2i(2, 5))


func test_make_undo_en_passant_capture() -> void:
	## Test that en passant capture is properly undone
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	white_pawn.has_moved = true
	var black_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.BLACK)
	black_pawn.has_moved = true

	board.set_piece(Vector2i(4, 4), white_pawn)  # e5
	board.set_piece(Vector2i(3, 4), black_pawn)  # d5
	board.en_passant_target = Vector2i(3, 5)     # d6

	var move_data := board.make_move(Vector2i(4, 4), Vector2i(3, 5))

	# After en passant: white pawn on d6, black pawn removed
	assert_eq(board.get_piece(Vector2i(3, 5)), white_pawn)
	assert_null(board.get_piece(Vector2i(3, 4)))
	assert_eq(move_data["special"], "en_passant")

	board.undo_move(move_data)

	# After undo: both pawns restored to original positions
	assert_eq(board.get_piece(Vector2i(4, 4)), white_pawn)
	assert_eq(board.get_piece(Vector2i(3, 4)), black_pawn)
	assert_null(board.get_piece(Vector2i(3, 5)))


# ─────────────────────────────────────────────────────────────────────────────
# Castling Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_make_undo_kingside_castling() -> void:
	## Test that kingside castling is properly undone
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(7, 0), rook)

	var move_data := board.make_move(Vector2i(4, 0), Vector2i(6, 0))

	# After castling: king on g1, rook on f1
	assert_eq(board.get_piece(Vector2i(6, 0)), king)
	assert_eq(board.get_piece(Vector2i(5, 0)), rook)
	assert_null(board.get_piece(Vector2i(4, 0)))
	assert_null(board.get_piece(Vector2i(7, 0)))
	assert_true(king.has_moved)
	assert_true(rook.has_moved)

	board.undo_move(move_data)

	# After undo: king on e1, rook on h1, has_moved restored
	assert_eq(board.get_piece(Vector2i(4, 0)), king)
	assert_eq(board.get_piece(Vector2i(7, 0)), rook)
	assert_null(board.get_piece(Vector2i(6, 0)))
	assert_null(board.get_piece(Vector2i(5, 0)))
	assert_false(king.has_moved)
	assert_false(rook.has_moved)


func test_make_undo_queenside_castling() -> void:
	## Test that queenside castling is properly undone
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(0, 0), rook)

	var move_data := board.make_move(Vector2i(4, 0), Vector2i(2, 0))

	# After castling: king on c1, rook on d1
	assert_eq(board.get_piece(Vector2i(2, 0)), king)
	assert_eq(board.get_piece(Vector2i(3, 0)), rook)
	assert_null(board.get_piece(Vector2i(4, 0)))
	assert_null(board.get_piece(Vector2i(0, 0)))

	board.undo_move(move_data)

	# After undo: king on e1, rook on a1
	assert_eq(board.get_piece(Vector2i(4, 0)), king)
	assert_eq(board.get_piece(Vector2i(0, 0)), rook)
	assert_null(board.get_piece(Vector2i(2, 0)))
	assert_null(board.get_piece(Vector2i(3, 0)))


# ─────────────────────────────────────────────────────────────────────────────
# Pawn Promotion Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_make_move_auto_promotes_to_queen() -> void:
	## Test that pawn auto-promotes to queen in make_move
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	pawn.has_moved = true
	board.set_piece(Vector2i(4, 6), pawn)

	var move_data := board.make_move(Vector2i(4, 6), Vector2i(4, 7))

	assert_eq(board.get_piece(Vector2i(4, 7)).type, Piece.Type.QUEEN)
	assert_eq(move_data["special"], "promotion")


func test_undo_move_restores_pawn_type() -> void:
	## Test that promotion is properly undone
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	pawn.has_moved = true
	board.set_piece(Vector2i(4, 6), pawn)

	var move_data := board.make_move(Vector2i(4, 6), Vector2i(4, 7))
	assert_eq(pawn.type, Piece.Type.QUEEN)

	board.undo_move(move_data)

	assert_eq(pawn.type, Piece.Type.PAWN)
	assert_eq(board.get_piece(Vector2i(4, 6)), pawn)
	assert_null(board.get_piece(Vector2i(4, 7)))


func test_make_undo_promotion_with_capture() -> void:
	## Test promotion with capture is properly undone
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	white_pawn.has_moved = true
	var black_rook := Piece.new(Piece.Type.ROOK, Piece.Side.BLACK)
	board.set_piece(Vector2i(4, 6), white_pawn)
	board.set_piece(Vector2i(5, 7), black_rook)

	var move_data := board.make_move(Vector2i(4, 6), Vector2i(5, 7))

	# After promotion capture: queen on f8
	assert_eq(board.get_piece(Vector2i(5, 7)).type, Piece.Type.QUEEN)
	assert_null(board.get_piece(Vector2i(4, 6)))

	board.undo_move(move_data)

	# After undo: pawn back, rook restored
	assert_eq(board.get_piece(Vector2i(4, 6)), white_pawn)
	assert_eq(white_pawn.type, Piece.Type.PAWN)
	assert_eq(board.get_piece(Vector2i(5, 7)), black_rook)


# ─────────────────────────────────────────────────────────────────────────────
# Full Board State Restoration Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_multiple_make_undo_preserves_state() -> void:
	## Test that multiple make/undo cycles preserve complete board state
	# Setup a complex position
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var queen := Piece.new(Piece.Type.QUEEN, Piece.Side.WHITE)
	var rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	var enemy_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), king)
	board.set_piece(Vector2i(3, 3), queen)
	board.set_piece(Vector2i(7, 0), rook)
	board.set_piece(Vector2i(4, 7), enemy_king)
	board.en_passant_target = Vector2i(2, 2)

	# Capture initial state
	var initial_state := board.to_dict()

	# Make and undo several moves
	var move1 := board.make_move(Vector2i(3, 3), Vector2i(3, 7))
	var move2 := board.make_move(Vector2i(4, 7), Vector2i(5, 7))
	var move3 := board.make_move(Vector2i(7, 0), Vector2i(7, 7))

	# Undo in reverse order
	board.undo_move(move3)
	board.undo_move(move2)
	board.undo_move(move1)

	# Compare states
	var restored_state := board.to_dict()
	assert_eq(restored_state["en_passant_target"], initial_state["en_passant_target"])

	# Verify piece positions
	assert_eq(board.get_piece(Vector2i(4, 0)), king)
	assert_eq(board.get_piece(Vector2i(3, 3)), queen)
	assert_eq(board.get_piece(Vector2i(7, 0)), rook)
	assert_eq(board.get_piece(Vector2i(4, 7)), enemy_king)


func test_nested_make_undo_for_minimax() -> void:
	## Simulate minimax-style nested make/undo calls
	var white_knight := Piece.new(Piece.Type.KNIGHT, Piece.Side.WHITE)
	var black_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 4), white_knight)
	board.set_piece(Vector2i(3, 6), black_pawn)

	# Level 1: make move
	var move1 := board.make_move(Vector2i(4, 4), Vector2i(3, 6))
	assert_eq(board.get_piece(Vector2i(3, 6)), white_knight)

	# Level 2: make another move (knight continues)
	var move2 := board.make_move(Vector2i(3, 6), Vector2i(5, 7))
	assert_eq(board.get_piece(Vector2i(5, 7)), white_knight)

	# Unwind
	board.undo_move(move2)
	assert_eq(board.get_piece(Vector2i(3, 6)), white_knight)
	assert_null(board.get_piece(Vector2i(5, 7)))

	board.undo_move(move1)
	assert_eq(board.get_piece(Vector2i(4, 4)), white_knight)
	assert_eq(board.get_piece(Vector2i(3, 6)), black_pawn)


# ─────────────────────────────────────────────────────────────────────────────
# Invalid Move Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_make_move_returns_empty_for_no_piece() -> void:
	## Test that make_move returns empty dict when no piece at source
	var move_data := board.make_move(Vector2i(4, 4), Vector2i(4, 5))
	assert_true(move_data.is_empty())


func test_undo_move_handles_empty_dict() -> void:
	## Test that undo_move gracefully handles empty dict
	board.undo_move({})
	# Should not crash - just a no-op
	pass_test("undo_move with empty dict didn't crash")
