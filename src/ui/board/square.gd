class_name BoardSquare
extends ColorRect
## A single square on the chess board

signal clicked(board_pos: Vector2i)

const LIGHT_COLOR := Color("#F0D9B5")  # Classic light square
const DARK_COLOR := Color("#B58863")   # Classic dark square
const HIGHLIGHT_COLOR := Color(1, 1, 0, 0.3)  # Yellow highlight for selection
const LAST_MOVE_COLOR := Color(0.5, 0.8, 0.3, 0.4)  # Green for last move

var board_position: Vector2i
var is_light: bool
var is_highlighted: bool = false
var is_last_move: bool = false

@onready var highlight_overlay: ColorRect = $HighlightOverlay


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(pos: Vector2i) -> void:
	board_position = pos
	is_light = (pos.x + pos.y) % 2 == 1
	_update_color()


func _update_color() -> void:
	color = LIGHT_COLOR if is_light else DARK_COLOR

	if highlight_overlay:
		if is_highlighted:
			highlight_overlay.color = HIGHLIGHT_COLOR
			highlight_overlay.visible = true
		elif is_last_move:
			highlight_overlay.color = LAST_MOVE_COLOR
			highlight_overlay.visible = true
		else:
			highlight_overlay.visible = false


func set_highlighted(value: bool) -> void:
	is_highlighted = value
	_update_color()


func set_last_move(value: bool) -> void:
	is_last_move = value
	_update_color()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit(board_position)
