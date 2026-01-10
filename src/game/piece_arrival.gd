class_name PieceArrivalManager
extends RefCounted
## Manages the Saktris piece arrival system

enum Mode {
	FIXED,        ## Pre-configured order
	SELECTABLE,   ## Player chooses from pool
	RANDOM_SAME,  ## Random, same sequence for both players
	RANDOM_DIFF   ## Random, different sequences for each player
}

## Default piece arrival order: all pawns, knights, bishops, king, rooks, queen
const DEFAULT_ORDER: Array[Piece.Type] = [
	# 8 Pawns first
	Piece.Type.PAWN, Piece.Type.PAWN, Piece.Type.PAWN, Piece.Type.PAWN,
	Piece.Type.PAWN, Piece.Type.PAWN, Piece.Type.PAWN, Piece.Type.PAWN,
	# 2 Knights
	Piece.Type.KNIGHT, Piece.Type.KNIGHT,
	# 2 Bishops
	Piece.Type.BISHOP, Piece.Type.BISHOP,
	# King
	Piece.Type.KING,
	# 2 Rooks
	Piece.Type.ROOK, Piece.Type.ROOK,
	# Queen last
	Piece.Type.QUEEN
]

var mode: Mode = Mode.FIXED
var arrival_frequency: int = 1  ## Piece arrives every N moves

## Queues for each player
var white_queue: Array[Piece.Type] = []
var black_queue: Array[Piece.Type] = []

## Available pieces pool for each player (for SELECTABLE mode)
var white_pool: Array[Piece.Type] = []
var black_pool: Array[Piece.Type] = []

## Current piece waiting to be placed
var white_current: Piece = null
var black_current: Piece = null

## Track pieces already given to each player
var white_pieces_given: int = 0
var black_pieces_given: int = 0

## Track moves made by each player (for arrival frequency)
var white_moves_made: int = 0
var black_moves_made: int = 0

## Random seed for reproducibility
var rng: RandomNumberGenerator


func _init() -> void:
	rng = RandomNumberGenerator.new()


func initialize(p_mode: Mode, p_frequency: int = 2, p_seed: int = -1) -> void:
	## Initialize the arrival system with given settings
	mode = p_mode
	arrival_frequency = p_frequency

	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()

	# Reset state
	white_queue.clear()
	black_queue.clear()
	white_current = null
	black_current = null
	white_pieces_given = 0
	black_pieces_given = 0
	white_moves_made = 0
	black_moves_made = 0

	# Initialize pools with full piece sets
	white_pool = _create_full_piece_pool()
	black_pool = _create_full_piece_pool()

	# Pre-generate queues based on mode
	match mode:
		Mode.FIXED:
			white_queue = DEFAULT_ORDER.duplicate()
			black_queue = DEFAULT_ORDER.duplicate()
		Mode.RANDOM_SAME:
			var shared_order := _generate_random_order()
			white_queue = shared_order.duplicate()
			black_queue = shared_order.duplicate()
		Mode.RANDOM_DIFF:
			white_queue = _generate_random_order()
			black_queue = _generate_random_order()
		Mode.SELECTABLE:
			# Pool mode - no pre-generated queue
			pass


func _create_full_piece_pool() -> Array[Piece.Type]:
	## Creates the standard chess piece set
	var pool: Array[Piece.Type] = []
	pool.append(Piece.Type.KING)
	pool.append(Piece.Type.QUEEN)
	for i in range(2):
		pool.append(Piece.Type.ROOK)
		pool.append(Piece.Type.BISHOP)
		pool.append(Piece.Type.KNIGHT)
	for i in range(8):
		pool.append(Piece.Type.PAWN)
	return pool


func _generate_random_order() -> Array[Piece.Type]:
	## Generates a randomized piece order
	var pool := _create_full_piece_pool()
	var order: Array[Piece.Type] = []

	while pool.size() > 0:
		var index := rng.randi_range(0, pool.size() - 1)
		order.append(pool[index])
		pool.remove_at(index)

	return order


func should_piece_arrive(color: int, _move_count: int) -> bool:
	## Returns true if a piece should arrive this turn
	var pieces_given := white_pieces_given if color == Piece.Side.WHITE else black_pieces_given
	var moves_made := white_moves_made if color == Piece.Side.WHITE else black_moves_made
	var pool := white_pool if color == Piece.Side.WHITE else black_pool

	# No more pieces to give
	if pool.is_empty() and mode == Mode.SELECTABLE:
		return false

	var queue := white_queue if color == Piece.Side.WHITE else black_queue
	if queue.is_empty() and mode != Mode.SELECTABLE:
		return false

	# A piece arrives when player has made enough moves since last piece
	# First piece (pieces_given=0): arrives immediately (0 >= 0*freq)
	# Second piece (pieces_given=1): arrives after freq moves (moves >= 1*freq)
	# Third piece (pieces_given=2): arrives after 2*freq moves (moves >= 2*freq)
	# etc.
	return moves_made >= pieces_given * arrival_frequency


func queue_next_piece(color: int) -> void:
	## Queues the next piece for arrival
	var queue: Array[Piece.Type]
	var pool: Array[Piece.Type]

	if color == Piece.Side.WHITE:
		queue = white_queue
		pool = white_pool
	else:
		queue = black_queue
		pool = black_pool

	var piece_type: Piece.Type

	if mode == Mode.SELECTABLE:
		# In selectable mode, we wait for player to choose
		return
	else:
		if queue.is_empty():
			return
		piece_type = queue.pop_front()
		# Remove from pool
		var idx := pool.find(piece_type)
		if idx >= 0:
			pool.remove_at(idx)

	var piece := Piece.new(piece_type, color)

	if color == Piece.Side.WHITE:
		white_current = piece
	else:
		black_current = piece


func get_current_piece(color: int) -> Piece:
	## Returns the piece waiting to be placed, or null
	return white_current if color == Piece.Side.WHITE else black_current


func get_next_piece_preview(color: int) -> int:
	## Returns the type of the next piece in queue (for preview), or -1 if none
	var queue := white_queue if color == Piece.Side.WHITE else black_queue
	if queue.is_empty():
		return -1  # Invalid
	return queue[0]


func get_upcoming_pieces(color: int, count: int) -> Array[Piece.Type]:
	## Returns the next N pieces in queue for preview
	var queue := white_queue if color == Piece.Side.WHITE else black_queue
	var result: Array[Piece.Type] = []
	for i in range(mini(count, queue.size())):
		result.append(queue[i])
	return result


func get_available_pool(color: int) -> Array[Piece.Type]:
	## Returns available pieces for SELECTABLE mode
	return white_pool.duplicate() if color == Piece.Side.WHITE else black_pool.duplicate()


func select_piece_from_pool(color: int, piece_type: Piece.Type) -> bool:
	## For SELECTABLE mode: player chooses which piece to deploy
	if mode != Mode.SELECTABLE:
		return false

	var pool := white_pool if color == Piece.Side.WHITE else black_pool
	var idx := pool.find(piece_type)
	if idx < 0:
		return false

	pool.remove_at(idx)
	var piece := Piece.new(piece_type, color)

	if color == Piece.Side.WHITE:
		white_current = piece
		white_pool = pool
	else:
		black_current = piece
		black_pool = pool

	return true


func piece_placed(color: int) -> void:
	## Called when a piece has been successfully placed on the board
	if color == Piece.Side.WHITE:
		white_current = null
		white_pieces_given += 1
	else:
		black_current = null
		black_pieces_given += 1


func record_move(color: int) -> void:
	## Called when a player makes a move (not placement)
	if color == Piece.Side.WHITE:
		white_moves_made += 1
	else:
		black_moves_made += 1


func has_pieces_remaining(color: int) -> bool:
	## Returns true if there are more pieces to come
	if mode == Mode.SELECTABLE:
		var pool := white_pool if color == Piece.Side.WHITE else black_pool
		return not pool.is_empty()
	else:
		var queue := white_queue if color == Piece.Side.WHITE else black_queue
		return not queue.is_empty()


func to_dict() -> Dictionary:
	## Serialize for save/load
	var white_current_data = null
	var black_current_data = null
	if white_current != null:
		white_current_data = white_current.to_dict()
	if black_current != null:
		black_current_data = black_current.to_dict()

	return {
		"mode": mode,
		"arrival_frequency": arrival_frequency,
		"white_queue": white_queue,
		"black_queue": black_queue,
		"white_pool": white_pool,
		"black_pool": black_pool,
		"white_current": white_current_data,
		"black_current": black_current_data,
		"white_pieces_given": white_pieces_given,
		"black_pieces_given": black_pieces_given,
		"white_moves_made": white_moves_made,
		"black_moves_made": black_moves_made,
		"rng_state": rng.state
	}


static func from_dict(data: Dictionary) -> PieceArrivalManager:
	## Deserialize from save data
	var manager := PieceArrivalManager.new()
	manager.mode = data["mode"]
	manager.arrival_frequency = data["arrival_frequency"]
	manager.white_queue.assign(data["white_queue"])
	manager.black_queue.assign(data["black_queue"])
	manager.white_pool.assign(data["white_pool"])
	manager.black_pool.assign(data["black_pool"])
	manager.white_current = Piece.from_dict(data["white_current"]) if data["white_current"] else null
	manager.black_current = Piece.from_dict(data["black_current"]) if data["black_current"] else null
	manager.white_pieces_given = data["white_pieces_given"]
	manager.black_pieces_given = data["black_pieces_given"]
	manager.white_moves_made = data.get("white_moves_made", 0)
	manager.black_moves_made = data.get("black_moves_made", 0)
	manager.rng.state = data.get("rng_state", 0)
	return manager
