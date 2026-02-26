class_name PieceSprite
extends TextureRect
## Visual representation of a chess piece

## Neon outline shader material for retrofuturistic theme
const NeonOutlineMaterial := preload("res://assets/shaders/neon_outline_material.tres")

## Available piece sets and their paths
const PIECE_SETS := {
	"standard": "res://assets/sprites/pieces/",
	"spatial": "res://assets/sprites/pieces_3d/",  # MIT license - 3D-style pieces
}

## Piece filename mapping
const PIECE_FILES := {
	Piece.Side.WHITE: {
		Piece.Type.KING: "wK.svg",
		Piece.Type.QUEEN: "wQ.svg",
		Piece.Type.ROOK: "wR.svg",
		Piece.Type.BISHOP: "wB.svg",
		Piece.Type.KNIGHT: "wN.svg",
		Piece.Type.PAWN: "wP.svg",
	},
	Piece.Side.BLACK: {
		Piece.Type.KING: "bK.svg",
		Piece.Type.QUEEN: "bQ.svg",
		Piece.Type.ROOK: "bR.svg",
		Piece.Type.BISHOP: "bB.svg",
		Piece.Type.KNIGHT: "bN.svg",
		Piece.Type.PAWN: "bP.svg",
	}
}

## Piece weights for physics simulation (based on chess point values)
const PIECE_WEIGHTS := {
	Piece.Type.PAWN: 1.0,
	Piece.Type.KNIGHT: 3.0,
	Piece.Type.BISHOP: 3.0,
	Piece.Type.ROOK: 5.0,
	Piece.Type.QUEEN: 9.0,
	Piece.Type.KING: 10.0,
}

var piece: Piece
var board_position: Vector2i
var _active_tweens: Array[Tween] = []

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

	# Load the appropriate texture based on piece set setting
	var piece_set: String = Settings.piece_set
	if not PIECE_SETS.has(piece_set):
		piece_set = "standard"
	var base_path: String = PIECE_SETS[piece_set]
	var filename: String = PIECE_FILES[piece.side][piece.type]
	texture = load(base_path + filename)

	# Size and position
	custom_minimum_size = Vector2(square_size, square_size)
	size = Vector2(square_size, square_size)
	expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Allow mouse input for dragging
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Apply neon glow shader if theme requires it
	_update_visual_theme()

	# Connect to theme changes
	if ThemeManager and not ThemeManager.visual_theme_changed.is_connected(_on_visual_theme_changed):
		ThemeManager.visual_theme_changed.connect(_on_visual_theme_changed)


func _on_visual_theme_changed(_theme: Resource) -> void:
	_update_visual_theme()


func _update_visual_theme() -> void:
	## Apply or remove neon glow shader based on current visual theme
	var theme := ThemeManager.get_current_visual_theme() if ThemeManager else null
	if theme and theme.neon_glow_enabled:
		var neon_mat := NeonOutlineMaterial.duplicate() as ShaderMaterial
		neon_mat.set_shader_parameter("glow_color", theme.neon_glow_color)
		material = neon_mat
	else:
		material = null


func _create_tracked_tween() -> Tween:
	## Create a tween and track it so we can kill all on exit
	# Prune finished tweens
	_active_tweens = _active_tweens.filter(func(t: Tween) -> bool: return t.is_valid() and t.is_running())
	var tween := create_tween()
	_active_tweens.append(tween)
	return tween


func _exit_tree() -> void:
	for tween in _active_tweens:
		if tween.is_valid():
			tween.kill()
	_active_tweens.clear()


func _gui_input(event: InputEvent) -> void:
	# Handle mouse button events
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(get_local_mouse_position())
				accept_event()
			else:
				_end_drag()
				accept_event()

	# Handle mouse motion while dragging
	elif event is InputEventMouseMotion and is_dragging:
		_update_drag(get_global_mouse_position())
		accept_event()

	# Handle touch events for mobile
	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(_screen_to_local(event.position))
			accept_event()
		else:
			_end_drag()
			accept_event()

	# Handle touch drag events
	elif event is InputEventScreenDrag and is_dragging:
		_update_drag(event.position)
		accept_event()


func _screen_to_local(screen_pos: Vector2) -> Vector2:
	## Convert screen position to local position
	return get_global_transform().affine_inverse() * screen_pos


func _start_drag(local_pos: Vector2) -> void:
	## Start a potential drag from a local position
	drag_start_pos = position
	drag_offset = local_pos
	drag_distance = 0.0
	is_dragging = true
	drag_was_cancelled = false
	z_index = 50  # Bring to front while dragging
	drag_started.emit(self)


func _end_drag() -> void:
	## End drag/click interaction
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
	elif drag_was_cancelled:
		# Drag was cancelled (e.g., clicked on enemy piece) - still emit click
		drag_was_cancelled = false
		clicked.emit(self)


func _update_drag(global_pos: Vector2) -> void:
	## Update position while dragging
	var new_pos: Vector2 = global_pos - get_parent().global_position - drag_offset
	drag_distance += position.distance_to(new_pos)
	position = new_pos


func cancel_drag() -> void:
	## Cancel drag immediately (called during drag_started if not allowed)
	if is_dragging:
		is_dragging = false
		drag_was_cancelled = true  # Remember we were in a drag that got cancelled
		z_index = 0
		position = drag_start_pos


func snap_back() -> void:
	## Animate back to start position (called after invalid drop)
	var tween := _create_tracked_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position", drag_start_pos, 0.2)


func animate_to(new_pos: Vector2i, target_pixel_pos: Vector2, duration: float = 0.15) -> void:
	board_position = new_pos
	is_moving = true
	var tween := _create_tracked_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_pixel_pos, duration)
	tween.tween_callback(func(): is_moving = false)


func get_texture_for_piece(p: Piece) -> Texture2D:
	var piece_set: String = Settings.piece_set
	if not PIECE_SETS.has(piece_set):
		piece_set = "standard"
	var base_path: String = PIECE_SETS[piece_set]
	var filename: String = PIECE_FILES[p.side][p.type]
	return load(base_path + filename)


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


func nudge(push_direction: Vector2, strength: float = 0.3, attacker_weight: float = 1.0) -> void:
	## Called when another piece bumps into this one
	## attacker_weight affects how much this piece moves (heavier attacker = more push)
	if is_bumping or is_moving:
		return  # Don't nudge pieces that are flying off or moving

	if not is_returning:
		home_position = position

	# Calculate weight factor: heavier attackers push more, heavier targets move less
	var my_weight := get_weight()
	var weight_factor := attacker_weight / my_weight

	# Push in the direction with some randomness, scaled by weight
	var offset := push_direction.normalized() * size.x * strength * weight_factor
	offset += Vector2(randf_range(-5, 5), randf_range(-5, 5))
	position += offset
	is_returning = true

	# Return speed also affected by weight (heavier pieces return slower/more deliberately)
	var return_duration := 1.5 * sqrt(my_weight / 3.0)  # Normalized around bishop/knight

	# Start returning after a tiny delay
	var tween := _create_tracked_tween()
	tween.tween_property(self, "position", home_position, return_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC).set_delay(0.05)
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


func get_weight() -> float:
	## Get the physics weight of this piece based on chess point values
	if piece and PIECE_WEIGHTS.has(piece.type):
		return PIECE_WEIGHTS[piece.type]
	return 1.0  # Default to pawn weight
