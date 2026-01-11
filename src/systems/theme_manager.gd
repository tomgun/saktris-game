class_name ThemeManagerClass
extends Node
## Manages audiovisual themes - loads, switches, and persists theme selection
## Access via ThemeManager autoload singleton

const AudioThemeClass := preload("res://src/systems/audio_theme.gd")

signal theme_changed(theme: Resource)

const THEMES_PATH := "res://assets/audio/themes/"
const DEFAULT_THEME := "classic"

var _available_themes: Dictionary = {}  # theme_id -> AudioTheme Resource
var _current_theme: Resource  # AudioTheme


func _ready() -> void:
	_load_available_themes()
	_apply_saved_theme()


func _load_available_themes() -> void:
	# Scan themes directory for .tres theme resources
	var dir := DirAccess.open(THEMES_PATH)
	if dir == null:
		push_warning("ThemeManager: Could not open themes directory: " + THEMES_PATH)
		return

	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var theme_path := THEMES_PATH + folder_name + "/theme.tres"
			if ResourceLoader.exists(theme_path):
				var theme: Resource = load(theme_path)
				if theme and theme.has_method("get_move_sound"):
					_available_themes[theme.theme_id] = theme
					print("ThemeManager: Loaded theme '%s'" % theme.theme_name)
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
		push_warning("ThemeManager: No themes available")


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
