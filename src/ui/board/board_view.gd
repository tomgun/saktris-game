class_name BoardView
extends Control
## Main chess board view - displays the board, pieces, and handles input

const SquareScene := preload("res://src/ui/board/square.tscn")
const PieceSpriteScene := preload("res://src/ui/board/piece_sprite.tscn")

const BOARD_SIZE := 8

# Fallback colors (used if no theme loaded)
const DEFAULT_LEGAL_MOVE_COLOR := Color(0, 0, 0, 0.2)
const DEFAULT_LEGAL_CAPTURE_COLOR := Color(0.8, 0.2, 0.2, 0.3)
const DEFAULT_PLACEMENT_COLOR := Color(0.3, 0.5, 0.9, 0.9)

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
var recent_collisions: Dictionary = {}  # Track recent collisions to avoid spark spam
var dragging_sprite: PieceSprite = null  # Currently dragged piece
var drag_was_new_selection: bool = false  # Track if drag_started created a new selection

# Mobile layout state
const MOBILE_BREAKPOINT := 800
var is_mobile: bool = false

# Touch input state
var touch_active: bool = false
var last_touch_position: Vector2 = Vector2.ZERO
var long_press_timer: Timer = null
var long_press_start_pos: Vector2 = Vector2.ZERO
const LONG_PRESS_DURATION := 0.5  # seconds

# Touch dragging state (for piece dragging on mobile)
var touch_dragging_piece: bool = false
var touch_drag_sprite: PieceSprite = null
var touch_drag_start_board_pos: Vector2i = Vector2i(-1, -1)
var touch_drag_distance: float = 0.0
const TOUCH_DRAG_THRESHOLD := 10.0  # Minimum distance to count as drag vs tap

# Online multiplayer state
var is_online_mode: bool = false
var my_side: int = Piece.Side.WHITE  # Which side we control in online mode

# Arrow drawing state
var arrow_start_pos: Vector2i = Vector2i(-1, -1)  # Board position where arrow starts
var arrow_piece: Piece = null  # Piece we're drawing arrows from
var is_drawing_arrow: bool = false
var planning_arrows: Array = []  # Persistent arrows drawn by player
var current_arrow: Node2D = null  # Arrow being drawn right now

@onready var board_container: Control = %BoardContainer
@onready var squares_grid: GridContainer = %SquaresGrid
@onready var board_background: ColorRect = $MarginContainer/HBoxContainer/BoardWrapper/BoardContainer/BoardBackground
@onready var grid_layer: Control = %GridLayer
@onready var pieces_layer: Control = %PiecesLayer
@onready var highlights_layer: Control = %HighlightsLayer
@onready var arrows_layer: Control = %ArrowsLayer
@onready var arrival_layer: Control = %ArrivalLayer
@onready var scanlines_overlay: ColorRect = %ScanlinesOverlay

# Grid lines for retrofuturistic theme
var grid_lines: Array = []
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
@onready var about_button: Button = %AboutButton
@onready var history_panel: VBoxContainer = %HistoryPanel
@onready var history_text: TextEdit = %HistoryText
@onready var copy_button: Button = %CopyButton
@onready var about_dialog: PanelContainer = %AboutDialog
@onready var about_description: RichTextLabel = %Description
@onready var about_close_button: Button = %CloseButton
@onready var margin_container: MarginContainer = $MarginContainer
@onready var main_hbox: HBoxContainer = $MarginContainer/HBoxContainer
@onready var side_panel: VBoxContainer = $MarginContainer/HBoxContainer/SidePanel
@onready var status_panel: VBoxContainer = %StatusPanel

# Mobile UI elements (using unique names which work regardless of hierarchy)
@onready var mobile_ui: VBoxContainer = %MobileUI
@onready var mobile_top_bar: PanelContainer = %MobileTopBar
@onready var mobile_turn_indicator: ColorRect = %MobileTurnIndicator
@onready var mobile_turn_label: Label = %MobileTurnLabel
@onready var mobile_status_label: Label = %MobileStatusLabel
@onready var mobile_bottom_bar: VBoxContainer = %MobileBottomBar
@onready var mobile_queue_container: HBoxContainer = %MobileQueueContainer
@onready var mobile_new_game_button: Button = %MobileNewGameButton
@onready var mobile_about_button: Button = %MobileAboutButton

signal new_game_requested


func set_online_mode(enabled: bool, side: int) -> void:
	## Enable online multiplayer mode
	is_online_mode = enabled
	my_side = side


func is_my_turn() -> bool:
	## Returns true if it's our turn in online mode, or always true in local mode
	if not is_online_mode:
		return true
	if game_state == null:
		return false
	return game_state.current_player == my_side


func is_remote_turn() -> bool:
	## Returns true if waiting for remote player's move
	return is_online_mode and not is_my_turn()


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	mobile_new_game_button.pressed.connect(_on_new_game_pressed)
	copy_button.pressed.connect(_on_copy_button_pressed)
	about_button.pressed.connect(_on_about_button_pressed)
	about_close_button.pressed.connect(_on_about_close_pressed)
	about_description.meta_clicked.connect(_on_link_clicked)
	mobile_about_button.pressed.connect(_on_about_button_pressed)
	_create_board()

	# Setup mobile detection and resize handling
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	# Defer initial mobile check - viewport size may not be correct immediately on web
	call_deferred("_initial_layout_setup")

	# Setup long press timer for touch arrow drawing
	long_press_timer = Timer.new()
	long_press_timer.one_shot = true
	long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(long_press_timer)

	# Connect to visual theme changes
	if ThemeManager:
		ThemeManager.visual_theme_changed.connect(_on_visual_theme_changed)
	# Apply initial theme after layout is ready
	call_deferred("_apply_visual_theme")


func _input(event: InputEvent) -> void:
	# Handle theme toggle (T key) - for development/testing
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_toggle_visual_theme()
		get_viewport().set_input_as_handled()
		return

	# Handle touch input (mobile)
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		_handle_touch_drag(event)
		get_viewport().set_input_as_handled()
		return

	# Handle right-click for arrow drawing (desktop)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_start_arrow_drawing()
		else:
			_finish_arrow_drawing()
		get_viewport().set_input_as_handled()
		return

	# Update arrow while dragging
	if event is InputEventMouseMotion and is_drawing_arrow:
		_update_current_arrow()

	# Clear arrows on left click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if planning_arrows.size() > 0:
			_clear_planning_arrows()

		if game_state and game_state.must_place_piece() and not game_state.is_ai_turn() and not is_remote_turn():
			# Use actual square positions to determine column (more robust)
			var col := _get_column_under_cursor()
			if col >= 0 and col < BOARD_SIZE:
				var is_white := game_state.current_player == Piece.Side.WHITE
				var target_row := 0 if is_white else 7
				var target_pos := Vector2i(col, target_row)

				var arriving := game_state.arrival_manager.get_current_piece(game_state.current_player)
				if arriving and game_state.board.can_place_piece_at(target_pos, arriving):
					if game_state.try_place_piece(col):
						# Send placement to remote in online mode
						if is_online_mode:
							NetworkManager.send_placement(col)
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

	# Connect signals
	game_state.turn_changed.connect(_on_turn_changed)
	game_state.status_changed.connect(_on_status_changed)
	game_state.game_over.connect(_on_game_over)
	game_state.promotion_needed.connect(_on_promotion_needed)
	game_state.ai_turn_started.connect(_on_ai_turn_started)
	game_state.ai_thinking_started.connect(_on_ai_thinking_started)
	game_state.ai_thinking_finished.connect(_on_ai_thinking_finished)
	game_state.ai_progress.connect(_on_ai_progress)
	game_state.triplet_clearing.connect(_on_triplet_clearing)
	game_state.board.piece_moved.connect(_on_piece_moved)
	game_state.board.piece_captured.connect(_on_piece_captured)
	game_state.board.piece_placed.connect(_on_piece_placed)
	game_state.move_executed.connect(_on_move_executed)

	# Wait for layout to complete before positioning
	await get_tree().process_frame
	await get_tree().process_frame

	# Initial display
	_refresh_pieces()
	_update_turn_display()
	_update_arrival_display()
	_clear_history_display()

	# Play game start sound
	if AudioManager:
		AudioManager.play_game_start()

	# Check if AI goes first
	if game_state.is_ai_turn():
		_on_ai_turn_started()


func _create_board() -> void:
	squares_grid.columns = BOARD_SIZE

	# Ensure no separation in GridContainer (can cause position mismatch)
	squares_grid.add_theme_constant_override("h_separation", 0)
	squares_grid.add_theme_constant_override("v_separation", 0)

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


func _on_visual_theme_changed(_theme: Resource) -> void:
	_apply_visual_theme()


func _toggle_visual_theme() -> void:
	## Toggle between available visual themes (T key)
	if not ThemeManager:
		return
	var current_id := ThemeManager.get_current_visual_theme_id()
	var themes := ThemeManager.get_available_visual_themes()
	if themes.size() < 2:
		return

	# Find next theme
	var next_idx := 0
	for i in range(themes.size()):
		if themes[i].id == current_id:
			next_idx = (i + 1) % themes.size()
			break

	ThemeManager.set_visual_theme(themes[next_idx].id)
	print("Switched to visual theme: %s" % themes[next_idx].name)


func _apply_visual_theme() -> void:
	## Apply the current visual theme to the board
	var theme: Resource = ThemeManager.get_current_visual_theme() if ThemeManager else null
	if theme == null:
		return

	# Update board background
	if board_background:
		board_background.color = theme.board_background

	# Update grid lines
	_update_grid_lines(theme)

	# Update scanlines overlay
	_update_scanlines(theme)

	# Refresh placement highlights if currently in placement mode
	if game_state and game_state.must_place_piece():
		_show_placement_highlights()


func _update_grid_lines(theme: Resource) -> void:
	## Draw or clear grid lines based on theme
	# Clear existing grid lines
	for line in grid_lines:
		if is_instance_valid(line):
			line.queue_free()
	grid_lines.clear()

	if grid_layer == null or theme.grid_line_width <= 0:
		return

	var grid_size := square_size * BOARD_SIZE

	# Draw vertical and horizontal grid lines
	for i in range(BOARD_SIZE + 1):
		# Vertical line
		var v_line := Line2D.new()
		v_line.width = theme.grid_line_width
		v_line.default_color = theme.grid_line_color
		v_line.add_point(Vector2(i * square_size, 0))
		v_line.add_point(Vector2(i * square_size, grid_size))
		v_line.z_index = 5
		grid_layer.add_child(v_line)
		grid_lines.append(v_line)

		# Horizontal line
		var h_line := Line2D.new()
		h_line.width = theme.grid_line_width
		h_line.default_color = theme.grid_line_color
		h_line.add_point(Vector2(0, i * square_size))
		h_line.add_point(Vector2(grid_size, i * square_size))
		h_line.z_index = 5
		grid_layer.add_child(h_line)
		grid_lines.append(h_line)


func _update_scanlines(theme: Resource) -> void:
	## Enable/disable scanlines effect based on theme
	if scanlines_overlay:
		scanlines_overlay.visible = theme.scanlines_enabled


func _verify_piece_sync() -> void:
	## Check if visual sprites match actual board state, refresh if not
	if game_state == null:
		return

	var needs_refresh := false

	# Check each board position
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var pos := Vector2i(col, row)
			var board_piece := game_state.board.get_piece(pos)
			var has_sprite := pos in piece_sprites

			if board_piece != null and not has_sprite:
				push_warning("Missing sprite at %s" % pos)
				needs_refresh = true
				break
			elif board_piece == null and has_sprite:
				push_warning("Extra sprite at %s" % pos)
				needs_refresh = true
				break
			elif board_piece != null and has_sprite:
				var sprite: PieceSprite = piece_sprites[pos]
				if sprite.piece != board_piece:
					push_warning("Sprite mismatch at %s" % pos)
					needs_refresh = true
					break
		if needs_refresh:
			break

	if needs_refresh:
		push_warning("Board out of sync, refreshing pieces")
		_refresh_pieces()


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

	# Connect drag signals
	sprite.drag_started.connect(_on_piece_drag_started)
	sprite.drag_ended.connect(_on_piece_drag_ended)
	sprite.clicked.connect(_on_piece_clicked)

	return sprite


func _board_to_pixel(board_pos: Vector2i) -> Vector2:
	## Convert board position to pixel position (relative to the grid/layers)
	# Use direct calculation - more reliable than global_position during layout updates
	var display_row := BOARD_SIZE - 1 - board_pos.y
	return Vector2(board_pos.x * square_size, display_row * square_size)


func _on_square_clicked(board_pos: Vector2i) -> void:
	if game_state == null:
		return

	# Ignore clicks during AI's turn or remote player's turn
	if game_state.is_ai_turn() or is_remote_turn():
		return

	# Check if we need to place an arriving piece first
	if game_state.must_place_piece():
		# In arrival mode - try to place piece
		if _try_place_arriving_piece(board_pos):
			_clear_placement_highlights()
			_update_arrival_display()
			_update_turn_display()
		return  # Don't allow normal moves while placing

	# Normal move mode
	if selected_pos == Vector2i(-1, -1):
		# No piece selected - try to select one
		var piece := game_state.board.get_piece(board_pos)
		if piece and piece.side == game_state.current_player:
			_select_piece(board_pos)
	else:
		# Piece already selected
		if board_pos in legal_moves:
			# Valid move - execute it
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

	var success := game_state.try_place_piece(board_pos.x)

	# Send placement to remote player in online mode
	if success and is_online_mode:
		NetworkManager.send_placement(board_pos.x)

	return success


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
	var success := game_state.try_move(from, to)

	# Send move to remote player in online mode
	if success and is_online_mode:
		NetworkManager.send_move(from, to)


func _on_piece_drag_started(sprite: PieceSprite) -> void:
	## Handle piece drag start
	if game_state == null or game_state.is_ai_turn() or is_remote_turn():
		sprite.cancel_drag()
		return

	# Can't drag during placement phase
	if game_state.must_place_piece():
		sprite.cancel_drag()
		return

	# Can only drag current player's pieces
	if sprite.piece.side != game_state.current_player:
		sprite.cancel_drag()
		return

	dragging_sprite = sprite
	# Track if this is a NEW selection (piece wasn't already selected)
	drag_was_new_selection = (selected_pos != sprite.board_position)
	_select_piece(sprite.board_position)


func _on_piece_drag_ended(sprite: PieceSprite, was_drag: bool) -> void:
	## Handle piece drag end
	if dragging_sprite != sprite:
		return

	if not was_drag:
		# Was actually a click, not a drag - handled by clicked signal
		dragging_sprite = null
		return

	# Find what square we're over
	# sprite.position is relative to pieces_layer which is at grid position,
	# so we can calculate board position directly without grid offset
	var sprite_center := sprite.position + sprite.size / 2
	var col := int(sprite_center.x / square_size)
	var display_row := int(sprite_center.y / square_size)
	var board_row := BOARD_SIZE - 1 - display_row
	var drop_pos := Vector2i(col, board_row)

	if drop_pos in legal_moves:
		# Valid move - execute it
		var from_pos := sprite.board_position
		_deselect()
		dragging_sprite = null
		game_state.try_move(from_pos, drop_pos)
	else:
		# Invalid - animate back to original position
		sprite.snap_back()
		_deselect()
		dragging_sprite = null


func _on_piece_clicked(sprite: PieceSprite) -> void:
	## Handle simple click on piece (not a drag)
	var was_new_selection := drag_was_new_selection
	dragging_sprite = null
	drag_was_new_selection = false

	if game_state == null or game_state.is_ai_turn() or is_remote_turn():
		return

	# Can't select during placement phase
	if game_state.must_place_piece():
		return

	# Clicking on current player's piece - select/toggle
	if sprite.piece.side == game_state.current_player:
		if selected_pos == sprite.board_position:
			# Only deselect if this piece was ALREADY selected before the click
			# (not if we just selected it via drag_started in the same click)
			if not was_new_selection:
				_deselect()
			# else: keep it selected (was just selected by this click)
		else:
			_select_piece(sprite.board_position)
	elif selected_pos != Vector2i(-1, -1):
		# Clicking on opponent's piece while we have selection - check if it's a capture
		if sprite.board_position in legal_moves:
			_execute_move(selected_pos, sprite.board_position)
		else:
			_deselect()


func _pixel_to_board(pixel_pos: Vector2) -> Vector2i:
	## Convert pixel position to board coordinates (accounting for grid offset)
	# Subtract grid offset to get position relative to the grid
	var grid_offset := squares_grid.position if squares_grid else Vector2.ZERO
	var adjusted_pos := pixel_pos - grid_offset

	var col := int(adjusted_pos.x / square_size)
	var display_row := int(adjusted_pos.y / square_size)
	var board_row := BOARD_SIZE - 1 - display_row
	return Vector2i(col, board_row)


func _show_legal_moves() -> void:
	_clear_legal_move_indicators()

	var theme: Resource = ThemeManager.get_current_visual_theme() if ThemeManager else null
	var move_color: Color = theme.legal_move_color if theme else DEFAULT_LEGAL_MOVE_COLOR
	var capture_col: Color = theme.capture_color if theme else DEFAULT_LEGAL_CAPTURE_COLOR

	for move_pos in legal_moves:
		var indicator := ColorRect.new()
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var target_piece := game_state.board.get_piece(move_pos)
		if target_piece:
			# Capture indicator - ring around square
			indicator.color = capture_col
			indicator.size = Vector2(square_size, square_size)
		else:
			# Move indicator - small dot in center
			var dot_size := square_size * 0.3
			indicator.color = move_color
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
	_update_turn_display()
	_update_arrival_display()


func _on_status_changed(new_status: GameState.Status) -> void:
	# Play status sounds
	if AudioManager:
		match new_status:
			GameState.Status.CHECK:
				AudioManager.play_check()
			GameState.Status.CHECKMATE:
				AudioManager.play_checkmate()
			GameState.Status.STALEMATE:
				AudioManager.play_stalemate()

	_update_status_display(new_status)


func _on_game_over(winner: int, reason: String) -> void:
	var winner_name := "White" if winner == Piece.Side.WHITE else "Black"
	status_label.text = "%s wins by %s!" % [winner_name, reason]
	# Ensure final board state is visually correct
	call_deferred("_verify_piece_sync")


func _on_piece_moved(from: Vector2i, to: Vector2i, piece: Piece) -> void:
	# Play move sound
	if AudioManager:
		AudioManager.play_move(piece.type)

	# Animate the piece movement
	if from in piece_sprites:
		var sprite = piece_sprites[from]
		var from_pixel := _board_to_pixel(from)
		var to_pixel := _board_to_pixel(to)

		# Check if this is a long move by a sliding piece (rook, bishop, queen)
		var move_distance := maxi(absi(to.x - from.x), absi(to.y - from.y))
		var is_slider := piece.type in [Piece.Type.ROOK, Piece.Type.BISHOP, Piece.Type.QUEEN]
		if is_slider and move_distance > 2:
			_spawn_motion_trail(from_pixel, to_pixel, piece.side)

		sprite.animate_to(to, to_pixel)
		piece_sprites.erase(from)
		piece_sprites[to] = sprite
	else:
		# Sprite not found at expected position - this is a bug, resync
		push_warning("Piece sprite not found at %s, resyncing board" % from)
		call_deferred("_refresh_pieces")

	# Update last move highlights
	_clear_last_move_highlights()
	_get_square(from).set_last_move(true)
	_get_square(to).set_last_move(true)


func _on_piece_captured(pos: Vector2i, _piece: Piece, attacker_from: Vector2i) -> void:
	# Play capture sound
	if AudioManager:
		AudioManager.play_capture()

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


func _spawn_motion_trail(from_pos: Vector2, to_pos: Vector2, side: int) -> void:
	## Spawn motion trail (vauhtiraidat) for fast-moving pieces
	var trail := Line2D.new()
	highlights_layer.add_child(trail)  # Add to highlights layer (renders above board, below pieces)

	# Trail color based on piece side - more visible colors
	var base_color := Color(1.0, 0.95, 0.7) if side == Piece.Side.WHITE else Color(0.5, 0.5, 0.6)

	# Create gradient for fading trail
	var gradient := Gradient.new()
	gradient.set_color(0, Color(base_color, 0.3))  # Semi-transparent at start
	gradient.set_color(1, Color(base_color, 0.8))  # More visible at end
	trail.gradient = gradient

	# Trail properties
	trail.width = square_size * 0.5
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.z_index = 10  # Above highlights

	# Center offset for piece center
	var center_offset := Vector2(square_size / 2, square_size / 2)

	# Add multiple trail lines for "speed stripe" effect
	var direction := (to_pos - from_pos).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)

	# Main center trail
	trail.add_point(from_pos + center_offset)
	trail.add_point(to_pos + center_offset)

	# Add side trails
	for offset_mult in [-0.3, 0.3]:
		var side_trail := Line2D.new()
		highlights_layer.add_child(side_trail)
		side_trail.gradient = gradient
		side_trail.width = square_size * 0.2
		side_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		side_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		side_trail.z_index = 10

		var side_offset: Vector2 = perpendicular * square_size * offset_mult
		side_trail.add_point(from_pos + center_offset + side_offset)
		side_trail.add_point(to_pos + center_offset + side_offset)

		# Fade and remove side trail
		var side_tween := create_tween()
		side_tween.tween_property(side_trail, "modulate:a", 0.0, 0.3).set_delay(0.1)
		side_tween.tween_callback(side_trail.queue_free)

	# Fade and remove main trail
	var tween := create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.35).set_delay(0.05)
	tween.tween_callback(trail.queue_free)


func _get_collision_key(a: PieceSprite, b: PieceSprite) -> String:
	## Generate a unique key for a collision pair
	var id_a := a.get_instance_id()
	var id_b := b.get_instance_id()
	if id_a < id_b:
		return "%d_%d" % [id_a, id_b]
	return "%d_%d" % [id_b, id_a]


func _spawn_collision_sparks(position: Vector2, direction: Vector2) -> void:
	## Spawn spark particles at collision point
	var sparks := CPUParticles2D.new()
	pieces_layer.add_child(sparks)
	sparks.position = position
	sparks.z_index = 200  # Above everything

	# Particle settings
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 12
	sparks.lifetime = 0.4

	# Spread in direction of impact
	sparks.direction = Vector2(direction.x, direction.y)
	sparks.spread = 45.0
	sparks.initial_velocity_min = 150.0
	sparks.initial_velocity_max = 300.0
	sparks.gravity = Vector2(0, 400)

	# Visual appearance - yellow/orange sparks
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	sparks.color = Color(1.0, 0.8, 0.2, 1.0)  # Golden yellow

	# Color gradient for fade
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.3, 1.0))  # Bright yellow
	gradient.set_color(1, Color(1.0, 0.4, 0.1, 0.0))  # Orange fade to transparent
	sparks.color_ramp = gradient

	# Auto-remove after particles finish
	get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)


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
				# Collision! Push the board piece and spawn sparks
				# Weight affects how much the target piece moves
				var push_dir := (other_center - bumping_center).normalized()
				var attacker_weight := bumping.get_weight()
				board_sprite.nudge(push_dir, 0.4, attacker_weight)

				# Only spawn sparks/sound if we haven't recently for this pair
				var collision_key := _get_collision_key(bumping, board_sprite)
				var now := Time.get_ticks_msec()
				if not recent_collisions.has(collision_key) or now - recent_collisions[collision_key] > 100:
					recent_collisions[collision_key] = now
					var collision_point := (bumping_center + other_center) / 2
					_spawn_collision_sparks(collision_point, push_dir)
					# Play collision sound
					if AudioManager:
						AudioManager.play_collision()

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

	# Clean up old collision tracking entries (older than 500ms)
	var now := Time.get_ticks_msec()
	var keys_to_remove: Array = []
	for key in recent_collisions:
		if now - recent_collisions[key] > 500:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		recent_collisions.erase(key)


func _on_piece_placed(pos: Vector2i, piece: Piece) -> void:
	# Play placement sound
	if AudioManager:
		AudioManager.play_place()

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


func _on_triplet_clearing(triplet_positions: Array, victim_pos: Vector2i, direction: Vector2i) -> void:
	## Animate the triplet pieces moving in a line and bumping out victim
	# Play special clear sound
	if AudioManager:
		AudioManager.play_triplet_clear()

	# Convert direction to screen space (Y is inverted in display)
	var screen_dir := Vector2(direction.x, -direction.y)

	# Sort triplet by movement order (front to back based on direction)
	var sorted_positions := triplet_positions.duplicate()
	if direction.x > 0 or direction.y > 0:
		sorted_positions.reverse()  # Front pieces first

	# Calculate animation parameters
	var exit_offset := screen_dir * square_size * 12  # Exit off screen
	var delay_per_piece := 0.08  # Stagger animation

	# Animate each triplet piece
	for i in range(sorted_positions.size()):
		var pos: Vector2i = sorted_positions[i]
		if pos in piece_sprites:
			var sprite: PieceSprite = piece_sprites[pos]
			piece_sprites.erase(pos)

			var start_delay := i * delay_per_piece
			var target := sprite.position + exit_offset

			# Create tween for smooth exit
			var tween := create_tween()
			tween.tween_property(sprite, "position", target, 0.5).set_delay(start_delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3).set_delay(start_delay + 0.3)
			tween.tween_callback(sprite.queue_free)

	# Bump the victim if exists
	if victim_pos != Vector2i(-1, -1) and victim_pos in piece_sprites:
		var victim_sprite: PieceSprite = piece_sprites[victim_pos]
		piece_sprites.erase(victim_pos)

		# Victim gets bumped after triplet passes
		var bump_delay := sorted_positions.size() * delay_per_piece + 0.2
		await get_tree().create_timer(bump_delay).timeout

		if is_instance_valid(victim_sprite):
			victim_sprite.home_position = victim_sprite.position
			victim_sprite.start_bump(screen_dir, square_size * 8.0)
			bumping_pieces.append(victim_sprite)


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
	var text := "%s to %s" % [current, action]

	# In online mode, show "Your turn" or "Opponent's turn"
	if is_online_mode:
		if is_my_turn():
			text = "Your turn to %s" % action
		else:
			text = "Opponent's turn..."

	# Update desktop turn display
	turn_label.text = text
	if turn_indicator:
		turn_indicator.color = Color.WHITE if is_white else Color.BLACK

	# Update mobile turn display
	if is_mobile:
		mobile_turn_label.text = text
		if mobile_turn_indicator:
			mobile_turn_indicator.color = Color.WHITE if is_white else Color.BLACK
		_update_mobile_queue_display()


func _update_status_display(status: GameState.Status) -> void:
	var text := ""
	match status:
		GameState.Status.PLAYING:
			text = ""
		GameState.Status.CHECK:
			text = "Check!"
		GameState.Status.CHECKMATE:
			text = "Checkmate!"
		GameState.Status.STALEMATE:
			text = "Stalemate!"
		GameState.Status.DRAW:
			text = "Draw!"

	# Update both desktop and mobile
	status_label.text = text
	if is_mobile and mobile_status_label:
		mobile_status_label.text = text


func _update_arrival_display() -> void:
	if game_state == null:
		return

	var can_place := game_state.must_place_piece()

	# Hide the side panel arrival UI - we use hovering piece instead
	if arrival_panel:
		arrival_panel.visible = false

	# Show or clear placement highlights
	if can_place and not game_state.is_ai_turn():
		_show_placement_highlights()
	else:
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
	# Use piece set from settings (reuse PieceSprite constants)
	var piece_set: String = Settings.piece_set
	if not PieceSprite.PIECE_SETS.has(piece_set):
		piece_set = "standard"
	var base_path: String = PieceSprite.PIECE_SETS[piece_set]
	var filename: String = PieceSprite.PIECE_FILES[side][piece_type]
	return load(base_path + filename)


func _show_placement_highlights() -> void:
	## Show LED-style indicators around valid placement squares
	_clear_placement_highlights()

	if game_state == null or not game_state.must_place_piece():
		return

	# Don't show highlights during AI's turn
	if game_state.is_ai_turn():
		return

	var arriving := game_state.arrival_manager.get_current_piece(game_state.current_player)
	if arriving == null:
		return

	var is_white := game_state.current_player == Piece.Side.WHITE
	var target_row := 0 if is_white else 7

	# Check each column on the back row
	for col in range(BOARD_SIZE):
		var target_pos := Vector2i(col, target_row)

		# Check if placement is valid at this position
		if game_state.board.can_place_piece_at(target_pos, arriving):
			# Create LED indicator around the valid square
			var indicator := _create_led_placement_indicator(col, is_white)
			highlights_layer.add_child(indicator)
			legal_move_indicators.append(indicator)


func _create_led_placement_indicator(col: int, is_white: bool) -> Control:
	## Create a glowing LED-style rectangle outline around a placement square
	var theme: Resource = ThemeManager.get_current_visual_theme() if ThemeManager else null
	var indicator_color: Color = theme.placement_indicator_color if theme else DEFAULT_PLACEMENT_COLOR
	var glow_col: Color = theme.placement_glow_color if theme else DEFAULT_PLACEMENT_COLOR
	var glow_enabled: bool = theme.placement_glow_enabled if theme else true

	var indicator := Control.new()
	var row := 0 if is_white else 7
	var pos := _board_to_pixel(Vector2i(col, row))

	# Create glowing rectangle outline using Line2D
	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = indicator_color
	outline.closed = true
	outline.antialiased = true
	outline.z_index = 10

	# Rectangle points with slight inset
	var inset := 4.0
	var rect_size := square_size - inset * 2
	outline.add_point(Vector2(inset, inset))
	outline.add_point(Vector2(inset + rect_size, inset))
	outline.add_point(Vector2(inset + rect_size, inset + rect_size))
	outline.add_point(Vector2(inset, inset + rect_size))

	indicator.add_child(outline)
	indicator.position = pos
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Add glow animation
	if glow_enabled:
		_add_glow_animation(outline, glow_col)

	return indicator


func _add_glow_animation(node: Line2D, glow_color: Color) -> void:
	## Add a pulsing glow animation to a Line2D
	node.default_color = glow_color
	var tween := create_tween().set_loops()
	tween.tween_property(node, "modulate:a", 0.5, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)


func _update_hovering_piece() -> void:
	## Update the hovering arrival piece position based on mouse/touch
	if game_state == null or not game_state.must_place_piece():
		hovering_piece.visible = false
		ghost_piece.visible = false
		hovered_column = -1
		# Clear any bishop placement warning when leaving placement mode
		if status_label.text.begins_with("Bishop"):
			status_label.text = ""
			if is_mobile and mobile_status_label:
				mobile_status_label.text = ""
		return

	var is_white := game_state.current_player == Piece.Side.WHITE
	var target_row := 0 if is_white else 7

	# Find which column the cursor is over by checking actual square positions
	var col := _get_column_under_cursor()
	if col < 0:
		col = 0  # Fallback to first column if cursor is outside

	var target_pos := Vector2i(col, target_row)
	var arriving := game_state.arrival_manager.get_current_piece(game_state.current_player)
	var is_valid := arriving != null and game_state.board.can_place_piece_at(target_pos, arriving)

	# Update hovering piece
	if arriving:
		hovering_piece.texture = _get_piece_texture(arriving.type, arriving.side)
		hovering_piece.size = Vector2(square_size, square_size)
		hovering_piece.visible = true

		# Get the actual X position from the target square's global position
		var target_square = _get_square(target_pos)
		var hover_global_x: float
		if target_square:
			hover_global_x = target_square.global_position.x
		else:
			hover_global_x = arrival_layer.global_position.x + col * square_size

		# Position the piece in the arrival area (outside the board)
		var hover_global_y: float
		if is_white:
			# White places on row 0 (bottom of display), so hover below board
			var bottom_square = _get_square(Vector2i(0, 0))
			if bottom_square:
				hover_global_y = bottom_square.global_position.y + square_size + 5
			else:
				hover_global_y = arrival_layer.global_position.y + BOARD_SIZE * square_size + 5
		else:
			# Black places on row 7 (top of display), so hover above board
			var top_square = _get_square(Vector2i(0, 7))
			if top_square:
				hover_global_y = top_square.global_position.y - square_size - 5
			else:
				hover_global_y = arrival_layer.global_position.y - square_size - 5

		hovering_piece.global_position = Vector2(hover_global_x, hover_global_y)

		# Add a gentle bobbing animation
		var bob := sin(Time.get_ticks_msec() / 200.0) * 3.0
		hovering_piece.position.y += bob

		# Tint the piece if column is invalid
		if is_valid:
			hovering_piece.modulate = Color.WHITE
			# Clear any bishop placement warning
			if arriving.type == Piece.Type.BISHOP and status_label.text.begins_with("Bishop"):
				status_label.text = ""
				if is_mobile and mobile_status_label:
					mobile_status_label.text = ""
		else:
			hovering_piece.modulate = Color(1, 0.5, 0.5, 0.7)  # Reddish tint
			# Show reason for invalid placement for bishops
			if arriving.type == Piece.Type.BISHOP and game_state.board.is_empty(target_pos):
				var square_color_name := "dark" if (col + target_row) % 2 == 0 else "light"
				var msg := "Bishop on %s squares already" % square_color_name
				status_label.text = msg
				if is_mobile and mobile_status_label:
					mobile_status_label.text = msg

		# Show ghost on target square if valid
		if is_valid:
			ghost_piece.texture = hovering_piece.texture
			ghost_piece.size = Vector2(square_size, square_size)
			# Position ghost exactly on the target square using its actual global position
			if target_square:
				ghost_piece.global_position = target_square.global_position
			else:
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


var _force_next_resize: bool = false  # Flag to force resize even if size unchanged


func _on_resized() -> void:
	# Recalculate square size based on available space
	if board_container == null or squares_grid == null:
		return

	var available := mini(board_container.size.x, board_container.size.y)

	# Skip if available size is too small (layout not ready)
	if available < 100:
		return

	var new_square_size: float = available / BOARD_SIZE

	# Calculate new board position
	var grid_size: float = new_square_size * BOARD_SIZE
	var offset_x: float = maxf(0, (board_container.size.x - grid_size) / 2)
	var offset_y: float = maxf(0, (board_container.size.y - grid_size) / 2)
	var new_board_pos := Vector2(offset_x, offset_y)

	# Check if anything actually changed (size OR position)
	var size_changed := absf(new_square_size - square_size) >= 0.1
	var pos_changed := squares_grid.position.distance_to(new_board_pos) >= 0.1
	var force := _force_next_resize
	_force_next_resize = false

	if not force and not size_changed and not pos_changed:
		return

	square_size = new_square_size

	# Update square sizes
	for row in squares:
		for square in row:
			square.custom_minimum_size = Vector2(square_size, square_size)

	# Position all layers
	squares_grid.position = new_board_pos
	if grid_layer:
		grid_layer.position = new_board_pos
	pieces_layer.position = new_board_pos
	highlights_layer.position = new_board_pos
	arrows_layer.position = new_board_pos
	arrival_layer.position = new_board_pos

	# Update grid lines for new size
	var theme := ThemeManager.get_current_visual_theme() if ThemeManager else null
	if theme:
		_update_grid_lines(theme)

	# Resize and position the background to match the board
	if board_background:
		board_background.position = new_board_pos
		board_background.size = Vector2(grid_size, grid_size)

	# Always reposition pieces when layout changes
	for pos in piece_sprites:
		var sprite = piece_sprites[pos]
		sprite.size = Vector2(square_size, square_size)
		sprite.custom_minimum_size = Vector2(square_size, square_size)
		sprite.position = _board_to_pixel(pos)


func _initial_layout_setup() -> void:
	## Called after _ready to set up initial layout (deferred for correct viewport size)
	# Wait one more frame for viewport to fully initialize (important for web/iOS)
	await get_tree().process_frame
	_check_mobile_mode(true)  # Force update on initial setup
	_on_resized()


func _on_viewport_size_changed() -> void:
	## Handle viewport size changes (including orientation changes)
	_check_mobile_mode(false)
	# Force resize after orientation changes to ensure pieces are repositioned
	_force_next_resize = true
	# Always trigger resize on viewport change to handle orientation changes
	# even when mobile mode doesn't change (e.g., portrait to landscape on phone)
	call_deferred("_deferred_resize_update")


func _check_mobile_mode(force_update: bool = false) -> void:
	## Check viewport size and switch layout mode if needed
	var viewport_size: Vector2i = get_viewport().size

	# Detect mobile by checking if viewport is too narrow for side panel layout
	# Use a reasonable breakpoint - side panel needs ~200px, so below ~900px total is tight
	# Also check for portrait on small screens (phones)
	var is_narrow: bool = viewport_size.x < MOBILE_BREAKPOINT  # 800px
	var is_portrait_and_small: bool = viewport_size.y > viewport_size.x and viewport_size.x < 1200
	var new_is_mobile: bool = is_narrow or is_portrait_and_small

	if force_update or new_is_mobile != is_mobile:
		is_mobile = new_is_mobile
		_update_layout()


func _update_layout() -> void:
	## Update UI layout for mobile or desktop mode
	if margin_container == null:
		return

	if is_mobile:
		# Mobile layout: minimal margins, hide side panel, show mobile UI overlay
		# Leave space at top for mobile status bar and bottom for controls
		margin_container.add_theme_constant_override("margin_left", 4)
		margin_container.add_theme_constant_override("margin_top", 60)  # Space for mobile top bar
		margin_container.add_theme_constant_override("margin_right", 4)
		margin_container.add_theme_constant_override("margin_bottom", 130)  # Space for mobile bottom bar + queue

		# Hide side panel - board will expand to fill space
		if side_panel:
			side_panel.visible = false

		# Hide arrival areas AND collapse their space on mobile
		if black_arrival_area:
			black_arrival_area.visible = false
			black_arrival_area.custom_minimum_size = Vector2(0, 0)
		if white_arrival_area:
			white_arrival_area.visible = false
			white_arrival_area.custom_minimum_size = Vector2(0, 0)

		# Show mobile UI overlay (positioned absolutely)
		if mobile_ui:
			mobile_ui.visible = true

		# Hide history panel on mobile (no space)
		if history_panel:
			history_panel.visible = false

		# Update mobile display
		_update_mobile_display()
	else:
		# Desktop layout: normal margins, show side panel, hide mobile UI
		margin_container.add_theme_constant_override("margin_left", 20)
		margin_container.add_theme_constant_override("margin_top", 20)
		margin_container.add_theme_constant_override("margin_right", 20)
		margin_container.add_theme_constant_override("margin_bottom", 20)

		if side_panel:
			side_panel.visible = true

		# Show arrival areas on desktop and restore their minimum size
		if black_arrival_area:
			black_arrival_area.visible = true
			black_arrival_area.custom_minimum_size = Vector2(0, 70)
		if white_arrival_area:
			white_arrival_area.visible = true
			white_arrival_area.custom_minimum_size = Vector2(0, 70)

		if mobile_ui:
			mobile_ui.visible = false

		# Show history panel on desktop
		if history_panel:
			history_panel.visible = true

	# Force layout recalculation after layout settles
	# Use multiple deferred calls to ensure layout has fully updated
	call_deferred("_on_resized")
	call_deferred("_deferred_resize_update")


func _deferred_resize_update() -> void:
	## Called after layout changes to ensure pieces are correctly positioned
	## This runs after the first deferred _on_resized, giving layout time to settle
	## Wait multiple frames for layout to fully settle (important for orientation changes)
	for i in range(3):
		await get_tree().process_frame
	_on_resized()
	# One more update after additional settling
	await get_tree().process_frame
	_on_resized()


func _update_mobile_display() -> void:
	## Update mobile UI elements with current game state
	if not is_mobile or game_state == null:
		return

	# Update mobile turn display
	var is_white := game_state.current_player == Piece.Side.WHITE
	var current := "White" if is_white else "Black"
	var action := "place" if game_state.must_place_piece() else "move"
	mobile_turn_label.text = "%s to %s" % [current, action]

	if mobile_turn_indicator:
		mobile_turn_indicator.color = Color.WHITE if is_white else Color.BLACK

	# Update mobile queue display
	_update_mobile_queue_display()


func _update_mobile_queue_display() -> void:
	## Update the mobile queue preview
	if not is_mobile or game_state == null or mobile_queue_container == null:
		return

	# Clear existing preview sprites
	for child in mobile_queue_container.get_children():
		child.queue_free()

	# Get upcoming pieces
	var preview_count := mini(Settings.piece_preview_count, 4)  # Limit on mobile
	var upcoming := game_state.arrival_manager.get_upcoming_pieces(game_state.current_player, preview_count)

	# Create preview sprites
	for piece_type in upcoming:
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(40, 40)
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = _get_piece_texture(piece_type, game_state.current_player)
		mobile_queue_container.add_child(preview)


# Touch input handling (mobile)

func _handle_touch_event(event: InputEventScreenTouch) -> void:
	## Handle touch start/end events
	last_touch_position = event.position
	touch_active = event.pressed

	if event.pressed:
		# Touch started - start long press detection for arrow drawing
		long_press_start_pos = event.position
		long_press_timer.start(LONG_PRESS_DURATION)

		# Clear existing planning arrows on tap
		if planning_arrows.size() > 0:
			_clear_planning_arrows()

		# Check if touching a piece for potential drag
		_start_touch_piece_drag(event.position)
	else:
		# Touch ended
		long_press_timer.stop()

		if is_drawing_arrow:
			# Finish arrow drawing
			_finish_arrow_drawing()
		elif touch_dragging_piece:
			# End piece drag
			_end_touch_piece_drag(event.position)
		else:
			# This was a tap - simulate click
			_handle_touch_tap(event.position)


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	## Handle touch drag events
	var prev_pos := last_touch_position
	last_touch_position = event.position

	# Cancel long press if finger moved too far
	if long_press_timer.time_left > 0:
		var drag_dist := event.position.distance_to(long_press_start_pos)
		if drag_dist > 20:  # 20px threshold
			long_press_timer.stop()

	# Update piece position while dragging
	if touch_dragging_piece and touch_drag_sprite:
		touch_drag_distance += event.position.distance_to(prev_pos)
		_update_touch_piece_drag(event.position)
		return

	# Update arrow while drawing
	if is_drawing_arrow:
		_update_current_arrow()


func _start_touch_piece_drag(screen_pos: Vector2) -> void:
	## Check if touching a piece and start dragging if valid
	if game_state == null or game_state.is_ai_turn() or is_remote_turn():
		return

	# Can't drag during placement phase
	if game_state.must_place_piece():
		return

	# Find board position
	var local_pos := board_container.get_global_transform().affine_inverse() * screen_pos
	var board_pos := _pixel_to_board(local_pos)

	if not _is_valid_board_pos(board_pos):
		return

	# Check if there's a piece we can drag
	var piece := game_state.board.get_piece(board_pos)
	if piece == null or piece.side != game_state.current_player:
		return

	# Get the sprite
	if board_pos not in piece_sprites:
		return

	var sprite: PieceSprite = piece_sprites[board_pos]

	# Start the drag
	touch_dragging_piece = true
	touch_drag_sprite = sprite
	touch_drag_start_board_pos = board_pos
	touch_drag_distance = 0.0

	# Select the piece and show legal moves
	_select_piece(board_pos)

	# Visual feedback - bring to front
	sprite.z_index = 50


func _update_touch_piece_drag(screen_pos: Vector2) -> void:
	## Update dragged piece position
	if touch_drag_sprite == null:
		return

	# Convert screen position to position relative to pieces_layer
	var local_pos := pieces_layer.get_global_transform().affine_inverse() * screen_pos
	# Center the piece on the finger
	var new_pos := local_pos - touch_drag_sprite.size / 2
	touch_drag_sprite.position = new_pos


func _end_touch_piece_drag(screen_pos: Vector2) -> void:
	## End piece drag - execute move if valid, snap back if not
	if touch_drag_sprite == null:
		touch_dragging_piece = false
		return

	var was_actual_drag := touch_drag_distance >= TOUCH_DRAG_THRESHOLD

	if was_actual_drag:
		# Find what square we're over
		var local_pos := board_container.get_global_transform().affine_inverse() * screen_pos
		var drop_pos := _pixel_to_board(local_pos)

		if drop_pos in legal_moves:
			# Valid move - execute it
			var from_pos := touch_drag_start_board_pos
			touch_drag_sprite.z_index = 0
			touch_drag_sprite = null
			touch_dragging_piece = false
			_deselect()
			game_state.try_move(from_pos, drop_pos)

			# Send move to remote in online mode
			if is_online_mode:
				NetworkManager.send_move(from_pos, drop_pos)
			return
		else:
			# Invalid drop - snap back
			touch_drag_sprite.snap_back()
	else:
		# Was just a tap - snap back and keep selection
		touch_drag_sprite.position = _board_to_pixel(touch_drag_start_board_pos)

	# Reset drag state
	touch_drag_sprite.z_index = 0
	touch_drag_sprite = null
	touch_dragging_piece = false

	# If it was just a tap, toggle selection
	if not was_actual_drag:
		# Selection is already set, nothing more to do
		pass


func _on_long_press_timeout() -> void:
	## Called when long press is detected - start arrow drawing
	if touch_active:
		_start_arrow_drawing_at(last_touch_position)


func _handle_touch_tap(position: Vector2) -> void:
	## Handle a touch tap as a click
	# Store touch position for _get_column_under_cursor
	last_touch_position = position
	touch_active = true

	# Handle piece placement using actual square positions
	if game_state and game_state.must_place_piece() and not game_state.is_ai_turn() and not is_remote_turn():
		var col := _get_column_under_cursor()
		if col >= 0 and col < BOARD_SIZE:
			var is_white := game_state.current_player == Piece.Side.WHITE
			var target_row := 0 if is_white else 7
			var target_pos := Vector2i(col, target_row)

			var arriving := game_state.arrival_manager.get_current_piece(game_state.current_player)
			if arriving and game_state.board.can_place_piece_at(target_pos, arriving):
				if game_state.try_place_piece(col):
					# Send placement to remote in online mode
					if is_online_mode:
						NetworkManager.send_placement(col)
					_clear_placement_highlights()
					_update_arrival_display()
					_update_turn_display()
					touch_active = false
					return

	# Handle normal square click
	var local_pos := board_container.get_global_transform().affine_inverse() * position
	var board_pos := _pixel_to_board(local_pos)
	touch_active = false

	if _is_valid_board_pos(board_pos):
		_on_square_clicked(board_pos)


func _start_arrow_drawing_at(screen_position: Vector2) -> void:
	## Start arrow drawing from a specific screen position (for touch)
	var local_pos := board_container.get_global_transform().affine_inverse() * screen_position
	var board_pos := _pixel_to_board(local_pos)

	if not _is_valid_board_pos(board_pos):
		return

	var piece := game_state.board.get_piece(board_pos) if game_state else null
	if piece == null:
		return

	arrow_start_pos = board_pos
	arrow_piece = piece
	is_drawing_arrow = true

	current_arrow = _create_arrow_node()
	arrows_layer.add_child(current_arrow)


func _get_input_position() -> Vector2:
	## Get current input position relative to the grid (works for both mouse and touch)
	var container_pos: Vector2
	if touch_active:
		container_pos = board_container.get_global_transform().affine_inverse() * last_touch_position
	else:
		container_pos = board_container.get_local_mouse_position()

	# Subtract grid offset to get position relative to the grid
	var grid_offset := squares_grid.position if squares_grid else Vector2.ZERO
	return container_pos - grid_offset


func _get_column_under_cursor() -> int:
	## Find which column the cursor is over by checking actual square global positions
	## Returns -1 if cursor is outside all columns
	var cursor_global: Vector2
	if touch_active:
		cursor_global = last_touch_position
	else:
		cursor_global = get_global_mouse_position()

	# Check each column by looking at the first row's squares
	for col in range(BOARD_SIZE):
		var square: Control = squares[0][col]  # Any row works since columns are aligned
		var square_rect: Rect2 = square.get_global_rect()
		# Extend the rect vertically to cover the full board height plus arrival areas
		square_rect.position.y -= square_size * 2  # Extend above
		square_rect.size.y = square_size * (BOARD_SIZE + 4)  # Cover full height plus margins
		if cursor_global.x >= square_rect.position.x and cursor_global.x < square_rect.position.x + square_rect.size.x:
			return col

	# Cursor is outside - determine closest column
	var first_square = squares[0][0]
	var last_square = squares[0][BOARD_SIZE - 1]
	if cursor_global.x < first_square.get_global_rect().position.x:
		return 0
	elif cursor_global.x >= last_square.get_global_rect().position.x:
		return BOARD_SIZE - 1
	return -1


# Promotion dialog handling

func _on_promotion_needed(pos: Vector2i, side: int) -> void:
	# If it's AI's turn, auto-select Queen (best choice in almost all cases)
	if game_state and game_state.is_ai_turn():
		# Small delay so player can see the pawn reaching the rank
		await get_tree().create_timer(0.2).timeout
		game_state.complete_promotion(Piece.Type.QUEEN)
		_update_turn_display()
		_update_arrival_display()
		return

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

	# Send promotion to remote player in online mode
	if is_online_mode:
		NetworkManager.send_promotion(piece_type)

	# Update displays
	_update_turn_display()
	_update_arrival_display()


# AI handling

func _on_ai_turn_started() -> void:
	# Add a small delay so the player can see the board state
	await get_tree().create_timer(0.3).timeout

	if game_state == null:
		return

	# Request AI to make its move
	game_state.request_ai_move()


func _on_new_game_pressed() -> void:
	new_game_requested.emit()


func _on_ai_thinking_started() -> void:
	var text := "AI thinking..."
	status_label.text = text
	if is_mobile and mobile_status_label:
		mobile_status_label.text = text


func _on_ai_thinking_finished() -> void:
	_update_status_display(game_state.status)


func _on_ai_progress(percent: float) -> void:
	var text := "AI thinking... %d%%" % int(percent * 100)
	status_label.text = text
	if is_mobile and mobile_status_label:
		mobile_status_label.text = text


# Arrow drawing for move planning

func _start_arrow_drawing() -> void:
	## Start drawing an arrow from the clicked square
	var local_pos := board_container.get_local_mouse_position()
	var board_pos := _pixel_to_board(local_pos)

	# Check if position is valid and has a piece
	if not _is_valid_board_pos(board_pos):
		return

	var piece := game_state.board.get_piece(board_pos) if game_state else null
	if piece == null:
		return

	arrow_start_pos = board_pos
	arrow_piece = piece
	is_drawing_arrow = true

	# Create the current arrow visual
	current_arrow = _create_arrow_node()
	arrows_layer.add_child(current_arrow)


func _update_current_arrow() -> void:
	## Update the arrow being drawn to follow mouse/touch
	if current_arrow == null or arrow_piece == null:
		return

	var local_pos := _get_input_position()
	var target_pos := _pixel_to_board(local_pos)

	# Check if target is valid for this piece's movement pattern
	var is_valid := _is_valid_arrow_target(arrow_start_pos, target_pos, arrow_piece)
	var is_knight := arrow_piece.type == Piece.Type.KNIGHT

	# Update arrow visual
	var start_pixel := _board_to_pixel(arrow_start_pos) + Vector2(square_size / 2, square_size / 2)
	var end_pixel := _board_to_pixel(target_pos) + Vector2(square_size / 2, square_size / 2)

	_update_arrow_visual(current_arrow, start_pixel, end_pixel, is_valid, is_knight)


func _finish_arrow_drawing() -> void:
	## Finish drawing and potentially save the arrow
	if not is_drawing_arrow:
		return

	is_drawing_arrow = false

	if current_arrow == null or arrow_piece == null:
		return

	var local_pos := _get_input_position()
	var target_pos := _pixel_to_board(local_pos)

	# Only save valid arrows that go to a different square
	if target_pos != arrow_start_pos and _is_valid_arrow_target(arrow_start_pos, target_pos, arrow_piece):
		# Check if this arrow already exists (toggle off)
		var existing_idx := _find_existing_arrow(arrow_start_pos, target_pos)
		if existing_idx >= 0:
			# Remove existing arrow
			planning_arrows[existing_idx].queue_free()
			planning_arrows.remove_at(existing_idx)
			current_arrow.queue_free()
		else:
			# Keep this arrow
			planning_arrows.append(current_arrow)
	else:
		# Invalid or same square - remove
		current_arrow.queue_free()

	current_arrow = null
	arrow_piece = null
	arrow_start_pos = Vector2i(-1, -1)


func _find_existing_arrow(from: Vector2i, to: Vector2i) -> int:
	## Find if an arrow already exists between these squares
	for i in range(planning_arrows.size()):
		var arrow = planning_arrows[i]
		if arrow.has_meta("from") and arrow.has_meta("to"):
			if arrow.get_meta("from") == from and arrow.get_meta("to") == to:
				return i
	return -1


func _clear_planning_arrows() -> void:
	## Clear all planning arrows
	for arrow in planning_arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	planning_arrows.clear()


func _create_arrow_node() -> Node2D:
	## Create a new arrow visual node
	var arrow := Node2D.new()
	var line := Line2D.new()
	line.name = "Line"
	line.width = 12.0
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	arrow.add_child(line)

	# Arrow head (triangle)
	var head := Polygon2D.new()
	head.name = "Head"
	arrow.add_child(head)

	return arrow


func _update_arrow_visual(arrow: Node2D, start: Vector2, end: Vector2, is_valid: bool, is_knight: bool = false) -> void:
	## Update arrow visuals
	var line: Line2D = arrow.get_node("Line")
	var head: Polygon2D = arrow.get_node("Head")

	# Color based on validity
	var color := Color(0.2, 0.7, 0.3, 0.8) if is_valid else Color(0.7, 0.3, 0.2, 0.5)
	line.default_color = color
	head.color = color

	var head_size := 20.0
	var direction: Vector2
	var final_end := end

	line.clear_points()

	if is_knight and is_valid:
		# Knight arrows show L-shaped path
		var dx := end.x - start.x
		var dy := end.y - start.y
		var abs_dx := absf(dx)
		var abs_dy := absf(dy)

		# Determine L-shape: go horizontal first if dx > dy, else vertical first
		var corner: Vector2
		if abs_dx > abs_dy:
			# Move horizontal first, then vertical
			corner = Vector2(end.x, start.y)
		else:
			# Move vertical first, then horizontal
			corner = Vector2(start.x, end.y)

		# Calculate final direction for arrow head
		direction = (end - corner).normalized()
		final_end = end - direction * head_size * 0.7

		line.add_point(start)
		line.add_point(corner)
		line.add_point(final_end)
	else:
		# Straight line for other pieces
		direction = (end - start).normalized()
		var arrow_length := start.distance_to(end)

		if arrow_length > head_size:
			line.add_point(start)
			line.add_point(end - direction * head_size * 0.7)
		else:
			direction = Vector2.RIGHT  # Fallback

	# Arrow head triangle
	if line.get_point_count() > 0:
		var perp := Vector2(-direction.y, direction.x)
		head.polygon = PackedVector2Array([
			end,
			end - direction * head_size + perp * head_size * 0.5,
			end - direction * head_size - perp * head_size * 0.5
		])
	else:
		head.polygon = PackedVector2Array()

	# Store metadata for duplicate detection
	var from_pos := _pixel_to_board(start - Vector2(square_size / 2, square_size / 2))
	var to_pos := _pixel_to_board(end - Vector2(square_size / 2, square_size / 2))
	arrow.set_meta("from", from_pos)
	arrow.set_meta("to", to_pos)


func _is_valid_board_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE


func _is_valid_arrow_target(from: Vector2i, to: Vector2i, piece: Piece) -> bool:
	## Check if moving from->to matches this piece's movement pattern (ignoring blockers)
	if not _is_valid_board_pos(to):
		return false
	if from == to:
		return false

	var dx := to.x - from.x
	var dy := to.y - from.y
	var abs_dx := absi(dx)
	var abs_dy := absi(dy)

	match piece.type:
		Piece.Type.KING:
			# One square in any direction
			return abs_dx <= 1 and abs_dy <= 1

		Piece.Type.QUEEN:
			# Straight or diagonal any distance
			return (dx == 0 or dy == 0) or (abs_dx == abs_dy)

		Piece.Type.ROOK:
			# Straight lines only
			return dx == 0 or dy == 0

		Piece.Type.BISHOP:
			# Diagonal only
			return abs_dx == abs_dy and abs_dx > 0

		Piece.Type.KNIGHT:
			# L-shape: 2+1 or 1+2
			return (abs_dx == 2 and abs_dy == 1) or (abs_dx == 1 and abs_dy == 2)

		Piece.Type.PAWN:
			# Forward 1-2 squares or diagonal capture (1 square)
			var forward := 1 if piece.side == Piece.Side.WHITE else -1
			# Forward moves
			if dx == 0 and (dy == forward or dy == forward * 2):
				return true
			# Diagonal captures
			if abs_dx == 1 and dy == forward:
				return true
			return false

	return false


# ─────────────────────────────────────────────────────────────────────────────
# Move History
# ─────────────────────────────────────────────────────────────────────────────

var move_number: int = 1  # Current move number for notation

func _on_move_executed(_move_data: Dictionary) -> void:
	## Called when a move is made - update the history display
	_update_history_display()


func _clear_history_display() -> void:
	## Clear the move history display
	if history_text:
		history_text.text = ""


func _update_history_display() -> void:
	## Rebuild the move history text from game_state.move_history
	if game_state == null or history_text == null:
		return

	var text := ""
	var move_num := 1

	for i in range(game_state.move_history.size()):
		var move_data: Dictionary = game_state.move_history[i]
		var notation := _move_to_notation(move_data)

		# Determine if this is white's or black's move based on piece side
		var piece = move_data.get("piece", move_data.get("moved_piece"))
		var is_white_move: bool = piece != null and piece.side == Piece.Side.WHITE

		if is_white_move:
			text += "%d. %s " % [move_num, notation]
		else:
			text += "%s\n" % notation
			move_num += 1

	# Handle case where last move was white's (no newline yet)
	if text.length() > 0 and not text.ends_with("\n"):
		text = text.strip_edges()

	history_text.text = text

	# Scroll to bottom
	await get_tree().process_frame
	if history_text:
		history_text.scroll_vertical = history_text.get_v_scroll_bar().max_value


func _move_to_notation(move_data: Dictionary) -> String:
	## Convert move data to algebraic notation (e.g., "Nf3", "exd5", "O-O")
	var from: Vector2i = move_data.get("from", Vector2i(-1, -1))
	var to: Vector2i = move_data.get("to", Vector2i(-1, -1))
	var piece = move_data.get("piece", move_data.get("moved_piece"))
	var captured = move_data.get("captured", move_data.get("captured_piece"))
	var special: String = move_data.get("special", "")

	if piece == null:
		return "?"

	# Handle castling
	if special == "castle_kingside":
		return "O-O"
	elif special == "castle_queenside":
		return "O-O-O"

	var notation := ""

	# Piece letter (except for pawns)
	match piece.type:
		Piece.Type.KING:
			notation += "K"
		Piece.Type.QUEEN:
			notation += "Q"
		Piece.Type.ROOK:
			notation += "R"
		Piece.Type.BISHOP:
			notation += "B"
		Piece.Type.KNIGHT:
			notation += "N"
		Piece.Type.PAWN:
			# For pawn captures, include the file letter
			if captured != null:
				notation += _col_to_file(from.x)

	# Capture indicator
	if captured != null:
		notation += "x"

	# Destination square
	notation += _pos_to_square(to)

	# Promotion
	if special.begins_with("promotion"):
		var promo_type := special.replace("promotion_", "")
		match promo_type:
			"queen":
				notation += "=Q"
			"rook":
				notation += "=R"
			"bishop":
				notation += "=B"
			"knight":
				notation += "=N"

	# En passant
	if special == "en_passant":
		notation += " e.p."

	return notation


func _col_to_file(col: int) -> String:
	## Convert column (0-7) to file letter (a-h)
	return char(ord("a") + col)


func _pos_to_square(pos: Vector2i) -> String:
	## Convert board position to square notation (e.g., "e4")
	return _col_to_file(pos.x) + str(pos.y + 1)


func _on_copy_button_pressed() -> void:
	## Copy move history to clipboard
	if history_text == null:
		return

	var text := history_text.text
	if text.is_empty():
		text = "No moves"

	DisplayServer.clipboard_set(text)

	# Visual feedback - briefly change button text
	copy_button.text = "Copied!"
	await get_tree().create_timer(1.0).timeout
	if copy_button:
		copy_button.text = "Copy Moves"


func _on_about_button_pressed() -> void:
	## Show the About dialog
	about_dialog.visible = true


func _on_about_close_pressed() -> void:
	## Hide the About dialog
	about_dialog.visible = false


func _on_link_clicked(meta: Variant) -> void:
	## Handle clicking on links in RichTextLabel
	var url := str(meta)
	OS.shell_open(url)
