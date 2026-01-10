class_name AudioManagerClass
extends Node
## Manages all audio playback - SFX and music
## Access via AudioManager autoload singleton

const AudioThemeClass := preload("res://src/systems/audio_theme.gd")
const SFX_POOL_SIZE := 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _music_player: AudioStreamPlayer

var _current_theme: Resource  # AudioTheme
var enabled := true


func _ready() -> void:
	# Create SFX player pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)


func set_theme(theme: Resource) -> void:
	_current_theme = theme


func get_theme() -> Resource:
	return _current_theme


# ─────────────────────────────────────────────────────────────────────────────
# SFX Playback
# ─────────────────────────────────────────────────────────────────────────────

func play_sfx(stream: AudioStream) -> void:
	if not enabled or stream == null:
		return

	var player := _sfx_players[_sfx_index]
	player.stream = stream
	player.play()
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE


func play_move(piece_type: int = -1) -> void:
	if _current_theme == null:
		return
	if piece_type >= 0:
		play_sfx(_current_theme.get_move_sound(piece_type))
	else:
		play_sfx(_current_theme.sfx_move)


func play_capture() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_capture)


func play_place() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_place)


func play_check() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_check)


func play_checkmate() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_checkmate)


func play_stalemate() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_stalemate)


func play_game_start() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_game_start)


func play_click() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_click)


func play_select() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_select)


func play_collision() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_collision)


func play_triplet_clear() -> void:
	if _current_theme:
		play_sfx(_current_theme.sfx_triplet_clear)


# ─────────────────────────────────────────────────────────────────────────────
# Music Playback
# ─────────────────────────────────────────────────────────────────────────────

func play_music(stream: AudioStream, fade_in := 1.0) -> void:
	if not enabled or stream == null:
		return

	if _music_player.playing:
		# Crossfade
		var fade_out_tween := create_tween()
		fade_out_tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
		await fade_out_tween.finished

	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.play()

	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(_music_player, "volume_db", 0.0, fade_in)


func play_gameplay_music() -> void:
	if _current_theme and _current_theme.music_gameplay:
		play_music(_current_theme.music_gameplay)


func play_menu_music() -> void:
	if _current_theme and _current_theme.music_menu:
		play_music(_current_theme.music_menu)


func stop_music(fade_out := 1.0) -> void:
	if not _music_player.playing:
		return

	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_out)
	await tween.finished
	_music_player.stop()


func is_music_playing() -> bool:
	return _music_player.playing


# ─────────────────────────────────────────────────────────────────────────────
# Volume Control
# ─────────────────────────────────────────────────────────────────────────────

func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(linear)
	)


func set_music_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(linear)
	)


func set_sfx_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"),
		linear_to_db(linear)
	)


func get_master_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index("Master")
	))


func get_music_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index("Music")
	))


func get_sfx_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index("SFX")
	))
