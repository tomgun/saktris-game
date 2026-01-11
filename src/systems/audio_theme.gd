class_name AudioTheme
extends Resource
## Defines an audiovisual theme with sounds and music

@export var theme_name: String = "Classic"
@export var theme_id: String = "classic"

## Music
@export var music_gameplay: AudioStream
@export var music_menu: AudioStream

## Core game SFX
@export var sfx_move: AudioStream
@export var sfx_capture: AudioStream
@export var sfx_place: AudioStream
@export var sfx_check: AudioStream
@export var sfx_checkmate: AudioStream
@export var sfx_stalemate: AudioStream
@export var sfx_game_start: AudioStream

## UI SFX
@export var sfx_click: AudioStream
@export var sfx_select: AudioStream

## Physics/effects SFX
@export var sfx_collision: AudioStream
@export var sfx_triplet_clear: AudioStream

## Optional: per-piece move sounds (if null, uses sfx_move)
@export var sfx_move_pawn: AudioStream
@export var sfx_move_knight: AudioStream
@export var sfx_move_bishop: AudioStream
@export var sfx_move_rook: AudioStream
@export var sfx_move_queen: AudioStream
@export var sfx_move_king: AudioStream


func get_move_sound(piece_type: int) -> AudioStream:
	## Returns piece-specific move sound, or default if not set
	match piece_type:
		0:  # KING
			return sfx_move_king if sfx_move_king else sfx_move
		1:  # QUEEN
			return sfx_move_queen if sfx_move_queen else sfx_move
		2:  # ROOK
			return sfx_move_rook if sfx_move_rook else sfx_move
		3:  # BISHOP
			return sfx_move_bishop if sfx_move_bishop else sfx_move
		4:  # KNIGHT
			return sfx_move_knight if sfx_move_knight else sfx_move
		5:  # PAWN
			return sfx_move_pawn if sfx_move_pawn else sfx_move
	return sfx_move
