extends Node
## Global game manager autoload - coordinates game flow and state

var current_game: GameState = null

signal game_started(game: GameState)
signal game_ended(winner: Piece.Side, reason: String)
signal game_loaded(game: GameState)


func _ready() -> void:
	print("GameManager ready")


func new_game(settings: Dictionary = {}) -> GameState:
	## Creates and starts a new game
	current_game = GameState.new()
	current_game.start_new_game(settings)
	current_game.game_over.connect(_on_game_over)
	game_started.emit(current_game)
	return current_game


func load_game(save_name: String) -> GameState:
	## Loads a saved game
	var save_path := "user://saves/%s.json" % save_name
	if not FileAccess.file_exists(save_path):
		push_error("Save file not found: %s" % save_path)
		return null

	var file := FileAccess.open(save_path, FileAccess.READ)
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("Failed to parse save file: %s" % json.get_error_message())
		return null

	current_game = GameState.from_dict(json.data)
	current_game.game_over.connect(_on_game_over)
	game_loaded.emit(current_game)
	return current_game


func save_game(save_name: String) -> bool:
	## Saves the current game
	if current_game == null:
		push_error("No game to save")
		return false

	# Ensure saves directory exists
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	var save_path := "user://saves/%s.json" % save_name
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: %s" % save_path)
		return false

	var json_string := JSON.stringify(current_game.to_dict(), "\t")
	file.store_string(json_string)
	file.close()

	print("Game saved to: %s" % save_path)
	return true


func get_save_list() -> Array[String]:
	## Returns list of available save files
	var saves: Array[String] = []
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return saves

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			saves.append(file_name.trim_suffix(".json"))
		file_name = dir.get_next()

	return saves


func delete_save(save_name: String) -> bool:
	## Deletes a saved game
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return false
	return dir.remove(save_name + ".json") == OK


func _on_game_over(winner: Piece.Side, reason: String) -> void:
	game_ended.emit(winner, reason)
