class_name VisualTheme
extends Resource
## Defines a visual theme for the chess board and pieces

@export var theme_name: String = "Classic"
@export var theme_id: String = "classic"

## Board colors
@export var light_square: Color = Color("#F0D9B5")
@export var dark_square: Color = Color("#B58863")
@export var board_background: Color = Color(0.2, 0.15, 0.1)

## Grid lines (for retrofuturistic style)
@export var grid_line_color: Color = Color(0, 0.8, 1, 0.6)
@export var grid_line_width: float = 0.0  # 0 = no grid lines

## Highlight colors
@export var selection_highlight: Color = Color(1, 1, 0, 0.3)
@export var last_move_highlight: Color = Color(0.5, 0.8, 0.3, 0.4)
@export var legal_move_color: Color = Color(0, 0, 0, 0.2)
@export var capture_color: Color = Color(0.8, 0.2, 0.2, 0.3)

## Placement indicators
@export var placement_indicator_color: Color = Color(0.3, 0.5, 0.9, 0.9)
@export var placement_glow_enabled: bool = true
@export var placement_glow_color: Color = Color(0.3, 0.5, 0.9, 0.8)

## Effects
@export var neon_glow_enabled: bool = false
@export var neon_glow_color: Color = Color(0, 1, 1, 1.0)
@export var scanlines_enabled: bool = false
