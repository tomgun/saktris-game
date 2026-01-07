extends GutTest
## Unit tests for Piece class


func test_piece_creation() -> void:
	var piece := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	assert_eq(piece.type, Piece.Type.KING)
	assert_eq(piece.side, Piece.Side.WHITE)
	assert_false(piece.has_moved)


func test_piece_symbols() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var queen := Piece.new(Piece.Type.QUEEN, Piece.Side.BLACK)
	var pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)

	assert_eq(king.get_symbol(), "K")
	assert_eq(queen.get_symbol(), "Q")
	assert_eq(pawn.get_symbol(), "")  # Pawns have no symbol in algebraic notation


func test_piece_display_names() -> void:
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var queen := Piece.new(Piece.Type.QUEEN, Piece.Side.BLACK)

	assert_eq(king.get_display_name(), "White King")
	assert_eq(queen.get_display_name(), "Black Queen")


func test_piece_duplicate() -> void:
	var original := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	original.has_moved = true

	var copy := original.duplicate_piece()

	assert_eq(copy.type, original.type)
	assert_eq(copy.side, original.side)
	assert_eq(copy.has_moved, original.has_moved)
	# Verify it's a separate object
	copy.has_moved = false
	assert_true(original.has_moved)


func test_piece_serialization() -> void:
	var piece := Piece.new(Piece.Type.KNIGHT, Piece.Side.BLACK)
	piece.has_moved = true

	var data := piece.to_dict()
	var restored := Piece.from_dict(data)

	assert_eq(restored.type, piece.type)
	assert_eq(restored.side, piece.side)
	assert_eq(restored.has_moved, piece.has_moved)
