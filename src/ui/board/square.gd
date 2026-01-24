class_name BoardSquare
extends ColorRect
## A single square on the chess board

signal clicked(board_pos: Vector2i)

# Fallback colors (used if no theme loaded)
const DEFAULT_LIGHT_COLOR := Color("#F0D9B5")
const DEFAULT_DARK_COLOR := Color("#B58863")
const DEFAULT_HIGHLIGHT_COLOR := Color(1, 1, 0, 0.3)
const DEFAULT_LAST_MOVE_COLOR := Color(0.5, 0.8, 0.3, 0.4)

var board_position: Vector2i
var is_light: bool
var is_highlighted: bool = false
var is_last_move: bool = false

@onready var highlight_overlay: ColorRect = $HighlightOverlay


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Connect to theme changes
	if ThemeManager:
		ThemeManager.visual_theme_changed.connect(_on_visual_theme_changed)


func setup(pos: Vector2i) -> void:
	board_position = pos
	is_light = (pos.x + pos.y) % 2 == 1
	# Apply current theme (in case theme was set before this square was created)
	call_deferred("_update_color")


func _on_visual_theme_changed(_theme: Resource) -> void:
	_update_color()


func _update_color() -> void:
	var theme: Resource = ThemeManager.get_current_visual_theme() if ThemeManager else null

	if theme:
		color = theme.light_square if is_light else theme.dark_square
	else:
		color = DEFAULT_LIGHT_COLOR if is_light else DEFAULT_DARK_COLOR

	if highlight_overlay:
		if is_highlighted:
			highlight_overlay.color = theme.selection_highlight if theme else DEFAULT_HIGHLIGHT_COLOR
			highlight_overlay.visible = true
		elif is_last_move:
			highlight_overlay.color = theme.last_move_highlight if theme else DEFAULT_LAST_MOVE_COLOR
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
