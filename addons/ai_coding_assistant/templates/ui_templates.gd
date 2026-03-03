@tool
extends RefCounted

static func get_singleton_template() -> String:
	return """extends Node

# Singleton/Autoload template
# Add this to Project Settings > Autoload

signal game_state_changed(new_state)

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

var current_state: GameState = GameState.MENU
var player_data: Dictionary = {}
var game_settings: Dictionary = {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 1.0,
	"fullscreen": false
}

func _ready():
	# Initialize singleton
	load_settings()
	print("Game Manager initialized")

func change_state(new_state: GameState):
	if current_state != new_state:
		current_state = new_state
		game_state_changed.emit(new_state)
		print("Game state changed to: ", GameState.keys()[new_state])

func save_settings():
	var config = ConfigFile.new()
	for key in game_settings:
		config.set_value("settings", key, game_settings[key])
	config.save("user://game_settings.cfg")

func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://game_settings.cfg")
	if err == OK:
		for key in game_settings:
			game_settings[key] = config.get_value("settings", key, game_settings[key])

func get_setting(key: String, default_value = null):
	return game_settings.get(key, default_value)

func set_setting(key: String, value):
	game_settings[key] = value
	save_settings()
"""

static func get_ui_controller_template() -> String:
	return """extends Control

# UI Controller template for managing UI interactions

@onready var main_menu: Control = $MainMenu
@onready var settings_menu: Control = $SettingsMenu
@onready var pause_menu: Control = $PauseMenu

var current_menu: Control
var menu_stack: Array[Control] = []

func _ready():
	# Initialize UI
	show_menu(main_menu)
	
	# Connect common signals
	if has_signal("menu_changed"):
		menu_changed.connect(_on_menu_changed)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if menu_stack.size() > 1:
			go_back()
		elif current_menu == pause_menu:
			resume_game()

func show_menu(menu: Control, add_to_stack: bool = true):
	if current_menu:
		current_menu.hide()
	
	current_menu = menu
	if add_to_stack and menu not in menu_stack:
		menu_stack.append(menu)
	
	menu.show()
	
	# Focus first button if available
	var first_button = find_first_button(menu)
	if first_button:
		first_button.grab_focus()

func go_back():
	if menu_stack.size() > 1:
		menu_stack.pop_back()
		show_menu(menu_stack[-1], false)

func find_first_button(container: Control) -> Button:
	for child in container.get_children():
		if child is Button:
			return child
		elif child.get_child_count() > 0:
			var button = find_first_button(child)
			if button:
				return button
	return null

func pause_game():
	get_tree().paused = true
	show_menu(pause_menu)

func resume_game():
	get_tree().paused = false
	current_menu.hide()
	menu_stack.clear()

signal menu_changed(menu_name: String)

func _on_menu_changed(menu_name: String):
	print("Menu changed to: ", menu_name)
"""
