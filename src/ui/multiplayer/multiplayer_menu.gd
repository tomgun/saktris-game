class_name MultiplayerMenu
extends Control
## Multiplayer menu - Create or join online games

signal back_pressed()
signal game_starting(settings: Dictionary, is_host: bool, my_side: int)

@onready var status_label: Label = %StatusLabel
@onready var create_button: Button = %CreateButton
@onready var join_button: Button = %JoinButton
@onready var back_button: Button = %BackButton
@onready var room_code_input: LineEdit = %RoomCodeInput
@onready var room_code_display: LineEdit = %RoomCodeDisplay
@onready var copy_button: Button = %CopyButton
@onready var waiting_panel: PanelContainer = %WaitingPanel
@onready var join_panel: PanelContainer = %JoinPanel
@onready var main_panel: PanelContainer = %MainPanel
@onready var side_selector: HBoxContainer = %SideSelector
@onready var white_button: Button = %WhiteButton
@onready var black_button: Button = %BlackButton
@onready var cancel_button: Button = %CancelButton
@onready var join_room_button: Button = %JoinRoomButton
@onready var name_panel: PanelContainer = %NamePanel
@onready var name_input: LineEdit = %NameInput
@onready var continue_button: Button = %ContinueButton

var _selected_side: int = Piece.Side.WHITE
var _connect_timer: SceneTreeTimer = null


func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	join_room_button.pressed.connect(_on_join_room_button_pressed)
	white_button.pressed.connect(_on_white_selected)
	black_button.pressed.connect(_on_black_selected)
	room_code_input.text_submitted.connect(_on_room_code_submitted)
	continue_button.pressed.connect(_on_continue_pressed)

	# Connect NetworkManager signals
	NetworkManager.state_changed.connect(_on_network_state_changed)
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.room_error.connect(_on_room_error)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.game_starting.connect(_on_game_starting)

	_update_side_buttons()

	if Settings.player_name.strip_edges().is_empty():
		_show_name_panel()
	else:
		_show_main_panel()


func _show_name_panel() -> void:
	name_panel.visible = true
	main_panel.visible = false
	waiting_panel.visible = false
	join_panel.visible = false
	name_input.text = Settings.player_name
	name_input.grab_focus()
	status_label.text = ""


func _on_continue_pressed() -> void:
	var name_text := name_input.text.strip_edges()
	if name_text.is_empty():
		status_label.text = "Please enter a name"
		return
	Settings.player_name = name_text
	Settings.save_settings()
	_show_main_panel()


func _show_main_panel() -> void:
	name_panel.visible = false
	main_panel.visible = true
	waiting_panel.visible = false
	join_panel.visible = false
	status_label.text = ""


func _show_waiting_panel(code: String) -> void:
	name_panel.visible = false
	main_panel.visible = false
	waiting_panel.visible = true
	join_panel.visible = false
	room_code_display.text = code
	status_label.text = "Waiting for opponent..."


func _show_join_panel() -> void:
	name_panel.visible = false
	main_panel.visible = false
	waiting_panel.visible = false
	join_panel.visible = true
	room_code_input.text = ""
	room_code_input.grab_focus()
	status_label.text = "Enter room code"


func _update_side_buttons() -> void:
	white_button.button_pressed = (_selected_side == Piece.Side.WHITE)
	black_button.button_pressed = (_selected_side == Piece.Side.BLACK)


func _on_white_selected() -> void:
	_selected_side = Piece.Side.WHITE
	_update_side_buttons()


func _on_black_selected() -> void:
	_selected_side = Piece.Side.BLACK
	_update_side_buttons()


func _on_create_pressed() -> void:
	status_label.text = "Connecting..."
	create_button.disabled = true
	join_button.disabled = true

	# Connect to signaling server first
	if NetworkManager.get_state() == NetworkManager.ConnectionState.OFFLINE:
		NetworkManager.connect_to_server()
		# Wait for connection, then create room
		await NetworkManager.state_changed
		if NetworkManager.get_state() == NetworkManager.ConnectionState.IN_LOBBY:
			NetworkManager.create_room(_selected_side)
	elif NetworkManager.get_state() == NetworkManager.ConnectionState.IN_LOBBY:
		NetworkManager.create_room(_selected_side)


func _on_join_pressed() -> void:
	_show_join_panel()

	# Connect to signaling server if needed
	if NetworkManager.get_state() == NetworkManager.ConnectionState.OFFLINE:
		status_label.text = "Connecting..."
		NetworkManager.connect_to_server()


func _on_room_code_submitted(code: String) -> void:
	_try_join_room(code)


func _on_join_room_button_pressed() -> void:
	_try_join_room(room_code_input.text)


func _try_join_room(code: String) -> void:
	code = code.strip_edges().to_upper()

	if not NetworkProtocol.is_valid_room_code(code):
		status_label.text = "Invalid code format (6 characters)"
		return

	if NetworkManager.get_state() == NetworkManager.ConnectionState.IN_LOBBY:
		status_label.text = "Joining..."
		NetworkManager.join_room(code)
	else:
		status_label.text = "Not connected to server"


func _on_back_pressed() -> void:
	NetworkManager.disconnect_from_game()
	back_pressed.emit()


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(room_code_display.text)
	copy_button.text = "Copied!"
	# Reset button text after a short delay
	get_tree().create_timer(1.5).timeout.connect(func(): copy_button.text = "Copy")


func _on_cancel_pressed() -> void:
	NetworkManager.leave_room()
	_show_main_panel()
	create_button.disabled = false
	join_button.disabled = false


func _start_slow_connect_timer() -> void:
	_connect_timer = get_tree().create_timer(2.0)
	_connect_timer.timeout.connect(_on_slow_connect)


func _on_slow_connect() -> void:
	_connect_timer = null
	if NetworkManager.get_state() == NetworkManager.ConnectionState.CONNECTING_TO_SERVER:
		status_label.text = "Starting server (may take up to 30s)..."


func _on_network_state_changed(new_state: NetworkManager.ConnectionState) -> void:
	# Cancel slow-connect timer if we've moved past connecting
	if new_state != NetworkManager.ConnectionState.CONNECTING_TO_SERVER:
		_connect_timer = null

	match new_state:
		NetworkManager.ConnectionState.OFFLINE:
			status_label.text = "Offline"
			create_button.disabled = false
			join_button.disabled = false

		NetworkManager.ConnectionState.CONNECTING_TO_SERVER:
			status_label.text = "Connecting to server..."
			_start_slow_connect_timer()

		NetworkManager.ConnectionState.IN_LOBBY:
			status_label.text = "Connected"
			create_button.disabled = false
			join_button.disabled = false

		NetworkManager.ConnectionState.CONNECTING_TO_PEER:
			status_label.text = "Connecting to opponent..."

		NetworkManager.ConnectionState.CONNECTED:
			status_label.text = "Connected to opponent!"

		NetworkManager.ConnectionState.ERROR:
			status_label.text = "Connection error"
			create_button.disabled = false
			join_button.disabled = false
			_show_main_panel()


func _on_room_created(code: String) -> void:
	_show_waiting_panel(code)


func _on_room_joined(code: String) -> void:
	status_label.text = "Joined room %s, connecting..." % code
	_show_waiting_panel(code)


func _on_room_error(message: String) -> void:
	status_label.text = "Error: %s" % message


func _on_peer_connected() -> void:
	status_label.text = "Opponent connected!"

	# If we're host, start the game
	if NetworkManager.is_host():
		# Generate game seed and settings
		var seed_val := randi()
		var settings := Settings.get_game_settings()
		settings["game_mode"] = GameState.GameMode.TWO_PLAYER

		# Send game start to guest
		NetworkManager.start_game(settings, seed_val)

		# Start local game
		game_starting.emit({
			"settings": settings,
			"seed": seed_val
		}, true, _selected_side)


func _on_game_starting(data: Dictionary) -> void:
	## Guest receives game start from host
	if not NetworkManager.is_host():
		var settings: Dictionary = data.get("settings", {})
		var seed_val: int = data.get("seed", 0)
		var host_side: int = data.get("host_side", Piece.Side.WHITE)
		var my_side := Piece.Side.BLACK if host_side == Piece.Side.WHITE else Piece.Side.WHITE

		# Acknowledge ready
		NetworkManager.send_ready()

		game_starting.emit({
			"settings": settings,
			"seed": seed_val
		}, false, my_side)
