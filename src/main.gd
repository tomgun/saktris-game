extends Control
## Main scene controller - manages game states and scene transitions

const BoardViewScene := preload("res://src/ui/board/board_view.tscn")
const MultiplayerMenuScene := preload("res://src/ui/multiplayer/multiplayer_menu.tscn")
const SettingsMenuScene := preload("res://src/ui/settings/settings_menu.tscn")

@onready var game_container: Control = $GameContainer
@onready var menu_container: Control = $MenuContainer
@onready var two_player_button: Button = %TwoPlayerButton
@onready var vs_computer_button: Button = %VsComputerButton
@onready var play_online_button: Button = %PlayOnlineButton
@onready var settings_button: Button = %SettingsButton
@onready var title_label: Label = $MenuContainer/CenterContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $MenuContainer/CenterContainer/VBoxContainer/Subtitle
@onready var credit_label: Label = $MenuContainer/Credit

var board_view: Control
var multiplayer_menu: Control
var settings_menu: Control
var is_mobile: bool = false
var is_online_game: bool = false
var my_side: int = Piece.Side.WHITE

signal new_game_requested


const BUILD_ID := "2026-02-25T01:15"

func _ready() -> void:
	print("Saktris v0.1.0 [build %s]" % BUILD_ID)
	two_player_button.pressed.connect(_on_two_player_pressed)
	vs_computer_button.pressed.connect(_on_vs_computer_pressed)
	play_online_button.pressed.connect(_on_play_online_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Setup mobile detection
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_check_mobile_mode")

	_show_main_menu()


func _show_main_menu() -> void:
	menu_container.visible = true
	game_container.visible = false
	is_online_game = false

	# Clean up multiplayer menu if exists
	if multiplayer_menu:
		multiplayer_menu.queue_free()
		multiplayer_menu = null

	# Clean up settings menu if exists
	if settings_menu:
		settings_menu.queue_free()
		settings_menu = null

	# Disconnect network if connected
	if NetworkManager.is_online():
		NetworkManager.disconnect_from_game()


func _on_two_player_pressed() -> void:
	var settings := Settings.get_game_settings()
	if Settings.game_style == 1:
		settings["game_mode"] = GameState.GameMode.ACTION
	else:
		settings["game_mode"] = GameState.GameMode.TWO_PLAYER
	_start_game(settings)


func _on_vs_computer_pressed() -> void:
	var settings := Settings.get_game_settings()
	if Settings.game_style == 1:
		settings["game_mode"] = GameState.GameMode.ACTION
		settings["use_ai"] = true
	else:
		settings["game_mode"] = GameState.GameMode.VS_AI
	settings["ai_side"] = Piece.Side.BLACK  # AI plays black
	_start_game(settings)


func _on_settings_pressed() -> void:
	menu_container.visible = false

	settings_menu = SettingsMenuScene.instantiate()
	add_child(settings_menu)
	settings_menu.back_pressed.connect(_on_settings_back)


func _on_settings_back() -> void:
	if settings_menu:
		settings_menu.queue_free()
		settings_menu = null
	_show_main_menu()


func _on_play_online_pressed() -> void:
	menu_container.visible = false

	# Create multiplayer menu
	multiplayer_menu = MultiplayerMenuScene.instantiate()
	add_child(multiplayer_menu)
	multiplayer_menu.back_pressed.connect(_on_multiplayer_back)
	multiplayer_menu.game_starting.connect(_on_online_game_starting)


func _on_multiplayer_back() -> void:
	if multiplayer_menu:
		multiplayer_menu.queue_free()
		multiplayer_menu = null
	_show_main_menu()


func _on_online_game_starting(data: Dictionary, is_host: bool, side: int) -> void:
	## Start an online game
	is_online_game = true
	my_side = side

	var settings: Dictionary = data.get("settings", {})
	var seed_val: int = data.get("seed", 0)

	# Use host's game mode from settings (don't override with local settings)
	settings["network_seed"] = seed_val

	# Clean up multiplayer menu
	if multiplayer_menu:
		multiplayer_menu.queue_free()
		multiplayer_menu = null

	_start_game(settings)


func _start_game(settings: Dictionary = {}) -> void:
	menu_container.visible = false
	game_container.visible = true

	# Create the game state via GameManager
	var game_state: GameState

	# Use network seed if provided (for online games)
	if settings.has("network_seed"):
		settings["arrival_seed"] = settings["network_seed"]

	game_state = GameManager.new_game(settings)

	# For online games, set up network sync
	if is_online_game:
		NetworkManager.set_game_state(game_state)
		_connect_network_signals(game_state)

	# Create and add the board view
	if board_view:
		board_view.queue_free()

	board_view = BoardViewScene.instantiate()
	game_container.add_child(board_view)
	board_view.initialize(game_state)

	# Set online mode on board view
	if is_online_game:
		board_view.set_online_mode(true, my_side)

	# Connect new game signal from board view
	if board_view.has_signal("new_game_requested"):
		board_view.new_game_requested.connect(_show_main_menu)


func _connect_network_signals(game_state: GameState) -> void:
	## Connect network events to game state
	NetworkManager.remote_move_received.connect(_on_remote_move.bind(game_state))
	NetworkManager.remote_placement_received.connect(_on_remote_placement.bind(game_state))
	NetworkManager.remote_promotion_received.connect(_on_remote_promotion.bind(game_state))
	NetworkManager.remote_resign.connect(_on_remote_resign.bind(game_state))
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)


func _on_remote_move(from: Vector2i, to: Vector2i, game_state: GameState) -> void:
	## Apply move from remote player
	if game_state.try_move(from, to):
		print("[Network] Applied remote move: %s -> %s" % [from, to])
	else:
		push_warning("[Network] Failed to apply remote move: %s -> %s" % [from, to])


func _on_remote_placement(column: int, game_state: GameState) -> void:
	## Apply placement from remote player
	if game_state.try_place_piece(column):
		print("[Network] Applied remote placement: column %d" % column)
	else:
		push_warning("[Network] Failed to apply remote placement: column %d" % column)


func _on_remote_promotion(piece_type: int, game_state: GameState) -> void:
	## Apply promotion from remote player
	if game_state.complete_promotion(piece_type):
		print("[Network] Applied remote promotion: type %d" % piece_type)
	else:
		push_warning("[Network] Failed to apply remote promotion")


func _on_remote_resign(game_state: GameState) -> void:
	## Handle remote player resignation
	var winner := my_side
	game_state.status = GameState.Status.CHECKMATE
	game_state.game_over.emit(winner, "resignation")


func _on_peer_disconnected() -> void:
	## Handle opponent disconnection
	if is_online_game and board_view:
		# Show disconnect message (handled in board_view)
		pass


func _resume_game(_save_data: Dictionary) -> void:
	# TODO: Resume from saved game
	pass


func _on_viewport_size_changed() -> void:
	_check_mobile_mode()


func _check_mobile_mode() -> void:
	var viewport_size: Vector2i = get_viewport().size
	# Detect mobile by portrait orientation (height > width)
	var new_is_mobile: bool = viewport_size.y > viewport_size.x

	if new_is_mobile != is_mobile:
		is_mobile = new_is_mobile
		_update_menu_fonts()


func _update_menu_fonts() -> void:
	## Update menu font sizes for mobile/desktop
	if is_mobile:
		# Mobile: larger fonts for touch-friendly UI
		title_label.add_theme_font_size_override("font_size", 72)
		subtitle_label.add_theme_font_size_override("font_size", 28)
		two_player_button.add_theme_font_size_override("font_size", 36)
		vs_computer_button.add_theme_font_size_override("font_size", 36)
		play_online_button.add_theme_font_size_override("font_size", 36)
		settings_button.add_theme_font_size_override("font_size", 36)
		two_player_button.custom_minimum_size = Vector2(350, 80)
		vs_computer_button.custom_minimum_size = Vector2(350, 80)
		play_online_button.custom_minimum_size = Vector2(350, 80)
		settings_button.custom_minimum_size = Vector2(350, 80)
		credit_label.add_theme_font_size_override("font_size", 18)
	else:
		# Desktop: original sizes
		title_label.add_theme_font_size_override("font_size", 48)
		subtitle_label.add_theme_font_size_override("font_size", 16)
		two_player_button.add_theme_font_size_override("font_size", 20)
		vs_computer_button.add_theme_font_size_override("font_size", 20)
		play_online_button.add_theme_font_size_override("font_size", 20)
		settings_button.add_theme_font_size_override("font_size", 20)
		two_player_button.custom_minimum_size = Vector2(250, 50)
		vs_computer_button.custom_minimum_size = Vector2(250, 50)
		play_online_button.custom_minimum_size = Vector2(250, 50)
		settings_button.custom_minimum_size = Vector2(250, 50)
		credit_label.add_theme_font_size_override("font_size", 12)
