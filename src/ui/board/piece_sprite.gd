class_name PieceSprite
extends TextureRect
## Visual representation of a chess piece

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

var piece: Piece
var board_position: Vector2i

## Dragging state
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO
var drag_distance: float = 0.0  # Track how far we've dragged
var drag_was_cancelled: bool = false  # Track if drag was cancelled (for click detection)
const DRAG_THRESHOLD: float = 5.0  # Minimum distance to count as drag vs click

signal drag_started(sprite: PieceSprite)
signal drag_ended(sprite: PieceSprite, was_drag: bool)  # was_drag = moved enough to be a drag
signal clicked(sprite: PieceSprite)  # Simple click without drag


func setup(p: Piece, pos: Vector2i, square_size: float) -> void:
	piece = p
	board_position = pos

	# Load the appropriate texture
	var texture_path: String = PIECE_TEXTURES[piece.side][piece.type]
	texture = load(texture_path)

	# Size and position
	custom_minimum_size = Vector2(square_size, square_size)
	size = Vector2(square_size, square_size)
	expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Allow mouse input for dragging
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start potential drag
				drag_start_pos = position
				drag_offset = get_local_mouse_position()
				drag_distance = 0.0
				is_dragging = true
				drag_was_cancelled = false
				z_index = 50  # Bring to front while dragging
				drag_started.emit(self)
				accept_event()
			else:
				# End drag/click
				if is_dragging:
					var was_actual_drag := drag_distance >= DRAG_THRESHOLD
					is_dragging = false
					z_index = 0

					if was_actual_drag:
						drag_ended.emit(self, true)
					else:
						# Was just a click - snap back and emit click
						position = drag_start_pos
						clicked.emit(self)
					accept_event()
				elif drag_was_cancelled:
					# Drag was cancelled (e.g., clicked on enemy piece) - still emit click
					drag_was_cancelled = false
					clicked.emit(self)
					accept_event()

	elif event is InputEventMouseMotion and is_dragging:
		# Update position while dragging
		var new_pos: Vector2 = get_global_mouse_position() - get_parent().global_position - drag_offset
		drag_distance += position.distance_to(new_pos)
		position = new_pos
		accept_event()


func cancel_drag() -> void:
	## Cancel drag immediately (called during drag_started if not allowed)
	if is_dragging:
		is_dragging = false
		drag_was_cancelled = true  # Remember we were in a drag that got cancelled
		z_index = 0
		position = drag_start_pos


func snap_back() -> void:
	## Animate back to start position (called after invalid drop)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position", drag_start_pos, 0.2)


func animate_to(new_pos: Vector2i, target_pixel_pos: Vector2, duration: float = 0.15) -> void:
	board_position = new_pos
	is_moving = true
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_pixel_pos, duration)
	tween.tween_callback(func(): is_moving = false)


func get_texture_for_piece(p: Piece) -> Texture2D:
	var path: String = PIECE_TEXTURES[p.side][p.type]
	return load(path)


## Physics state for bump animation
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var is_bumping: bool = false
var is_moving: bool = false  # True while animating a regular move
var home_position: Vector2 = Vector2.ZERO  # Where to return after being nudged
var is_returning: bool = false


func start_bump(direction: Vector2, speed: float = 400.0) -> void:
	## Start the captured piece flying off the board
	is_bumping = true
	velocity = direction.normalized() * speed
	velocity.y -= 150  # Add upward component
	angular_velocity = randf_range(300, 500) * (1 if randf() > 0.5 else -1)
	# Bring to front so it renders above other pieces
	z_index = 100


func nudge(push_direction: Vector2, strength: float = 0.3) -> void:
	## Called when another piece bumps into this one
	if is_bumping or is_moving:
		return  # Don't nudge pieces that are flying off or moving

	if not is_returning:
		home_position = position

	# Push in the direction with some randomness
	var offset := push_direction.normalized() * size.x * strength
	offset += Vector2(randf_range(-5, 5), randf_range(-5, 5))
	position += offset
	is_returning = true

	# Start returning after a tiny delay
	var tween := create_tween()
	tween.tween_property(self, "position", home_position, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC).set_delay(0.05)
	tween.tween_callback(func(): is_returning = false)


func physics_update(delta: float, gravity: float = 800.0) -> void:
	## Update physics simulation for bumping pieces
	if not is_bumping:
		return

	# Apply gravity
	velocity.y += gravity * delta

	# Update position
	position += velocity * delta

	# Update rotation
	rotation_degrees += angular_velocity * delta

	# Fade out as it falls
	if position.y > home_position.y + size.y * 2:
		modulate.a -= delta * 2.0
		if modulate.a <= 0:
			queue_free()


func get_center() -> Vector2:
	return position + size / 2


func get_collision_radius() -> float:
	return size.x * 0.45
