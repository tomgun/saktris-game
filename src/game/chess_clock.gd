class_name ChessClock
extends RefCounted
## Chess clock timer with support for various time controls
## Note: Call tick(delta) from game loop to update time

# Standard time controls
const TIME_CONTROLS := {
	"bullet_1_0": {"time": 60.0, "increment": 0.0, "category": "Bullet"},
	"bullet_2_1": {"time": 120.0, "increment": 1.0, "category": "Bullet"},
	"blitz_3_0": {"time": 180.0, "increment": 0.0, "category": "Blitz"},
	"blitz_5_0": {"time": 300.0, "increment": 0.0, "category": "Blitz"},
	"blitz_5_3": {"time": 300.0, "increment": 3.0, "category": "Blitz"},
	"rapid_10_0": {"time": 600.0, "increment": 0.0, "category": "Rapid"},
	"rapid_15_10": {"time": 900.0, "increment": 10.0, "category": "Rapid"},
	"rapid_30_0": {"time": 1800.0, "increment": 0.0, "category": "Rapid"},
}

signal time_expired(side: int)
signal time_updated(white_time: float, black_time: float)
signal low_time_warning(side: int, seconds_remaining: float)

var white_time_remaining: float = 0.0
var black_time_remaining: float = 0.0
var increment: float = 0.0
var active_side: int = -1  # -1 = paused, 0 = white, 1 = black
var initial_time: float = 0.0

# Thresholds for warnings (in seconds)
const LOW_TIME_THRESHOLD := 30.0
const CRITICAL_TIME_THRESHOLD := 10.0

var _running := false
var _white_warned_low := false
var _white_warned_critical := false
var _black_warned_low := false
var _black_warned_critical := false


func setup(time_seconds: float, increment_seconds: float = 0.0) -> void:
	## Initialize the clock with a time control
	initial_time = time_seconds
	increment = increment_seconds
	white_time_remaining = time_seconds
	black_time_remaining = time_seconds
	active_side = -1
	_running = false
	_reset_warnings()


func setup_from_preset(preset_name: String) -> bool:
	## Setup from a named time control preset
	if TIME_CONTROLS.has(preset_name):
		var tc: Dictionary = TIME_CONTROLS[preset_name]
		setup(tc["time"], tc["increment"])
		return true
	return false


func start() -> void:
	## Start the clock for white's first move
	if initial_time <= 0:
		return
	active_side = Piece.Side.WHITE
	_running = true


func pause() -> void:
	## Pause the clock
	_running = false


func resume() -> void:
	## Resume the clock
	if active_side >= 0:
		_running = true


func is_running() -> bool:
	return _running


func switch_side() -> void:
	## Switch to the other player and add increment
	if not _running:
		return

	# Add increment to the player who just moved
	if active_side == Piece.Side.WHITE:
		white_time_remaining += increment
	else:
		black_time_remaining += increment

	# Switch sides
	active_side = Piece.Side.BLACK if active_side == Piece.Side.WHITE else Piece.Side.WHITE

	time_updated.emit(white_time_remaining, black_time_remaining)


func get_active_side() -> int:
	return active_side


func get_time_remaining(side: int) -> float:
	return white_time_remaining if side == Piece.Side.WHITE else black_time_remaining


func tick(delta: float) -> void:
	## Call this from game loop to update time
	if not _running or active_side < 0:
		return

	# Decrement active side's time
	if active_side == Piece.Side.WHITE:
		white_time_remaining -= delta
		_check_time_status(Piece.Side.WHITE, white_time_remaining)
	else:
		black_time_remaining -= delta
		_check_time_status(Piece.Side.BLACK, black_time_remaining)

	time_updated.emit(white_time_remaining, black_time_remaining)


func _check_time_status(side: int, time: float) -> void:
	## Check for time warnings and expiry
	if time <= 0:
		# Time expired
		if side == Piece.Side.WHITE:
			white_time_remaining = 0.0
		else:
			black_time_remaining = 0.0
		_running = false
		time_expired.emit(side)
		return

	# Check for warnings
	if side == Piece.Side.WHITE:
		if time <= CRITICAL_TIME_THRESHOLD and not _white_warned_critical:
			_white_warned_critical = true
			low_time_warning.emit(side, time)
		elif time <= LOW_TIME_THRESHOLD and not _white_warned_low:
			_white_warned_low = true
			low_time_warning.emit(side, time)
	else:
		if time <= CRITICAL_TIME_THRESHOLD and not _black_warned_critical:
			_black_warned_critical = true
			low_time_warning.emit(side, time)
		elif time <= LOW_TIME_THRESHOLD and not _black_warned_low:
			_black_warned_low = true
			low_time_warning.emit(side, time)


func _reset_warnings() -> void:
	_white_warned_low = false
	_white_warned_critical = false
	_black_warned_low = false
	_black_warned_critical = false


func set_time(side: int, time: float) -> void:
	## Set time for a specific side (for loading games)
	if side == Piece.Side.WHITE:
		white_time_remaining = time
	else:
		black_time_remaining = time


static func format_time(seconds: float) -> String:
	## Format time as MM:SS or M:SS.s for <10 seconds
	if seconds <= 0:
		return "0:00"

	var mins := int(seconds) / 60
	var secs := fmod(seconds, 60.0)

	if seconds < 10.0:
		# Show tenths for critical time
		return "%d:%04.1f" % [mins, secs]
	else:
		return "%d:%02d" % [mins, int(secs)]


static func get_time_control_display_name(preset_name: String) -> String:
	## Get human-readable name for a time control preset
	if not TIME_CONTROLS.has(preset_name):
		return preset_name

	var tc: Dictionary = TIME_CONTROLS[preset_name]
	var mins := int(tc["time"]) / 60
	var inc := int(tc["increment"])

	if inc > 0:
		return "%s %d+%d" % [tc["category"], mins, inc]
	else:
		return "%s %d+0" % [tc["category"], mins]


func to_dict() -> Dictionary:
	## Serialize for save/load
	return {
		"white_time_remaining": white_time_remaining,
		"black_time_remaining": black_time_remaining,
		"initial_time": initial_time,
		"increment": increment,
		"active_side": active_side,
		"running": _running
	}


static func from_dict(data: Dictionary) -> ChessClock:
	## Create ChessClock from save data
	## Note: Returns an unparented instance - caller must add to scene tree
	var clock := ChessClock.new()
	clock.white_time_remaining = data.get("white_time_remaining", 0.0)
	clock.black_time_remaining = data.get("black_time_remaining", 0.0)
	clock.initial_time = data.get("initial_time", 0.0)
	clock.increment = data.get("increment", 0.0)
	clock.active_side = data.get("active_side", -1)
	clock._running = data.get("running", false)
	return clock
