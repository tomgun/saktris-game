extends Node
## NetworkManager - Autoload for managing online multiplayer connections
## Coordinates signaling, WebRTC, and game message handling

# Preload dependencies to avoid class_name resolution issues with autoloads
const NetworkProtocolClass := preload("res://src/network/network_protocol.gd")
const SignalingClientClass := preload("res://src/network/signaling_client.gd")
const WebRTCClientClass := preload("res://src/network/webrtc_client.gd")

enum ConnectionState {
	OFFLINE,
	CONNECTING_TO_SERVER,
	IN_LOBBY,
	CONNECTING_TO_PEER,
	CONNECTED,
	DISCONNECTED,
	ERROR
}

const SIGNALING_SERVER_URL := "wss://saktris-signaling.your-server.workers.dev"  # TODO: Update with actual URL

var _signaling  # SignalingClient instance
var _webrtc     # WebRTCClient instance
var _state: ConnectionState = ConnectionState.OFFLINE
var _room_code: String = ""
var _is_host: bool = false
var _game_state: GameState = null
var _move_sequence: int = 0
var _pending_acks: Dictionary = {}  # seq -> timestamp
var _last_ping_time: float = 0.0
var _ping_ms: int = 0
var _my_side: int = Piece.Side.WHITE  # Which side we play

const PING_INTERVAL := 5.0
const ACK_TIMEOUT := 10.0

# Signals for UI/game integration
signal state_changed(new_state: ConnectionState)
signal room_created(code: String)
signal room_joined(code: String)
signal room_error(message: String)
signal peer_connected()
signal peer_disconnected()
signal game_starting(settings: Dictionary)
signal remote_move_received(from: Vector2i, to: Vector2i)
signal remote_placement_received(column: int)
signal remote_promotion_received(piece_type: int)
signal remote_resign()
signal remote_draw_offer()
signal remote_draw_response(accepted: bool)
signal ping_updated(ms: int)
signal resync_needed()


func _ready() -> void:
	_signaling = SignalingClientClass.new()
	_webrtc = WebRTCClientClass.new()

	# Connect signaling signals
	_signaling.connected.connect(_on_signaling_connected)
	_signaling.disconnected.connect(_on_signaling_disconnected)
	_signaling.error.connect(_on_signaling_error)
	_signaling.room_created.connect(_on_room_created)
	_signaling.room_joined.connect(_on_room_joined)
	_signaling.room_error.connect(_on_room_error)
	_signaling.peer_joined.connect(_on_peer_joined)
	_signaling.peer_left.connect(_on_peer_left)
	_signaling.signal_received.connect(_on_signaling_signal)

	# Connect WebRTC signals
	_webrtc.connected.connect(_on_webrtc_connected)
	_webrtc.disconnected.connect(_on_webrtc_disconnected)
	_webrtc.message_received.connect(_on_webrtc_message)
	_webrtc.offer_created.connect(_on_offer_created)
	_webrtc.answer_created.connect(_on_answer_created)
	_webrtc.ice_candidate_generated.connect(_on_ice_candidate)


func _process(_delta: float) -> void:
	# Poll network clients
	_signaling.poll()
	_webrtc.poll()

	# Periodic ping
	if _state == ConnectionState.CONNECTED:
		_last_ping_time += _delta
		if _last_ping_time >= PING_INTERVAL:
			_send_ping()
			_last_ping_time = 0.0

		# Check for ACK timeouts
		_check_ack_timeouts()


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func get_state() -> ConnectionState:
	return _state


func is_online() -> bool:
	return _state == ConnectionState.CONNECTED


func is_host() -> bool:
	return _is_host


func get_room_code() -> String:
	return _room_code


func get_ping() -> int:
	return _ping_ms


func get_my_side() -> int:
	return _my_side


func is_my_turn() -> bool:
	if _game_state == null:
		return false
	return _game_state.current_player == _my_side


func connect_to_server() -> void:
	## Connect to the signaling server
	if _state != ConnectionState.OFFLINE and _state != ConnectionState.DISCONNECTED:
		push_warning("NetworkManager: Already connecting or connected")
		return

	_set_state(ConnectionState.CONNECTING_TO_SERVER)
	_signaling.connect_to_server(SIGNALING_SERVER_URL)


func create_room(play_as_side: int = Piece.Side.WHITE) -> void:
	## Create a new room (become host)
	if _state != ConnectionState.IN_LOBBY:
		push_warning("NetworkManager: Must be connected to server to create room")
		return

	_is_host = true
	_my_side = play_as_side
	_signaling.create_room()


func join_room(code: String) -> void:
	## Join an existing room (become guest)
	if _state != ConnectionState.IN_LOBBY:
		push_warning("NetworkManager: Must be connected to server to join room")
		return

	if not NetworkProtocolClass.is_valid_room_code(code):
		room_error.emit("Invalid room code format")
		return

	_is_host = false
	_signaling.join_room(code)


func leave_room() -> void:
	## Leave current room and return to lobby
	_signaling.leave_room()
	_webrtc.close()
	_room_code = ""
	_is_host = false
	_set_state(ConnectionState.IN_LOBBY)


func disconnect_from_game() -> void:
	## Disconnect completely
	_signaling.disconnect_from_server()
	_webrtc.close()
	_room_code = ""
	_is_host = false
	_game_state = null
	_set_state(ConnectionState.OFFLINE)


func set_game_state(state: GameState) -> void:
	## Set the game state reference for network sync
	_game_state = state


# ─────────────────────────────────────────────────────────────────────────────
# Game Messages - Sending
# ─────────────────────────────────────────────────────────────────────────────

func start_game(settings: Dictionary, seed: int) -> void:
	## Host calls this to start the game
	if not _is_host:
		push_warning("NetworkManager: Only host can start game")
		return

	_move_sequence = 0
	var msg := NetworkProtocolClass.make_game_start(seed, settings, _my_side)
	_send(msg)


func send_ready() -> void:
	## Guest calls this to signal ready
	var msg := NetworkProtocolClass.make_game_ready()
	_send(msg)


func send_move(from: Vector2i, to: Vector2i) -> void:
	## Send a move to the remote player
	_move_sequence += 1
	var msg := NetworkProtocolClass.make_move(from, to, _move_sequence)
	_pending_acks[_move_sequence] = Time.get_unix_time_from_system()
	_send(msg)

	# Send state hash for verification
	_send_state_hash()


func send_placement(column: int) -> void:
	## Send a piece placement to the remote player
	_move_sequence += 1
	var msg := NetworkProtocolClass.make_placement(column, _move_sequence)
	_pending_acks[_move_sequence] = Time.get_unix_time_from_system()
	_send(msg)

	_send_state_hash()


func send_promotion(piece_type: int) -> void:
	## Send a promotion choice to the remote player
	_move_sequence += 1
	var msg := NetworkProtocolClass.make_promotion(piece_type, _move_sequence)
	_pending_acks[_move_sequence] = Time.get_unix_time_from_system()
	_send(msg)

	_send_state_hash()


func send_resign() -> void:
	## Send resignation
	var msg := NetworkProtocolClass.make_resign()
	_send(msg)


func send_draw_offer() -> void:
	## Offer a draw to the opponent
	var msg := NetworkProtocolClass.make_draw_offer()
	_send(msg)


func send_draw_response(accept: bool) -> void:
	## Respond to a draw offer
	var msg := NetworkProtocolClass.make_draw_accept() if accept else NetworkProtocolClass.make_draw_decline()
	_send(msg)


func _send_state_hash() -> void:
	## Send current state hash for verification
	if _game_state == null:
		return

	var hash_val := NetworkProtocolClass.compute_state_hash(_game_state)
	var msg := NetworkProtocolClass.make_state_hash(hash_val, _game_state.move_count)
	_send(msg)


func _send_ping() -> void:
	var msg := NetworkProtocolClass.make_ping()
	_last_ping_time = Time.get_unix_time_from_system()
	_send(msg)


func _send(data: PackedByteArray) -> void:
	if not _webrtc.send(data):
		push_warning("NetworkManager: Failed to send message")


# ─────────────────────────────────────────────────────────────────────────────
# Signaling Callbacks
# ─────────────────────────────────────────────────────────────────────────────

func _on_signaling_connected() -> void:
	_set_state(ConnectionState.IN_LOBBY)


func _on_signaling_disconnected() -> void:
	if _state != ConnectionState.CONNECTED:
		# If not P2P connected, we lost connection
		_set_state(ConnectionState.DISCONNECTED)


func _on_signaling_error(message: String) -> void:
	push_error("NetworkManager: Signaling error - %s" % message)
	_set_state(ConnectionState.ERROR)


func _on_room_created(code: String) -> void:
	_room_code = code
	room_created.emit(code)


func _on_room_joined(code: String) -> void:
	_room_code = code
	room_joined.emit(code)


func _on_room_error(message: String) -> void:
	room_error.emit(message)


func _on_peer_joined() -> void:
	## Guest joined our room - initiate WebRTC connection
	_set_state(ConnectionState.CONNECTING_TO_PEER)
	_webrtc.create_offer()


func _on_peer_left() -> void:
	_webrtc.close()
	peer_disconnected.emit()

	if _state == ConnectionState.CONNECTED:
		_set_state(ConnectionState.DISCONNECTED)


func _on_signaling_signal(data: Dictionary) -> void:
	## Handle WebRTC signaling message from peer
	var signal_type: String = data.get("signal_type", "")

	match signal_type:
		"offer":
			# We're guest, receiving offer from host
			_set_state(ConnectionState.CONNECTING_TO_PEER)
			_webrtc.receive_offer(data.get("sdp", ""))
			# Data channel will be received, then we create answer

		"answer":
			# We're host, receiving answer from guest
			_webrtc.receive_answer(data.get("sdp", ""))

		"ice":
			# ICE candidate from peer
			_webrtc.add_ice_candidate(data.get("candidate", {}))


# ─────────────────────────────────────────────────────────────────────────────
# WebRTC Callbacks
# ─────────────────────────────────────────────────────────────────────────────

func _on_webrtc_connected() -> void:
	_set_state(ConnectionState.CONNECTED)
	peer_connected.emit()

	# Disconnect from signaling server - no longer needed
	_signaling.disconnect_from_server()


func _on_webrtc_disconnected() -> void:
	_set_state(ConnectionState.DISCONNECTED)
	peer_disconnected.emit()


func _on_offer_created(sdp: String) -> void:
	_signaling.send_offer(sdp)


func _on_answer_created(sdp: String) -> void:
	_signaling.send_answer(sdp)


func _on_ice_candidate(candidate: Dictionary) -> void:
	_signaling.send_ice_candidate(candidate)


func _on_webrtc_message(data: PackedByteArray) -> void:
	## Handle incoming game message from peer
	var msg := NetworkProtocolClass.decode_message(data)
	if msg.is_empty():
		return

	var msg_type: int = msg.get("type", -1)
	var msg_data: Dictionary = msg.get("data", {})

	match msg_type:
		NetworkProtocolClass.MessageType.PING:
			_send(NetworkProtocolClass.make_pong())

		NetworkProtocolClass.MessageType.PONG:
			var now := Time.get_unix_time_from_system()
			_ping_ms = int((now - _last_ping_time) * 1000)
			ping_updated.emit(_ping_ms)

		NetworkProtocolClass.MessageType.GAME_START:
			var parsed := NetworkProtocolClass.parse_game_start(msg_data)
			# Guest receives host's side, so guest plays opposite
			_my_side = Piece.Side.BLACK if parsed["host_side"] == Piece.Side.WHITE else Piece.Side.WHITE
			game_starting.emit(parsed)

		NetworkProtocolClass.MessageType.GAME_READY:
			# Guest is ready - game can begin
			pass

		NetworkProtocolClass.MessageType.MOVE:
			var parsed := NetworkProtocolClass.parse_move(msg_data)
			# Send ACK
			_send(NetworkProtocolClass.make_ack(parsed["seq"]))
			remote_move_received.emit(parsed["from"], parsed["to"])

		NetworkProtocolClass.MessageType.PLACEMENT:
			var parsed := NetworkProtocolClass.parse_placement(msg_data)
			_send(NetworkProtocolClass.make_ack(parsed["seq"]))
			remote_placement_received.emit(parsed["column"])

		NetworkProtocolClass.MessageType.PROMOTION:
			var parsed := NetworkProtocolClass.parse_promotion(msg_data)
			_send(NetworkProtocolClass.make_ack(parsed["seq"]))
			remote_promotion_received.emit(parsed["piece_type"])

		NetworkProtocolClass.MessageType.ACK:
			var seq: int = msg_data.get("seq", 0)
			_pending_acks.erase(seq)

		NetworkProtocolClass.MessageType.STATE_HASH:
			_handle_state_hash(msg_data)

		NetworkProtocolClass.MessageType.FULL_STATE:
			_handle_full_state(msg_data)

		NetworkProtocolClass.MessageType.RESYNC_REQUEST:
			_handle_resync_request()

		NetworkProtocolClass.MessageType.RESIGN:
			remote_resign.emit()

		NetworkProtocolClass.MessageType.DRAW_OFFER:
			remote_draw_offer.emit()

		NetworkProtocolClass.MessageType.DRAW_ACCEPT:
			remote_draw_response.emit(true)

		NetworkProtocolClass.MessageType.DRAW_DECLINE:
			remote_draw_response.emit(false)


# ─────────────────────────────────────────────────────────────────────────────
# State Verification
# ─────────────────────────────────────────────────────────────────────────────

func _handle_state_hash(data: Dictionary) -> void:
	## Verify our state matches the remote state
	if _game_state == null:
		return

	var parsed := NetworkProtocolClass.parse_state_hash(data)
	var remote_hash: int = parsed["hash"]
	var remote_move_count: int = parsed["move_count"]

	# Only check if move counts match (otherwise we might be mid-update)
	if _game_state.move_count != remote_move_count:
		return

	var local_hash := NetworkProtocolClass.compute_state_hash(_game_state)

	if local_hash != remote_hash:
		push_warning("NetworkManager: State hash mismatch! Local=%d Remote=%d" % [local_hash, remote_hash])
		# Request resync from host
		if not _is_host:
			_send(NetworkProtocolClass.make_resync_request())
		else:
			# Host sends full state
			_send_full_state()


func _handle_resync_request() -> void:
	## Guest requested full state - send it (host only)
	if not _is_host:
		return
	_send_full_state()


func _send_full_state() -> void:
	if _game_state == null:
		return
	var state_data := _game_state.to_dict()
	var msg := NetworkProtocolClass.make_full_state(state_data)
	_send(msg)


func _handle_full_state(data: Dictionary) -> void:
	## Receive full state for resync (guest only)
	var state_data: Dictionary = data.get("state", {})
	if state_data.is_empty():
		return

	resync_needed.emit()
	# The game scene will handle rebuilding state from this data


func _check_ack_timeouts() -> void:
	## Check for unacknowledged messages that have timed out
	var now := Time.get_unix_time_from_system()
	var timed_out: Array = []

	for seq in _pending_acks:
		var sent_time: float = _pending_acks[seq]
		if now - sent_time > ACK_TIMEOUT:
			timed_out.append(seq)
			push_warning("NetworkManager: ACK timeout for seq %d" % seq)

	for seq in timed_out:
		_pending_acks.erase(seq)

	# If we have too many timeouts, connection might be dead
	if timed_out.size() > 3:
		push_error("NetworkManager: Too many ACK timeouts, connection may be dead")


func _set_state(new_state: ConnectionState) -> void:
	if _state != new_state:
		_state = new_state
		state_changed.emit(new_state)
