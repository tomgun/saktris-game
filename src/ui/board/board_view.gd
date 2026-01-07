class_name BoardView
extends Control
## Main chess board view - displays the board, pieces, and handles input

const SquareScene := preload("res://src/ui/board/square.tscn")
const PieceSpriteScene := preload("res://src/ui/board/piece_sprite.tscn")

const BOARD_SIZE := 8
const LEGAL_MOVE_DOT_COLOR := Color(0, 0, 0, 0.2)
const LEGAL_CAPTURE_COLOR := Color(0.8, 0.2, 0.2, 0.3)

var game_state: GameState
var square_size: float = 64.0
var selected_pos: Vector2i = Vector2i(-1, -1)
var legal_moves: Array[Vector2i] = []

# UI elements
var squares: Array = []  # 2D array of BoardSquare nodes
var piece_sprites: Dictionary = {}  # Vector2i -> PieceSprite
var legal_move_indicators: Array = []
var bumping_pieces: Array[PieceSprite] = []  # Pieces currently flying off
var hovered_column: int = -1  # Column currently being hovered for piece placement

@onready var board_container: Control = %BoardContainer
@onready var squares_grid: GridContainer = %SquaresGrid
@onready var pieces_layer: Control = %PiecesLayer
@onready var highlights_layer: Control = %HighlightsLayer
@onready var arrival_layer: Control = %ArrivalLayer
@onready var hovering_piece: TextureRect = %HoveringPiece
@onready var ghost_piece: TextureRect = %GhostPiece
@onready var black_arrival_area: Control = %BlackArrivalArea
@onready var white_arrival_area: Control = %WhiteArrivalArea
@onready var turn_label: Label = %TurnLabel
@onready var turn_indicator: ColorRect = %TurnIndicator
@onready var status_label: Label = %StatusLabel
@onready var arrival_panel: Control = %ArrivalPanel
@onready var arrival_piece_sprite: TextureRect = $MarginContainer/HBoxContainer/SidePanel/ArrivalPanel/ArrivalPieceContainer/ArrivalPieceSprite
@onready var queue_panel: Control = %QueuePanel
@onready var queue_container: HBoxContainer = %QueueContainer
@onready var promotion_dialog: PanelContainer = %PromotionDialog
@onready var promotion_buttons: HBoxContainer = %PromotionButtons
@onready var new_game_button: Button = %NewGameButton

signal new_game_requested


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	_create_board()


func _input(event: InputEvent) -> void:
	# Handle clicks for piece placement anywhere in the board column area
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_state and game_state.must_place_piece() and not game_state.is_ai_turn():
			# Check if click is within or near the board area
			var local_pos := board_container.get_local_mouse_position()
			var col := int(local_pos.x / square_size)

			# Allow clicks in valid column range and extended vertical area
			if col >= 0 and col < BOARD_SIZE:
				var is_white := game_state.current_player == Piece.Side.WHITE
				var target_row := 0 if is_white else 7
				var target_pos := Vector2i(col, target_row)

				# Check vertical bounds - allow clicks above/below board too
				var board_height := BOARD_SIZE * square_size
				var in_extended_area := local_pos.y >= -square_size * 1.5 and local_pos.y <= board_height + square_size * 1.5

				if in_extended_area and game_state.board.is_empty(target_pos):
					if game_state.try_place_piece(col):
						# Turn ends after placing - no auto-select needed
						_clear_placement_highlights()
						_update_arrival_display()
						_update_turn_display()
						get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_physics(delta)
	_update_hovering_piece()


func initialize(state: GameState) -> void:
	game_state = state

	var player := "WHITE" if game_state.current_player == Piece.Side.WHITE else "BLACK"
	var arriving := game_state.arrival_manager.get_current_piece(game_state.current_player)
	print("[BoardView] Initialize: current_player=%s, has_piece=%s, must_place=%s" % [
		player, arriving != null, game_state.must_place_piece()])

	# Connect signals
	game_state.turn_changed.connect(_on_turn_changed)
	game_state.status_changed.connect(_on_status_changed)
	game_state.game_over.connect(_on_game_over)
	game_state.promotion_needed.connect(_on_promotion_needed)
	game_state.ai_turn_started.connect(_on_ai_turn_started)
	game_state.board.piece_moved.connect(_on_piece_moved)
	game_state.board.piece_captured.connect(_on_piece_captured)
	game_state.board.piece_placed.connect(_on_piece_placed)

	# Wait for layout to complete before positioning
	await get_tree().process_frame
	await get_tree().process_frame

	# Initial display
	_refresh_pieces()
	_update_turn_display()
	_update_arrival_display()

	print("[BoardView] After init display: turn_label=%s" % turn_label.text)

	# Check if AI goes first
	if game_state.is_ai_turn():
		_on_ai_turn_started()


func _create_board() -> void:
	squares_grid.columns = BOARD_SIZE

	# Create 8x8 grid of squares
	for row in range(BOARD_SIZE):
		var row_array: Array = []
		for col in range(BOARD_SIZE):
			var square = SquareScene.instantiate()
			squares_grid.add_child(square)
			# Board coordinates: col=x, row=y, but display row 0 at bottom
			var board_pos := Vector2i(col, BOARD_SIZE - 1 - row)
			square.setup(board_pos)
			square.clicked.connect(_on_square_clicked)
			row_array.append(square)
		squares.append(row_array)


func _refresh_pieces() -> void:
	# Clear existing piece sprites
	for sprite in piece_sprites.values():
		sprite.queue_free()
	piece_sprites.clear()

	if game_state == null:
		return

	# Create sprites for all pieces on the board
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var pos := Vector2i(col, row)
			var piece := game_state.board.get_piece(pos)
			if piece:
				_create_piece_sprite(piece, pos)


func _create_piece_sprite(piece: Piece, pos: Vector2i):
	var sprite = PieceSpriteScene.instantiate()
	pieces_layer.add_child(sprite)
	sprite.setup(piece, pos, square_size)
	sprite.position = _board_to_pixel(pos)
	piece_sprites[pos] = sprite
	return sprite


func _board_to_pixel(board_pos: Vector2i) -> Vector2:
	# Convert board position to pixel position based on actual square positions
	var square = _get_square(board_pos)
	if square:
		return square.global_position - pieces_layer.global_position
	# Fallback calculation
	var display_row := BOARD_SIZE - 1 - board_pos.y
	return Vector2(board_pos.x * square_size, display_row * square_size)


func _on_square_clicked(board_pos: Vector2i) -> void:
	if game_state == null:
		print("[DEBUG] game_state is null")
		return

	var player := "WHITE" if game_state.current_player == Piece.Side.WHITE else "BLACK"
	print("[DEBUG] Click at %s, current_player=%s, is_ai_turn=%s" % [board_pos, player, game_state.is_ai_turn()])

	# Ignore clicks during AI's turn
	if game_state.is_ai_turn():
		print("[DEBUG] Blocked - AI's turn")
		return

	# Check if we need to place an arriving piece first
	if game_state.must_place_piece():
		print("[DEBUG] Must place piece first! Clicking %s" % board_pos)
		# In arrival mode - try to place piece
		if _try_place_arriving_piece(board_pos):
			print("[DEBUG] Piece placed successfully - turn ends")
			_clear_placement_highlights()
			_update_arrival_display()
			_update_turn_display()
			# Turn ends after placing - no auto-select
		else:
			print("[DEBUG] Invalid placement location - must place on back row empty square")
		return  # Don't allow normal moves while placing

	# Normal move mode
	print("[DEBUG] selected_pos=%s, legal_moves=%s" % [selected_pos, legal_moves])
	if selected_pos == Vector2i(-1, -1):
		# No piece selected - try to select one
		var piece := game_state.board.get_piece(board_pos)
		print("[DEBUG] Trying to select at %s, piece=%s" % [board_pos, piece])
		if piece and piece.side == game_state.current_player:
			print("[DEBUG] Selecting piece!")
			_select_piece(board_pos)
		else:
			print("[DEBUG] No piece to select or wrong side")
	else:
		# Piece already selected
		if board_pos in legal_moves:
			# Valid move - execute it
			print("[DEBUG] Executing move from %s to %s" % [selected_pos, board_pos])
			_execute_move(selected_pos, board_pos)
		else:
			# Check if clicking on another own piece
			var piece := game_state.board.get_piece(board_pos)
			if piece and piece.side == game_state.current_player:
				_select_piece(board_pos)
			else:
				_deselect()


func _try_place_arriving_piece(board_pos: Vector2i) -> bool:
	# Can only place on back row
	var expected_row := 0 if game_state.current_player == Piece.Side.WHITE else 7
	if board_pos.y != expected_row:
		return false

	return game_state.try_place_piece(board_pos.x)


func _select_piece(pos: Vector2i) -> void:
	_deselect()  # Clear previous selection

	selected_pos = pos
	legal_moves = game_state.board.get_legal_moves(pos)

	# Highlight selected square
	_get_square(pos).set_highlighted(true)

	# Show legal move indicators
	_show_legal_moves()


func _deselect() -> void:
	if selected_pos != Vector2i(-1, -1):
		_get_square(selected_pos).set_highlighted(false)

	selected_pos = Vector2i(-1, -1)
	legal_moves.clear()
	_clear_legal_move_indicators()


func _execute_move(from: Vector2i, to: Vector2i) -> void:
	_deselect()
	game_state.try_move(from, to)


func _show_legal_moves() -> void:
	_clear_legal_move_indicators()

	for move_pos in legal_moves:
		var indicator := ColorRect.new()
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var target_piece := game_state.board.get_piece(move_pos)
		if target_piece:
			# Capture indicator - ring around square
			indicator.color = LEGAL_CAPTURE_COLOR
			indicator.size = Vector2(square_size, square_size)
		else:
			# Move indicator - small dot in center
			var dot_size := square_size * 0.3
			indicator.color = LEGAL_MOVE_DOT_COLOR
			indicator.size = Vector2(dot_size, dot_size)
			indicator.pivot_offset = indicator.size / 2

		indicator.position = _board_to_pixel(move_pos)
		if not target_piece:
			indicator.position += Vector2((square_size - indicator.size.x) / 2, (square_size - indicator.size.y) / 2)

		highlights_layer.add_child(indicator)
		legal_move_indicators.append(indicator)


func _clear_legal_move_indicators() -> void:
	for indicator in legal_move_indicators:
		indicator.queue_free()
	legal_move_indicators.clear()


func _get_square(board_pos: Vector2i):
	var display_row := BOARD_SIZE - 1 - board_pos.y
	return squares[display_row][board_pos.x]


# Signal handlers

func _on_turn_changed(_player: int) -> void:
	var player := "WHITE" if game_state.current_player == Piece.Side.WHITE else "BLACK"
	var arriving := game_state.arrival_manager.get_current_piece(game_state.current_player)
	print("[BoardView] Turn changed to %s, has_piece=%s, must_place=%s" % [
		player, arriving != null, game_state.must_place_piece()])
	_update_turn_display()
	_update_arrival_display()


func _on_status_changed(new_status: GameState.Status) -> void:
	_update_status_display(new_status)


func _on_game_over(winner: int, reason: String) -> void:
	var winner_name := "White" if winner == Piece.Side.WHITE else "Black"
	status_label.text = "%s wins by %s!" % [winner_name, reason]


func _on_piece_moved(from: Vector2i, to: Vector2i, _piece: Piece) -> void:
	# Animate the piece movement
	if from in piece_sprites:
		var sprite = piece_sprites[from]
		sprite.animate_to(to, _board_to_pixel(to))
		piece_sprites.erase(from)
		piece_sprites[to] = sprite

	# Update last move highlights
	_clear_last_move_highlights()
	_get_square(from).set_last_move(true)
	_get_square(to).set_last_move(true)


func _on_piece_captured(pos: Vector2i, _piece: Piece, attacker_from: Vector2i) -> void:
	if pos in piece_sprites:
		var sprite: PieceSprite = piece_sprites[pos]
		piece_sprites.erase(pos)

		if Settings.physics_bump_enabled:
			# Calculate direction in SCREEN space (from attacker position to captured position)
			var attacker_screen_pos := _board_to_pixel(attacker_from) + Vector2(square_size, square_size) / 2
			var captured_screen_pos := sprite.position + sprite.size / 2
			var direction := (captured_screen_pos - attacker_screen_pos).normalized()

			sprite.home_position = sprite.position
			sprite.start_bump(direction, square_size * 6.0)
			bumping_pieces.append(sprite)
		else:
			sprite.queue_free()


func _update_physics(delta: float) -> void:
	## Update physics simulation for all bumping pieces
	if bumping_pieces.is_empty():
		return

	# Get all sprites on the board for collision checking
	var board_sprites: Array[PieceSprite] = []
	for sprite in piece_sprites.values():
		board_sprites.append(sprite)

	# Update each bumping piece
	var pieces_to_remove: Array[PieceSprite] = []
	for bumping in bumping_pieces:
		if not is_instance_valid(bumping):
			pieces_to_remove.append(bumping)
			continue

		# Check collisions before moving
		var bumping_center := bumping.get_center()
		var bumping_radius := bumping.get_collision_radius()

		for board_sprite in board_sprites:
			if board_sprite == bumping:
				continue

			var other_center := board_sprite.get_center()
			var other_radius := board_sprite.get_collision_radius()
			var distance := bumping_center.distance_to(other_center)

			if distance < bumping_radius + other_radius:
				# Collision! Push the board piece
				var push_dir := (other_center - bumping_center).normalized()
				board_sprite.nudge(push_dir, 0.4)

		# Update physics
		bumping.physics_update(delta)

		# Check if piece should be removed (off screen or faded out)
		if bumping.modulate.a <= 0 or bumping.position.y > size.y + 200:
			pieces_to_remove.append(bumping)

	# Clean up removed pieces
	for piece in pieces_to_remove:
		bumping_pieces.erase(piece)
		if is_instance_valid(piece):
			piece.queue_free()


func _on_piece_placed(pos: Vector2i, piece: Piece) -> void:
	# Remove existing sprite if there is one (for promotion)
	if pos in piece_sprites:
		piece_sprites[pos].queue_free()
		piece_sprites.erase(pos)

	# Create the sprite and animate it dropping from hover position
	var sprite = _create_piece_sprite(piece, pos)

	# If we have a valid hovering piece, animate from there
	if hovering_piece.visible:
		var start_pos := hovering_piece.position
		sprite.position = start_pos
		sprite.modulate.a = 0.0  # Start invisible

		# Hide hover/ghost immediately
		hovering_piece.visible = false
		ghost_piece.visible = false

		# Animate drop
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(sprite, "position", _board_to_pixel(pos), 0.3)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.1).set_ease(Tween.EASE_IN)


func _clear_last_move_highlights() -> void:
	for row in squares:
		for square in row:
			square.set_last_move(false)


func _update_turn_display() -> void:
	if game_state == null:
		return

	var is_white := game_state.current_player == Piece.Side.WHITE
	var current := "White" if is_white else "Black"
	var action := "place" if game_state.must_place_piece() else "move"
	turn_label.text = "%s to %s" % [current, action]

	# Update turn indicator color
	if turn_indicator:
		turn_indicator.color = Color.WHITE if is_white else Color.BLACK


func _update_status_display(status: GameState.Status) -> void:
	match status:
		GameState.Status.PLAYING:
			status_label.text = ""
		GameState.Status.CHECK:
			status_label.text = "Check!"
		GameState.Status.CHECKMATE:
			status_label.text = "Checkmate!"
		GameState.Status.STALEMATE:
			status_label.text = "Stalemate!"
		GameState.Status.DRAW:
			status_label.text = "Draw!"


func _update_arrival_display() -> void:
	if game_state == null:
		return

	var can_place := game_state.must_place_piece()

	# Hide the side panel arrival UI - we use hovering piece instead
	if arrival_panel:
		arrival_panel.visible = false

	# Clear old placement highlights - hovering piece provides visual cue now
	if not can_place:
		_clear_placement_highlights()

	# Update queue preview
	_update_queue_display()


func _update_queue_display() -> void:
	if game_state == null or queue_container == null:
		return

	# Clear existing preview sprites
	for child in queue_container.get_children():
		child.queue_free()

	# Get upcoming pieces
	var preview_count := Settings.piece_preview_count
	var upcoming := game_state.arrival_manager.get_upcoming_pieces(game_state.current_player, preview_count)

	# Create preview sprites
	for piece_type in upcoming:
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(48, 48)
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = _get_piece_texture(piece_type, game_state.current_player)
		queue_container.add_child(preview)

	# Show/hide queue panel based on whether there are upcoming pieces
	if queue_panel:
		queue_panel.visible = upcoming.size() > 0


func _get_piece_texture(piece_type: int, side: int) -> Texture2D:
	const PIECE_TEXTURES := {
		Piece.Side.WHITE: {
			Piece.Type.KING: "res://assets/sprites/pieces/wK.svg",
			Piece.Type.QUEEN: "res://assets/sprites/pieces/wQ.svg",
			Piece.Type.ROOK: "res://assets/sprites/pieces/wR.svg",
			Piece.Type.BISHOP: "res://assets/sprites/pieces/wB.svg",
			Piece.Type.KNIGHT: "res://assets/sprites/pieces/wN.svg",
			Piece.Type.PAWN: "res://assets/sprites/pieces/wP.svg",
		},
		Piece.Side.BLACK: {
			Piece.Type.KING: "res://assets/sprites/pieces/bK.svg",
			Piece.Type.QUEEN: "res://assets/sprites/pieces/bQ.svg",
			Piece.Type.ROOK: "res://assets/sprites/pieces/bR.svg",
			Piece.Type.BISHOP: "res://assets/sprites/pieces/bB.svg",
			Piece.Type.KNIGHT: "res://assets/sprites/pieces/bN.svg",
			Piece.Type.PAWN: "res://assets/sprites/pieces/bP.svg",
		}
	}
	var path: String = PIECE_TEXTURES[side][piece_type]
	return load(path)


func _show_placement_highlights() -> void:
	_clear_placement_highlights()
	# We no longer show green highlights - the hovering piece provides the visual cue


func _update_hovering_piece() -> void:
	## Update the hovering arrival piece position based on mouse
	if game_state == null or not game_state.must_place_piece():
		hovering_piece.visible = false
		ghost_piece.visible = false
		hovered_column = -1
		return

	# Get mouse position relative to board
	var mouse_pos := board_container.get_local_mouse_position()
	var is_white := game_state.current_player == Piece.Side.WHITE

	# Calculate which column the mouse is over
	var col := int(mouse_pos.x / square_size)
	col = clampi(col, 0, BOARD_SIZE - 1)

	# Check if this column is valid for placement
	var target_row := 0 if is_white else 7
	var target_pos := Vector2i(col, target_row)
	var is_valid := game_state.board.is_empty(target_pos)

	# Update hovering piece
	var arriving := game_state.arrival_manager.get_current_piece(game_state.current_player)
	if arriving:
		hovering_piece.texture = _get_piece_texture(arriving.type, arriving.side)
		hovering_piece.size = Vector2(square_size, square_size)
		hovering_piece.visible = true

		# Position the piece in the arrival area (outside the board)
		var hover_x := col * square_size
		var hover_y: float
		if is_white:
			# White places on row 0 (bottom of display), so hover below board
			# Position relative to board container - arrival area is below
			hover_y = BOARD_SIZE * square_size + 5
		else:
			# Black places on row 7 (top of display), so hover above board
			# Position relative to board container - arrival area is above
			hover_y = -square_size - 5

		hovering_piece.position = Vector2(hover_x, hover_y)

		# Add a gentle bobbing animation
		var bob := sin(Time.get_ticks_msec() / 200.0) * 3.0
		hovering_piece.position.y += bob

		# Tint the piece if column is invalid
		if is_valid:
			hovering_piece.modulate = Color.WHITE
		else:
			hovering_piece.modulate = Color(1, 0.5, 0.5, 0.7)  # Reddish tint

		# Show ghost on target square if valid
		if is_valid:
			ghost_piece.texture = hovering_piece.texture
			ghost_piece.size = Vector2(square_size, square_size)
			ghost_piece.position = _board_to_pixel(target_pos)
			ghost_piece.visible = true
			hovered_column = col
		else:
			ghost_piece.visible = false
			hovered_column = -1
	else:
		hovering_piece.visible = false
		ghost_piece.visible = false
		hovered_column = -1


func _clear_placement_highlights() -> void:
	# Reuse legal_move_indicators array for placement highlights too
	_clear_legal_move_indicators()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_on_resized()


func _on_resized() -> void:
	# Recalculate square size based on available space
	if board_container == null:
		return

	var available := mini(board_container.size.x, board_container.size.y)
	square_size = available / BOARD_SIZE

	# Update square sizes
	for row in squares:
		for square in row:
			square.custom_minimum_size = Vector2(square_size, square_size)

	# Reposition pieces
	for pos in piece_sprites:
		var sprite = piece_sprites[pos]
		sprite.size = Vector2(square_size, square_size)
		sprite.custom_minimum_size = Vector2(square_size, square_size)
		sprite.position = _board_to_pixel(pos)


# Promotion dialog handling

func _on_promotion_needed(pos: Vector2i, side: int) -> void:
	_show_promotion_dialog(side)


func _show_promotion_dialog(side: int) -> void:
	# Clear existing buttons
	for child in promotion_buttons.get_children():
		child.queue_free()

	# Create buttons for each promotion option
	var promotion_types := [Piece.Type.QUEEN, Piece.Type.ROOK, Piece.Type.BISHOP, Piece.Type.KNIGHT]

	for piece_type in promotion_types:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(50, 50)

		# Create texture rect for piece icon
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _get_piece_texture(piece_type, side)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

		btn.add_child(icon)
		btn.pressed.connect(_on_promotion_selected.bind(piece_type))
		promotion_buttons.add_child(btn)

	promotion_dialog.visible = true


func _on_promotion_selected(piece_type: int) -> void:
	if game_state == null:
		return

	# Hide dialog first
	promotion_dialog.visible = false

	# Complete the promotion
	game_state.complete_promotion(piece_type)

	# Update displays
	_update_turn_display()
	_update_arrival_display()


# AI handling

func _on_ai_turn_started() -> void:
	print("[DEBUG] AI turn started")
	# Add a small delay so the player can see the board state
	await get_tree().create_timer(0.3).timeout

	if game_state == null:
		print("[DEBUG] AI: game_state is null")
		return

	print("[DEBUG] AI requesting move...")
	# Request AI to make its move
	game_state.request_ai_move()
	var player := "WHITE" if game_state.current_player == Piece.Side.WHITE else "BLACK"
	print("[DEBUG] AI done, now %s's turn" % player)


func _on_new_game_pressed() -> void:
	new_game_requested.emit()
