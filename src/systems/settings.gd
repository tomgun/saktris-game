extends Node
## Global settings autoload - manages user preferences and game settings
##
## NOTE: Settings are persisted to user://settings.json and loaded on startup.
## When changing default values in this file, the saved file will override them.
## To apply new defaults, either:
##   1. Delete the settings file: ~/Library/Application Support/Godot/app_userdata/Saktris/settings.json
##   2. Or call Settings.reset_to_defaults() from code
##   3. Or manually update the JSON file

const SETTINGS_PATH := "user://settings.json"

## Game settings
var game_style: int = 0  ## 0 = Classic (turn-based), 1 = Action (real-time)
var arrival_frequency: int = 1
var arrival_mode: int = PieceArrivalManager.Mode.FIXED
var row_clear_enabled: bool = false
var triplet_clear_enabled: bool = true
var physics_bump_enabled: bool = true
var piece_preview_count: int = 1  ## How many upcoming pieces to show
var game_mode: int = 0  ## 0 = TWO_PLAYER, 1 = VS_AI, 2 = ACTION
var ai_difficulty: int = 1  ## 0 = EASY, 1 = MEDIUM, 2 = HARD
var ai_side: int = Piece.Side.BLACK  ## Which side the AI plays

## Action mode settings
var action_move_cooldown: float = 1.0      ## Seconds between moves per player
var action_arrival_interval: float = 3.0   ## Seconds between piece auto-arrivals
var action_ai_reaction_min: float = 0.4    ## Minimum AI reaction delay after cooldown ready
var action_ai_reaction_max: float = 1.0    ## Maximum AI reaction delay after cooldown ready

## Audio settings
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var audio_theme: String = "classic"

## Player settings
var player_name: String = ""

## Visual settings
var board_theme: String = "retrofuturistic"  # Default to new retrofuturistic theme
var piece_set: String = "standard"  ## Options: "standard", "spatial"
var show_coordinates: bool = true
var show_legal_moves: bool = true
var animation_speed: float = 1.0
var piece_3d_enabled: bool = true  ## Enable 3D-style shading on pieces

signal settings_changed


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	## Load settings from file
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_warning("Failed to parse settings file")
		return

	var data: Dictionary = json.data

	# Game settings
	game_style = data.get("game_style", game_style)
	arrival_frequency = data.get("arrival_frequency", arrival_frequency)
	arrival_mode = data.get("arrival_mode", arrival_mode)
	row_clear_enabled = data.get("row_clear_enabled", row_clear_enabled)
	triplet_clear_enabled = data.get("triplet_clear_enabled", triplet_clear_enabled)
	physics_bump_enabled = data.get("physics_bump_enabled", physics_bump_enabled)
	piece_preview_count = data.get("piece_preview_count", piece_preview_count)
	# Note: action_move_cooldown and action_arrival_interval are NOT loaded from save
	# They always use code defaults so developers can easily tweak them

	# Player settings
	player_name = data.get("player_name", player_name)

	# Audio settings
	master_volume = data.get("master_volume", master_volume)
	music_volume = data.get("music_volume", music_volume)
	sfx_volume = data.get("sfx_volume", sfx_volume)
	audio_theme = data.get("audio_theme", audio_theme)

	# Visual settings
	board_theme = data.get("board_theme", board_theme)
	# Force standard pieces (with outlines) until settings menu exists
	piece_set = "standard"
	show_coordinates = data.get("show_coordinates", show_coordinates)
	show_legal_moves = data.get("show_legal_moves", show_legal_moves)
	animation_speed = data.get("animation_speed", animation_speed)
	piece_3d_enabled = data.get("piece_3d_enabled", piece_3d_enabled)

	_apply_audio_settings()


func save_settings() -> void:
	## Save settings to file
	# Note: action_move_cooldown and action_arrival_interval are NOT saved
	# They always use code defaults so developers can easily tweak them
	var data := {
		"player_name": player_name,
		"game_style": game_style,
		"arrival_frequency": arrival_frequency,
		"arrival_mode": arrival_mode,
		"row_clear_enabled": row_clear_enabled,
		"triplet_clear_enabled": triplet_clear_enabled,
		"physics_bump_enabled": physics_bump_enabled,
		"piece_preview_count": piece_preview_count,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"audio_theme": audio_theme,
		"board_theme": board_theme,
		"piece_set": piece_set,
		"show_coordinates": show_coordinates,
		"show_legal_moves": show_legal_moves,
		"animation_speed": animation_speed,
		"piece_3d_enabled": piece_3d_enabled
	}

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save settings")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	settings_changed.emit()


func _apply_audio_settings() -> void:
	## Apply audio settings to audio buses
	# Assumes standard audio bus layout: Master, Music, SFX
	var master_bus := AudioServer.get_bus_index("Master")
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")

	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))


func get_game_settings() -> Dictionary:
	## Returns settings for starting a new game
	return {
		"arrival_frequency": arrival_frequency,
		"arrival_mode": arrival_mode,
		"row_clear_enabled": row_clear_enabled,
		"triplet_clear_enabled": triplet_clear_enabled,
		"physics_bump_enabled": physics_bump_enabled,
		"game_mode": game_mode,
		"ai_difficulty": ai_difficulty,
		"ai_side": ai_side,
		"action_move_cooldown": action_move_cooldown,
		"action_arrival_interval": action_arrival_interval,
		"action_ai_reaction_min": action_ai_reaction_min,
		"action_ai_reaction_max": action_ai_reaction_max
	}


func reset_to_defaults() -> void:
	## Reset all settings to default values
	player_name = ""
	arrival_frequency = 1
	arrival_mode = PieceArrivalManager.Mode.FIXED
	row_clear_enabled = false
	triplet_clear_enabled = true
	physics_bump_enabled = true
	piece_preview_count = 1
	action_move_cooldown = 3.0
	action_arrival_interval = 8.0
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
	board_theme = "retrofuturistic"
	piece_set = "standard"
	show_coordinates = true
	show_legal_moves = true
	animation_speed = 1.0
	piece_3d_enabled = false
	save_settings()
