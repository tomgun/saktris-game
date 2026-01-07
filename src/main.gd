extends Control
## Main scene controller - manages game states and scene transitions

const BoardViewScene := preload("res://src/ui/board/board_view.tscn")

@onready var game_container: Control = $GameContainer
@onready var menu_container: Control = $MenuContainer
@onready var two_player_button: Button = %TwoPlayerButton
@onready var vs_computer_button: Button = %VsComputerButton

var board_view: Control

signal new_game_requested


func _ready() -> void:
	print("Saktris v0.1.0 starting...")
	two_player_button.pressed.connect(_on_two_player_pressed)
	vs_computer_button.pressed.connect(_on_vs_computer_pressed)
	_show_main_menu()


func _show_main_menu() -> void:
	menu_container.visible = true
	game_container.visible = false


func _on_two_player_pressed() -> void:
	var settings := Settings.get_game_settings()
	settings["game_mode"] = 0  # TWO_PLAYER
	_start_game(settings)


func _on_vs_computer_pressed() -> void:
	var settings := Settings.get_game_settings()
	settings["game_mode"] = 1  # VS_AI
	settings["ai_side"] = Piece.Side.BLACK  # AI plays black
	_start_game(settings)


func _start_game(settings: Dictionary = {}) -> void:
	menu_container.visible = false
	game_container.visible = true

	# Create the game state via GameManager
	var game_state := GameManager.new_game(settings)

	# Create and add the board view
	if board_view:
		board_view.queue_free()

	board_view = BoardViewScene.instantiate()
	game_container.add_child(board_view)
	board_view.initialize(game_state)

	# Connect new game signal from board view
	if board_view.has_signal("new_game_requested"):
		board_view.new_game_requested.connect(_show_main_menu)


func _resume_game(_save_data: Dictionary) -> void:
	# TODO: Resume from saved game
	pass
