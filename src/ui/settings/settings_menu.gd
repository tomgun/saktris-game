class_name SettingsMenu
extends Control
## Settings menu - Edit player name and preferences

signal back_pressed()

@onready var name_input: LineEdit = %NameInput
@onready var save_button: Button = %SaveButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	name_input.text = Settings.player_name
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _on_save_pressed() -> void:
	Settings.player_name = name_input.text.strip_edges()
	Settings.save_settings()
	save_button.text = "Saved!"
	get_tree().create_timer(1.0).timeout.connect(func(): save_button.text = "Save")


func _on_back_pressed() -> void:
	back_pressed.emit()
