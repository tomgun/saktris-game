class_name SignalingClient
extends RefCounted
## WebSocket client for connecting to the signaling server
## Handles room creation/joining and WebRTC signal relay

enum State {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	ERROR
}

var _socket: WebSocketPeer
var _state: State = State.DISCONNECTED
var _server_url: String = ""

signal connected()
signal disconnected()
signal error(message: String)
signal room_created(code: String)
signal room_joined(code: String)
signal room_error(message: String)
signal peer_joined()
signal peer_left()
signal signal_received(data: Dictionary)


func _init() -> void:
	_socket = WebSocketPeer.new()


func connect_to_server(url: String) -> void:
	## Connect to the signaling server
	if _state == State.CONNECTING or _state == State.CONNECTED:
		push_warning("SignalingClient: Already connecting or connected")
		return

	_server_url = url
	_state = State.CONNECTING

	var err := _socket.connect_to_url(url)
	if err != OK:
		_state = State.ERROR
		error.emit("Failed to initiate connection: %d" % err)
		return


func disconnect_from_server() -> void:
	## Disconnect from the signaling server
	if _state == State.CONNECTED or _state == State.CONNECTING:
		_socket.close()
	_state = State.DISCONNECTED
	disconnected.emit()


func poll() -> void:
	## Poll the WebSocket - call this in _process
	if _state == State.DISCONNECTED:
		return

	_socket.poll()

	var socket_state := _socket.get_ready_state()

	match socket_state:
		WebSocketPeer.STATE_CONNECTING:
			pass  # Still connecting

		WebSocketPeer.STATE_OPEN:
			if _state == State.CONNECTING:
				_state = State.CONNECTED
				connected.emit()

			# Process incoming messages
			while _socket.get_available_packet_count() > 0:
				var packet := _socket.get_packet()
				_handle_message(packet)

		WebSocketPeer.STATE_CLOSING:
			pass  # Closing

		WebSocketPeer.STATE_CLOSED:
			var code := _socket.get_close_code()
			var reason := _socket.get_close_reason()
			if _state != State.DISCONNECTED:
				_state = State.DISCONNECTED
				if code != 1000:  # Normal closure
					error.emit("Connection closed: %s (code %d)" % [reason, code])
				disconnected.emit()


func is_connected_to_server() -> bool:
	return _state == State.CONNECTED


func get_state() -> State:
	return _state


# ─────────────────────────────────────────────────────────────────────────────
# Room Operations
# ─────────────────────────────────────────────────────────────────────────────

func create_room() -> void:
	## Request to create a new room
	_send({"type": "create"})


func join_room(code: String) -> void:
	## Request to join an existing room
	_send({"type": "join", "code": code.to_upper()})


func leave_room() -> void:
	## Leave the current room
	_send({"type": "leave"})


# ─────────────────────────────────────────────────────────────────────────────
# WebRTC Signaling
# ─────────────────────────────────────────────────────────────────────────────

func send_offer(sdp: String) -> void:
	## Send WebRTC offer to peer via signaling server
	_send({
		"type": "signal",
		"signal_type": "offer",
		"sdp": sdp
	})


func send_answer(sdp: String) -> void:
	## Send WebRTC answer to peer via signaling server
	_send({
		"type": "signal",
		"signal_type": "answer",
		"sdp": sdp
	})


func send_ice_candidate(candidate: Dictionary) -> void:
	## Send ICE candidate to peer via signaling server
	_send({
		"type": "signal",
		"signal_type": "ice",
		"candidate": candidate
	})


# ─────────────────────────────────────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────────────────────────────────────

func _send(data: Dictionary) -> void:
	## Send a message to the signaling server
	if _state != State.CONNECTED:
		push_warning("SignalingClient: Cannot send, not connected")
		return

	var json := JSON.stringify(data)
	_socket.send_text(json)


func _handle_message(packet: PackedByteArray) -> void:
	## Handle a message from the signaling server
	var json := packet.get_string_from_utf8()
	var data: Variant = JSON.parse_string(json)

	if data == null or not data is Dictionary:
		push_warning("SignalingClient: Invalid message received")
		return

	var data_dict: Dictionary = data as Dictionary
	var msg_type: String = data_dict.get("type", "")

	match msg_type:
		"created":
			# Room created successfully
			var code: String = data_dict.get("code", "")
			room_created.emit(code)

		"joined":
			# Successfully joined room
			var code: String = data_dict.get("code", "")
			room_joined.emit(code)

		"error":
			# Room error (not found, full, etc.)
			var message: String = data_dict.get("message", "Unknown error")
			room_error.emit(message)

		"peer_joined":
			# Another player joined our room
			peer_joined.emit()

		"peer_left":
			# Other player left the room
			peer_left.emit()

		"signal":
			# WebRTC signaling data from peer
			signal_received.emit(data)

		_:
			push_warning("SignalingClient: Unknown message type: %s" % msg_type)
