extends GutTest
## Unit tests for ChessClock (F-0016: TimerMode)

var clock: ChessClock


func before_each() -> void:
	clock = ChessClock.new()


# ─────────────────────────────────────────────────────────────────────────────
# Basic Setup Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_initial_state() -> void:
	## Clock should start in stopped state
	assert_false(clock.is_running())
	assert_eq(clock.get_active_side(), -1)


func test_setup_with_time_and_increment() -> void:
	## Setup should initialize both clocks with same time
	clock.setup(300.0, 5.0)

	assert_eq(clock.white_time_remaining, 300.0)
	assert_eq(clock.black_time_remaining, 300.0)
	assert_eq(clock.increment, 5.0)


func test_setup_from_preset_bullet() -> void:
	## Should set correct time for bullet 1+0
	assert_true(clock.setup_from_preset("bullet_1_0"))

	assert_eq(clock.white_time_remaining, 60.0)
	assert_eq(clock.black_time_remaining, 60.0)
	assert_eq(clock.increment, 0.0)


func test_setup_from_preset_blitz() -> void:
	## Should set correct time for blitz 5+3
	assert_true(clock.setup_from_preset("blitz_5_3"))

	assert_eq(clock.white_time_remaining, 300.0)
	assert_eq(clock.black_time_remaining, 300.0)
	assert_eq(clock.increment, 3.0)


func test_setup_from_preset_invalid() -> void:
	## Should return false for invalid preset
	assert_false(clock.setup_from_preset("invalid_preset"))


# ─────────────────────────────────────────────────────────────────────────────
# Running State Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_start_activates_white() -> void:
	## Starting clock should activate white's time
	clock.setup(300.0)
	clock.start()

	assert_true(clock.is_running())
	assert_eq(clock.get_active_side(), Piece.Side.WHITE)


func test_pause_stops_clock() -> void:
	## Pausing should stop the clock
	clock.setup(300.0)
	clock.start()
	clock.pause()

	assert_false(clock.is_running())


func test_resume_after_pause() -> void:
	## Resume should restart the clock
	clock.setup(300.0)
	clock.start()
	clock.pause()
	clock.resume()

	assert_true(clock.is_running())


func test_cannot_start_without_setup() -> void:
	## Should not start if no time set
	clock.start()
	assert_false(clock.is_running())


# ─────────────────────────────────────────────────────────────────────────────
# Time Countdown Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_tick_decrements_active_side() -> void:
	## Tick should decrement active player's time
	clock.setup(300.0)
	clock.start()

	clock.tick(1.0)

	assert_eq(clock.white_time_remaining, 299.0)
	assert_eq(clock.black_time_remaining, 300.0)  # Black unchanged


func test_tick_does_nothing_when_paused() -> void:
	## Tick should not change time when paused
	clock.setup(300.0)
	clock.start()
	clock.pause()

	clock.tick(1.0)

	assert_eq(clock.white_time_remaining, 300.0)
	assert_eq(clock.black_time_remaining, 300.0)


func test_tick_decrements_black_after_switch() -> void:
	## After switch, tick should decrement black's time
	clock.setup(300.0)
	clock.start()
	clock.switch_side()

	clock.tick(1.0)

	assert_eq(clock.white_time_remaining, 300.0)  # White unchanged
	assert_eq(clock.black_time_remaining, 299.0)


# ─────────────────────────────────────────────────────────────────────────────
# Side Switching Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_switch_side_changes_active() -> void:
	## Switch should change active side
	clock.setup(300.0)
	clock.start()

	assert_eq(clock.get_active_side(), Piece.Side.WHITE)

	clock.switch_side()

	assert_eq(clock.get_active_side(), Piece.Side.BLACK)


func test_switch_side_adds_increment() -> void:
	## Switch should add increment to player who just moved
	clock.setup(300.0, 5.0)
	clock.start()

	# Simulate white using 10 seconds
	clock.tick(10.0)
	assert_eq(clock.white_time_remaining, 290.0)

	# Switch adds increment to white
	clock.switch_side()

	assert_eq(clock.white_time_remaining, 295.0)  # 290 + 5
	assert_eq(clock.black_time_remaining, 300.0)  # Unchanged


func test_switch_side_does_nothing_when_not_running() -> void:
	## Switch should do nothing if clock not running
	clock.setup(300.0, 5.0)

	clock.switch_side()

	assert_eq(clock.white_time_remaining, 300.0)
	assert_eq(clock.black_time_remaining, 300.0)


# ─────────────────────────────────────────────────────────────────────────────
# Time Expiry Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_time_expired_signal() -> void:
	## Should emit time_expired when time runs out
	clock.setup(1.0)
	clock.start()

	watch_signals(clock)

	# Run out white's time
	clock.tick(1.5)

	assert_signal_emitted(clock, "time_expired")
	assert_false(clock.is_running())


func test_time_bottoms_out_at_zero() -> void:
	## Time should not go negative
	clock.setup(1.0)
	clock.start()

	clock.tick(5.0)  # Way more than available

	assert_eq(clock.white_time_remaining, 0.0)


# ─────────────────────────────────────────────────────────────────────────────
# Time Formatting Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_format_time_minutes_seconds() -> void:
	## Should format as M:SS for normal time
	assert_eq(ChessClock.format_time(300.0), "5:00")
	assert_eq(ChessClock.format_time(125.0), "2:05")
	assert_eq(ChessClock.format_time(60.0), "1:00")


func test_format_time_under_minute() -> void:
	## Should format correctly under 1 minute
	assert_eq(ChessClock.format_time(45.0), "0:45")
	assert_eq(ChessClock.format_time(30.0), "0:30")


func test_format_time_critical() -> void:
	## Should show tenths for <10 seconds
	assert_eq(ChessClock.format_time(9.5), "0:09.5")
	assert_eq(ChessClock.format_time(5.3), "0:05.3")
	assert_eq(ChessClock.format_time(0.1), "0:00.1")


func test_format_time_zero() -> void:
	## Should handle zero
	assert_eq(ChessClock.format_time(0.0), "0:00")


# ─────────────────────────────────────────────────────────────────────────────
# Low Time Warning Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_low_time_warning_at_30_seconds() -> void:
	## Should emit warning at 30 seconds
	clock.setup(35.0)
	clock.start()

	watch_signals(clock)

	clock.tick(6.0)  # Down to 29 seconds

	assert_signal_emitted(clock, "low_time_warning")


func test_low_time_warning_only_once() -> void:
	## Warning should only emit once per side
	clock.setup(35.0)
	clock.start()

	watch_signals(clock)

	clock.tick(6.0)  # First warning
	clock.tick(1.0)  # Should not warn again

	assert_signal_emit_count(clock, "low_time_warning", 1)


# ─────────────────────────────────────────────────────────────────────────────
# Serialization Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_serialization_roundtrip() -> void:
	## to_dict/from_dict should preserve state
	clock.setup(300.0, 5.0)
	clock.start()
	clock.tick(50.0)
	clock.switch_side()
	clock.tick(20.0)

	var data := clock.to_dict()
	var restored := ChessClock.from_dict(data)

	assert_eq(restored.white_time_remaining, clock.white_time_remaining)
	assert_eq(restored.black_time_remaining, clock.black_time_remaining)
	assert_eq(restored.increment, clock.increment)
	assert_eq(restored.initial_time, clock.initial_time)


# ─────────────────────────────────────────────────────────────────────────────
# Display Name Tests
# ─────────────────────────────────────────────────────────────────────────────

func test_get_time_control_display_name() -> void:
	## Should return readable names for presets
	assert_eq(ChessClock.get_time_control_display_name("bullet_1_0"), "Bullet 1+0")
	assert_eq(ChessClock.get_time_control_display_name("blitz_5_3"), "Blitz 5+3")
	assert_eq(ChessClock.get_time_control_display_name("rapid_15_10"), "Rapid 15+10")


func test_get_time_control_display_name_invalid() -> void:
	## Should return input for unknown preset
	assert_eq(ChessClock.get_time_control_display_name("unknown"), "unknown")
