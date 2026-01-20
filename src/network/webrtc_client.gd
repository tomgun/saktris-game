class_name WebRTCClient
extends RefCounted
## WebRTC peer connection wrapper for P2P game communication

enum State {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	FAILED
}

var _peer: WebRTCPeerConnection
var _channel: WebRTCDataChannel
var _state: State = State.DISCONNECTED
var _is_host: bool = false

## Public STUN servers for NAT traversal
const ICE_SERVERS := [
	{"urls": ["stun:stun.l.google.com:19302"]},
	{"urls": ["stun:stun1.l.google.com:19302"]},
]

signal state_changed(new_state: State)
signal connected()
signal disconnected()
signal message_received(data: PackedByteArray)
signal ice_candidate_generated(candidate: Dictionary)
signal offer_created(sdp: String)
signal answer_created(sdp: String)


func _init() -> void:
	_peer = WebRTCPeerConnection.new()
	_peer.initialize({"iceServers": ICE_SERVERS})

	# Connect peer signals
	_peer.session_description_created.connect(_on_session_description_created)
	_peer.ice_candidate_created.connect(_on_ice_candidate_created)


func poll() -> void:
	## Poll the peer connection - call this in _process
	if _peer == null:
		return

	_peer.poll()

	# Check data channel state
	if _channel != null:
		_channel.poll()

		match _channel.get_ready_state():
			WebRTCDataChannel.STATE_CONNECTING:
				if _state != State.CONNECTING:
					_set_state(State.CONNECTING)

			WebRTCDataChannel.STATE_OPEN:
				if _state != State.CONNECTED:
					_set_state(State.CONNECTED)
					connected.emit()

				# Read incoming messages
				while _channel.get_available_packet_count() > 0:
					var packet := _channel.get_packet()
					message_received.emit(packet)

			WebRTCDataChannel.STATE_CLOSING:
				pass

			WebRTCDataChannel.STATE_CLOSED:
				if _state == State.CONNECTED:
					_set_state(State.DISCONNECTED)
					disconnected.emit()

	# Check peer connection state
	var peer_state := _peer.get_connection_state()
	if peer_state == WebRTCPeerConnection.STATE_FAILED:
		if _state != State.FAILED:
			_set_state(State.FAILED)
	elif peer_state == WebRTCPeerConnection.STATE_DISCONNECTED:
		if _state == State.CONNECTED:
			_set_state(State.DISCONNECTED)
			disconnected.emit()


func get_state() -> State:
	return _state


func is_connected_to_peer() -> bool:
	return _state == State.CONNECTED


func is_host() -> bool:
	return _is_host


# ─────────────────────────────────────────────────────────────────────────────
# Connection Setup
# ─────────────────────────────────────────────────────────────────────────────

func create_offer() -> void:
	## Host calls this to initiate connection
	_is_host = true
	_set_state(State.CONNECTING)

	# Create data channel (host creates it)
	_channel = _peer.create_data_channel("game", {
		"negotiated": false,
		"ordered": true
	})

	# Create and send offer
	_peer.create_offer()


func receive_offer(sdp: String) -> void:
	## Guest calls this when receiving offer from host
	_is_host = false
	_set_state(State.CONNECTING)

	# Set remote description (the offer)
	_peer.set_remote_description("offer", sdp)


func receive_answer(sdp: String) -> void:
	## Host calls this when receiving answer from guest
	_peer.set_remote_description("answer", sdp)


func add_ice_candidate(candidate: Dictionary) -> void:
	## Add ICE candidate from peer
	var media: String = candidate.get("media", candidate.get("sdpMid", ""))
	var index: int = candidate.get("index", candidate.get("sdpMLineIndex", 0))
	var sdp: String = candidate.get("sdp", candidate.get("candidate", ""))

	if sdp.is_empty():
		return

	_peer.add_ice_candidate(media, index, sdp)


func send(data: PackedByteArray) -> bool:
	## Send data to the peer
	if _channel == null or _channel.get_ready_state() != WebRTCDataChannel.STATE_OPEN:
		push_warning("WebRTCClient: Cannot send, channel not open")
		return false

	var err := _channel.put_packet(data)
	return err == OK


func close() -> void:
	## Close the connection
	if _channel != null:
		_channel.close()
		_channel = null

	if _peer != null:
		_peer.close()

	_set_state(State.DISCONNECTED)
	disconnected.emit()


# ─────────────────────────────────────────────────────────────────────────────
# Internal Callbacks
# ─────────────────────────────────────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	if _state != new_state:
		_state = new_state
		state_changed.emit(new_state)


func _on_session_description_created(type: String, sdp: String) -> void:
	## Called when local SDP is created
	_peer.set_local_description(type, sdp)

	if type == "offer":
		offer_created.emit(sdp)
	elif type == "answer":
		answer_created.emit(sdp)


func _on_ice_candidate_created(media: String, index: int, sdp: String) -> void:
	## Called when local ICE candidate is generated
	ice_candidate_generated.emit({
		"media": media,
		"index": index,
		"sdp": sdp
	})


func _on_data_channel_received(channel: WebRTCDataChannel) -> void:
	## Guest receives the data channel created by host
	_channel = channel
