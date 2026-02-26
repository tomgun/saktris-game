class_name SettingsMenu
extends Control
## Settings menu - Edit player name and preferences

signal back_pressed()

@onready var name_input: LineEdit = %NameInput
@onready var save_button: Button = %SaveButton
@onready var back_button: Button = %BackButton
@onready var classic_button: Button = %ClassicButton
@onready var action_button: Button = %ActionButton

func _ready() -> void:
	name_input.text = Settings.player_name
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	classic_button.pressed.connect(_on_classic_pressed)
	action_button.pressed.connect(_on_action_pressed)

	_update_style_buttons()


func _update_style_buttons() -> void:
	classic_button.button_pressed = (Settings.game_style == 0)
	action_button.button_pressed = (Settings.game_style == 1)


func _on_classic_pressed() -> void:
	Settings.game_style = 0
	_update_style_buttons()


func _on_action_pressed() -> void:
	Settings.game_style = 1
	_update_style_buttons()


func _on_save_pressed() -> void:
	Settings.player_name = name_input.text.strip_edges()
	Settings.save_settings()
	save_button.text = "Saved!"
	get_tree().create_timer(1.0).timeout.connect(func(): save_button.text = "Save")


func _on_back_pressed() -> void:
	# Auto-save on back
	Settings.player_name = name_input.text.strip_edges()
	Settings.save_settings()
	back_pressed.emit()
