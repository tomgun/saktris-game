class_name ThemeManagerClass
extends Node
## Manages audiovisual themes - loads, switches, and persists theme selection
## Access via ThemeManager autoload singleton

const AudioThemeClass := preload("res://src/systems/audio_theme.gd")
const VisualThemeClass := preload("res://src/systems/visual_theme.gd")

signal theme_changed(theme: Resource)
signal visual_theme_changed(theme: Resource)  # VisualTheme resource

const AUDIO_THEMES_PATH := "res://assets/audio/themes/"
const VISUAL_THEMES_PATH := "res://assets/visual_themes/"
const DEFAULT_THEME := "classic"
const DEFAULT_VISUAL_THEME := "retrofuturistic"

var _available_themes: Dictionary = {}  # theme_id -> AudioTheme Resource
var _current_theme: Resource  # AudioTheme

var _available_visual_themes: Dictionary = {}  # theme_id -> VisualTheme Resource
var _current_visual_theme: Resource  # VisualTheme


func _ready() -> void:
	_load_available_themes()
	_load_available_visual_themes()
	_apply_saved_theme()
	_apply_saved_visual_theme()


func _load_available_themes() -> void:
	# Scan audio themes directory for .tres theme resources
	var dir := DirAccess.open(AUDIO_THEMES_PATH)
	if dir == null:
		push_warning("ThemeManager: Could not open audio themes directory: " + AUDIO_THEMES_PATH)
		return

	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var theme_path := AUDIO_THEMES_PATH + folder_name + "/theme.tres"
			if ResourceLoader.exists(theme_path):
				var theme: Resource = load(theme_path)
				if theme and theme.has_method("get_move_sound"):
					_available_themes[theme.theme_id] = theme
					print("ThemeManager: Loaded audio theme '%s'" % theme.theme_name)
		folder_name = dir.get_next()
	dir.list_dir_end()


func _load_available_visual_themes() -> void:
	# Scan visual themes directory for .tres theme resources
	var dir := DirAccess.open(VISUAL_THEMES_PATH)
	if dir == null:
		push_warning("ThemeManager: Could not open visual themes directory: " + VISUAL_THEMES_PATH)
		return

	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var theme_path := VISUAL_THEMES_PATH + folder_name + "/visual.tres"
			if ResourceLoader.exists(theme_path):
				var theme: Resource = load(theme_path)
				if theme is VisualThemeClass:
					_available_visual_themes[theme.theme_id] = theme
					print("ThemeManager: Loaded visual theme '%s'" % theme.theme_name)
		folder_name = dir.get_next()
	dir.list_dir_end()


func _apply_saved_theme() -> void:
	var saved_id := Settings.audio_theme if Settings else DEFAULT_THEME
	if _available_themes.has(saved_id):
		set_theme(saved_id)
	elif _available_themes.size() > 0:
		# Fallback to first available theme
		set_theme(_available_themes.keys()[0])
	else:
		push_warning("ThemeManager: No audio themes available")


func _apply_saved_visual_theme() -> void:
	var saved_id := Settings.board_theme if Settings else DEFAULT_VISUAL_THEME
	if _available_visual_themes.has(saved_id):
		set_visual_theme(saved_id)
	elif _available_visual_themes.size() > 0:
		# Fallback to first available theme
		set_visual_theme(_available_visual_themes.keys()[0])
	else:
		push_warning("ThemeManager: No visual themes available")


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func get_available_themes() -> Array:
	## Returns array of {id: String, name: String} for UI
	var result := []
	for id in _available_themes:
		var theme: Resource = _available_themes[id]
		result.append({"id": id, "name": theme.theme_name})
	return result


func get_current_theme() -> Resource:
	return _current_theme


func get_current_theme_id() -> String:
	return _current_theme.theme_id if _current_theme else ""


func set_theme(theme_id: String) -> bool:
	## Switch to theme by ID. Returns true if successful.
	if not _available_themes.has(theme_id):
		push_warning("ThemeManager: Unknown theme: " + theme_id)
		return false

	_current_theme = _available_themes[theme_id]

	# Update AudioManager
	if AudioManager:
		AudioManager.set_theme(_current_theme)

	# Save preference
	if Settings:
		Settings.audio_theme = theme_id
		Settings.save_settings()

	theme_changed.emit(_current_theme)
	print("ThemeManager: Switched to theme '%s'" % _current_theme.theme_name)
	return true


func reload_themes() -> void:
	## Re-scan themes directory (useful for development)
	_available_themes.clear()
	_load_available_themes()
	_apply_saved_theme()


# ─────────────────────────────────────────────────────────────────────────────
# Visual Theme Public API
# ─────────────────────────────────────────────────────────────────────────────

func get_available_visual_themes() -> Array:
	## Returns array of {id: String, name: String} for UI
	var result := []
	for id in _available_visual_themes:
		var theme: Resource = _available_visual_themes[id]
		result.append({"id": id, "name": theme.theme_name})
	return result


func get_current_visual_theme() -> Resource:
	## Returns current VisualTheme resource
	return _current_visual_theme


func get_current_visual_theme_id() -> String:
	return _current_visual_theme.theme_id if _current_visual_theme else ""


func set_visual_theme(theme_id: String) -> bool:
	## Switch to visual theme by ID. Returns true if successful.
	if not _available_visual_themes.has(theme_id):
		push_warning("ThemeManager: Unknown visual theme: " + theme_id)
		return false

	_current_visual_theme = _available_visual_themes[theme_id]

	# Save preference
	if Settings:
		Settings.board_theme = theme_id
		Settings.save_settings()

	visual_theme_changed.emit(_current_visual_theme)
	print("ThemeManager: Switched to visual theme '%s'" % _current_visual_theme.theme_name)
	return true


func reload_visual_themes() -> void:
	## Re-scan visual themes directory (useful for development)
	_available_visual_themes.clear()
	_load_available_visual_themes()
	_apply_saved_visual_theme()
