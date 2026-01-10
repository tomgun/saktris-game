extends GutTest
## Unit tests for draw detection (F-0018: DrawRules)

var draw_detector: DrawDetector
var board: Board


func before_each() -> void:
	draw_detector = DrawDetector.new()
	board = Board.new()


# ─────────────────────────────────────────────────────────────────────────────
# 50-Move Rule Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_fifty_move_rule_initial_state() -> void:
	## Initially, 50-move rule should not apply
	assert_false(draw_detector.is_fifty_move_rule())


func test_fifty_move_rule_triggers_at_100_halfmoves() -> void:
	## 50-move rule triggers after 100 half-moves without capture or pawn move
	for i in range(100):
		draw_detector.on_move_made(false, false)  # No capture, no pawn move

	assert_true(draw_detector.is_fifty_move_rule())


func test_halfmove_clock_resets_on_capture() -> void:
	## Halfmove clock should reset when a capture occurs
	# Make 50 non-capture moves
	for i in range(50):
		draw_detector.on_move_made(false, false)

	# Make a capture
	draw_detector.on_move_made(true, false)

	# Make 49 more non-capture moves (should not trigger 50-move rule)
	for i in range(49):
		draw_detector.on_move_made(false, false)

	assert_false(draw_detector.is_fifty_move_rule())

	# One more move should not trigger it yet
	draw_detector.on_move_made(false, false)

	# Now we need 50 more to reach 100 from the reset
	for i in range(50):
		draw_detector.on_move_made(false, false)

	assert_true(draw_detector.is_fifty_move_rule())


func test_halfmove_clock_resets_on_pawn_move() -> void:
	## Halfmove clock should reset when a pawn moves
	for i in range(50):
		draw_detector.on_move_made(false, false)

	# Make a pawn move
	draw_detector.on_move_made(false, true)

	# Should be reset to 0
	for i in range(99):
		draw_detector.on_move_made(false, false)

	assert_false(draw_detector.is_fifty_move_rule())

	draw_detector.on_move_made(false, false)
	assert_true(draw_detector.is_fifty_move_rule())


# ─────────────────────────────────────────────────────────────────────────────
# Threefold Repetition Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_threefold_repetition_initial_state() -> void:
	## Initially, no repetition should be detected
	assert_false(draw_detector.is_threefold_repetition())


func test_threefold_repetition_detection() -> void:
	## Same position occurring 3 times should trigger threefold repetition
	# Set up a simple position
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)

	# Record same position 3 times
	draw_detector.record_position(board, Piece.Side.WHITE)
	assert_false(draw_detector.is_threefold_repetition())

	draw_detector.record_position(board, Piece.Side.WHITE)
	assert_false(draw_detector.is_threefold_repetition())

	draw_detector.record_position(board, Piece.Side.WHITE)
	assert_true(draw_detector.is_threefold_repetition())


func test_position_hash_consistency() -> void:
	## Same board state should produce same hash
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)

	var hasher := PositionHash.new()
	var hash1 := hasher.compute_hash(board, Piece.Side.WHITE)
	var hash2 := hasher.compute_hash(board, Piece.Side.WHITE)

	assert_eq(hash1, hash2)


func test_different_positions_different_hashes() -> void:
	## Different positions should (very likely) produce different hashes
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)

	var hasher := PositionHash.new()
	var hash1 := hasher.compute_hash(board, Piece.Side.WHITE)

	# Move king to different position
	board.set_piece(Vector2i(4, 0), null)
	board.set_piece(Vector2i(5, 0), king)

	var hash2 := hasher.compute_hash(board, Piece.Side.WHITE)

	assert_ne(hash1, hash2)


func test_side_to_move_affects_hash() -> void:
	## Same board but different side to move should produce different hash
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)

	var hasher := PositionHash.new()
	var hash_white := hasher.compute_hash(board, Piece.Side.WHITE)
	var hash_black := hasher.compute_hash(board, Piece.Side.BLACK)

	assert_ne(hash_white, hash_black)


# ─────────────────────────────────────────────────────────────────────────────
# Insufficient Material Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_insufficient_material_k_vs_k() -> void:
	## King vs King is insufficient material
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(4, 7), black_king)

	assert_true(draw_detector.is_insufficient_material(board))


func test_insufficient_material_kb_vs_k() -> void:
	## King + Bishop vs King is insufficient material
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var white_bishop := Piece.new(Piece.Type.BISHOP, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(2, 0), white_bishop)
	board.set_piece(Vector2i(4, 7), black_king)

	assert_true(draw_detector.is_insufficient_material(board))


func test_insufficient_material_kn_vs_k() -> void:
	## King + Knight vs King is insufficient material
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var white_knight := Piece.new(Piece.Type.KNIGHT, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(1, 0), white_knight)
	board.set_piece(Vector2i(4, 7), black_king)

	assert_true(draw_detector.is_insufficient_material(board))


func test_insufficient_material_k_vs_kb() -> void:
	## King vs King + Bishop (black has bishop) is insufficient material
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)
	var black_bishop := Piece.new(Piece.Type.BISHOP, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(4, 7), black_king)
	board.set_piece(Vector2i(5, 7), black_bishop)

	assert_true(draw_detector.is_insufficient_material(board))


func test_insufficient_material_kb_vs_kb_same_color() -> void:
	## King + Bishop vs King + Bishop (same color bishops) is insufficient
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var white_bishop := Piece.new(Piece.Type.BISHOP, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)
	var black_bishop := Piece.new(Piece.Type.BISHOP, Piece.Side.BLACK)

	# Both bishops on light squares (0,0) and (2,0) have sum 0 and 2 -> both even
	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(0, 0), white_bishop)  # Light square (0+0=0, even)
	board.set_piece(Vector2i(4, 7), black_king)
	board.set_piece(Vector2i(2, 7), black_bishop)  # Light square (2+7=9, odd - wait, let me recalculate)
	# (2,7) = 2+7 = 9, odd = dark square
	# Need same color, so let's use (0,1) for black bishop = 0+1=1 = odd = dark
	# Actually (0,0) = 0 = light, (2,0) = 2 = light. Both light.

	# Let me redo this with correct squares
	board = Board.new()
	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(2, 0), white_bishop)  # 2+0=2, even = light
	board.set_piece(Vector2i(4, 7), black_king)
	board.set_piece(Vector2i(0, 7), black_bishop)  # 0+7=7, odd = dark

	# These are different colors, so not insufficient - let me use same color
	board = Board.new()
	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(2, 0), white_bishop)  # 2+0=2, even = light
	board.set_piece(Vector2i(4, 7), black_king)
	board.set_piece(Vector2i(4, 5), black_bishop)  # 4+5=9, odd = dark

	# Still different. Let me think about this more carefully:
	# Light squares: (x+y) % 2 == 0
	# Dark squares: (x+y) % 2 == 1
	# I want both on light:
	# (2,0): 2+0=2, 2%2=0 -> light
	# (4,4): 4+4=8, 8%2=0 -> light

	board = Board.new()
	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(2, 0), white_bishop)  # Light square
	board.set_piece(Vector2i(4, 7), black_king)
	board.set_piece(Vector2i(4, 4), black_bishop)  # Light square

	assert_true(draw_detector.is_insufficient_material(board))


func test_sufficient_material_kq_vs_k() -> void:
	## King + Queen vs King is sufficient material
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var white_queen := Piece.new(Piece.Type.QUEEN, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(3, 0), white_queen)
	board.set_piece(Vector2i(4, 7), black_king)

	assert_false(draw_detector.is_insufficient_material(board))


func test_sufficient_material_kr_vs_k() -> void:
	## King + Rook vs King is sufficient material
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var white_rook := Piece.new(Piece.Type.ROOK, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(0, 0), white_rook)
	board.set_piece(Vector2i(4, 7), black_king)

	assert_false(draw_detector.is_insufficient_material(board))


func test_sufficient_material_kp_vs_k() -> void:
	## King + Pawn vs King is sufficient material (pawn can promote)
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var white_pawn := Piece.new(Piece.Type.PAWN, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(0, 1), white_pawn)
	board.set_piece(Vector2i(4, 7), black_king)

	assert_false(draw_detector.is_insufficient_material(board))


func test_sufficient_material_kb_vs_kb_opposite_color() -> void:
	## King + Bishop vs King + Bishop (opposite color bishops) is sufficient
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var white_bishop := Piece.new(Piece.Type.BISHOP, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)
	var black_bishop := Piece.new(Piece.Type.BISHOP, Piece.Side.BLACK)

	# White bishop on light square, black bishop on dark square
	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(2, 0), white_bishop)  # 2+0=2, even = light
	board.set_piece(Vector2i(4, 7), black_king)
	board.set_piece(Vector2i(1, 0), black_bishop)  # 1+0=1, odd = dark

	assert_false(draw_detector.is_insufficient_material(board))


# ─────────────────────────────────────────────────────────────────────────────
# check_all_draws Integration Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_check_all_draws_returns_none_initially() -> void:
	## No draw conditions should be detected initially
	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)

	var result := draw_detector.check_all_draws(board, Piece.Side.WHITE)
	assert_eq(result, DrawDetector.DrawReason.NONE)


func test_check_all_draws_returns_insufficient_material() -> void:
	## Should return INSUFFICIENT_MATERIAL when applicable
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(4, 7), black_king)

	var result := draw_detector.check_all_draws(board, Piece.Side.WHITE)
	assert_eq(result, DrawDetector.DrawReason.INSUFFICIENT_MATERIAL)


func test_check_all_draws_returns_fifty_move() -> void:
	## Should return FIFTY_MOVE_RULE when applicable
	var white_king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	var white_queen := Piece.new(Piece.Type.QUEEN, Piece.Side.WHITE)
	var black_king := Piece.new(Piece.Type.KING, Piece.Side.BLACK)

	board.set_piece(Vector2i(4, 0), white_king)
	board.set_piece(Vector2i(3, 0), white_queen)
	board.set_piece(Vector2i(4, 7), black_king)

	# Make 100 non-capture, non-pawn moves
	for i in range(100):
		draw_detector.on_move_made(false, false)

	var result := draw_detector.check_all_draws(board, Piece.Side.WHITE)
	assert_eq(result, DrawDetector.DrawReason.FIFTY_MOVE_RULE)


func test_draw_reason_string() -> void:
	## Test draw reason string conversion
	assert_eq(DrawDetector.get_draw_reason_string(DrawDetector.DrawReason.FIFTY_MOVE_RULE), "50-move rule")
	assert_eq(DrawDetector.get_draw_reason_string(DrawDetector.DrawReason.THREEFOLD_REPETITION), "threefold repetition")
	assert_eq(DrawDetector.get_draw_reason_string(DrawDetector.DrawReason.INSUFFICIENT_MATERIAL), "insufficient material")
	assert_eq(DrawDetector.get_draw_reason_string(DrawDetector.DrawReason.NONE), "")


# ─────────────────────────────────────────────────────────────────────────────
# Serialization Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_draw_detector_serialization() -> void:
	## DrawDetector should serialize and deserialize correctly
	# Set up some state
	for i in range(25):
		draw_detector.on_move_made(false, false)

	var king := Piece.new(Piece.Type.KING, Piece.Side.WHITE)
	board.set_piece(Vector2i(4, 0), king)
	draw_detector.record_position(board, Piece.Side.WHITE)
	draw_detector.record_position(board, Piece.Side.WHITE)

	# Serialize
	var data := draw_detector.to_dict()

	# Deserialize
	var restored := DrawDetector.from_dict(data)

	# Verify state preserved
	assert_eq(restored.halfmove_clock, 25)
	assert_eq(restored.get_repetition_count(board, Piece.Side.WHITE), 2)
