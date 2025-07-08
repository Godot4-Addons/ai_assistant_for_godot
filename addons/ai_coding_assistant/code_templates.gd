@tool
extends RefCounted

# Code templates for quick generation

static func get_template(template_name: String) -> String:
	match template_name:
		"player_movement":
			return get_player_movement_template()
		"singleton":
			return get_singleton_template()
		"ui_controller":
			return get_ui_controller_template()
		"state_machine":
			return get_state_machine_template()
		"inventory_system":
			return get_inventory_system_template()
		"save_system":
			return get_save_system_template()
		"audio_manager":
			return get_audio_manager_template()
		"scene_manager":
			return get_scene_manager_template()
		"input_handler":
			return get_input_handler_template()
		"health_system":
			return get_health_system_template()
		_:
			return ""

static func get_player_movement_template() -> String:
	return """extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Apply movement
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()
"""

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

static func get_state_machine_template() -> String:
	return """extends Node

# Generic State Machine implementation

signal state_changed(old_state, new_state)

var states: Dictionary = {}
var current_state: String = ""
var previous_state: String = ""

func _ready():
	# Initialize states
	setup_states()

func setup_states():
	# Override this method to add states
	# Example:
	# add_state("idle", _idle_enter, _idle_update, _idle_exit)
	# add_state("moving", _moving_enter, _moving_update, _moving_exit)
	pass

func add_state(state_name: String, enter_func: Callable = Callable(), update_func: Callable = Callable(), exit_func: Callable = Callable()):
	states[state_name] = {
		"enter": enter_func,
		"update": update_func,
		"exit": exit_func
	}

func change_state(new_state: String):
	if new_state == current_state:
		return
	
	if current_state != "" and states.has(current_state):
		var exit_func = states[current_state]["exit"]
		if exit_func.is_valid():
			exit_func.call()
	
	previous_state = current_state
	current_state = new_state
	
	if states.has(current_state):
		var enter_func = states[current_state]["enter"]
		if enter_func.is_valid():
			enter_func.call()
	
	state_changed.emit(previous_state, current_state)

func _process(delta):
	if current_state != "" and states.has(current_state):
		var update_func = states[current_state]["update"]
		if update_func.is_valid():
			update_func.call(delta)

func get_current_state() -> String:
	return current_state

func get_previous_state() -> String:
	return previous_state
"""

static func get_template_list() -> Array[String]:
	return [
		"player_movement",
		"singleton", 
		"ui_controller",
		"state_machine",
		"inventory_system",
		"save_system",
		"audio_manager",
		"scene_manager",
		"input_handler",
		"health_system"
	]

static func get_inventory_system_template() -> String:
	return """extends Node

# Inventory System
signal item_added(item: Dictionary)
signal item_removed(item: Dictionary)
signal inventory_full()

var items: Array[Dictionary] = []
var max_slots: int = 20

func add_item(item_id: String, quantity: int = 1) -> bool:
	var existing_item = find_item(item_id)

	if existing_item:
		existing_item["quantity"] += quantity
		item_added.emit(existing_item)
		return true
	elif items.size() < max_slots:
		var new_item = {"id": item_id, "quantity": quantity}
		items.append(new_item)
		item_added.emit(new_item)
		return true
	else:
		inventory_full.emit()
		return false

func remove_item(item_id: String, quantity: int = 1) -> bool:
	var item = find_item(item_id)
	if item and item["quantity"] >= quantity:
		item["quantity"] -= quantity
		if item["quantity"] <= 0:
			items.erase(item)
		item_removed.emit(item)
		return true
	return false

func find_item(item_id: String) -> Dictionary:
	for item in items:
		if item["id"] == item_id:
			return item
	return {}

func has_item(item_id: String, quantity: int = 1) -> bool:
	var item = find_item(item_id)
	return item and item["quantity"] >= quantity

func get_item_count(item_id: String) -> int:
	var item = find_item(item_id)
	return item["quantity"] if item else 0
"""

static func get_save_system_template() -> String:
	return """extends Node

# Save/Load System
const SAVE_FILE = "user://savegame.save"

func save_game(data: Dictionary) -> bool:
	var save_file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if save_file == null:
		print("Error opening save file for writing")
		return false

	var json_string = JSON.stringify(data)
	save_file.store_string(json_string)
	save_file.close()
	print("Game saved successfully")
	return true

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE):
		print("Save file does not exist")
		return {}

	var save_file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if save_file == null:
		print("Error opening save file for reading")
		return {}

	var json_string = save_file.get_as_text()
	save_file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("Error parsing save file")
		return {}

	print("Game loaded successfully")
	return json.data

func delete_save() -> bool:
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
		print("Save file deleted")
		return true
	return false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)
"""

static func get_audio_manager_template() -> String:
	return """extends Node

# Audio Manager
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var music_volume: float = 1.0
var sfx_volume: float = 1.0

func _ready():
	music_player = AudioStreamPlayer.new()
	sfx_player = AudioStreamPlayer.new()
	add_child(music_player)
	add_child(sfx_player)

func play_music(stream: AudioStream, fade_in: bool = false):
	if fade_in:
		var tween = create_tween()
		music_player.volume_db = -80
		music_player.stream = stream
		music_player.play()
		tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), 1.0)
	else:
		music_player.stream = stream
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play()

func stop_music(fade_out: bool = false):
	if fade_out:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, 1.0)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()

func play_sfx(stream: AudioStream):
	sfx_player.stream = stream
	sfx_player.volume_db = linear_to_db(sfx_volume)
	sfx_player.play()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
"""

static func get_template_description(template_name: String) -> String:
	match template_name:
		"player_movement":
			return "2D character movement with physics"
		"singleton":
			return "Game manager singleton/autoload"
		"ui_controller":
			return "UI navigation and menu controller"
		"state_machine":
			return "Generic state machine implementation"
		"inventory_system":
			return "Item inventory management system"
		"save_system":
			return "Game save/load functionality"
		"audio_manager":
			return "Audio and music management"
		"scene_manager":
			return "Scene transition management"
		"input_handler":
			return "Input mapping and handling"
		"health_system":
			return "Health and damage system"
		_:
			return "Code template"

static func get_scene_manager_template() -> String:
	return """extends Node

# Scene Manager for handling scene transitions
signal scene_changed(scene_name: String)

var current_scene: Node = null
var loading_screen: Control = null

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

func goto_scene(path: String):
	call_deferred("_deferred_goto_scene", path)

func _deferred_goto_scene(path: String):
	if current_scene:
		current_scene.free()

	var new_scene = ResourceLoader.load(path)
	if new_scene:
		current_scene = new_scene.instantiate()
		get_tree().root.add_child(current_scene)
		get_tree().current_scene = current_scene
		scene_changed.emit(path)
	else:
		print("Error loading scene: ", path)

func reload_current_scene():
	get_tree().reload_current_scene()
"""

static func get_input_handler_template() -> String:
	return """extends Node

# Input Handler for managing input actions
signal action_pressed(action: String)
signal action_released(action: String)

var input_map: Dictionary = {}
var is_input_enabled: bool = true

func _ready():
	# Setup default input mappings
	setup_input_map()

func _input(event: InputEvent):
	if not is_input_enabled:
		return

	for action in input_map.keys():
		if event.is_action_pressed(action):
			action_pressed.emit(action)
		elif event.is_action_released(action):
			action_released.emit(action)

func setup_input_map():
	input_map = {
		"move_left": "ui_left",
		"move_right": "ui_right",
		"move_up": "ui_up",
		"move_down": "ui_down",
		"jump": "ui_accept",
		"interact": "ui_select"
	}

func enable_input():
	is_input_enabled = true

func disable_input():
	is_input_enabled = false

func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action) and is_input_enabled
"""

static func get_health_system_template() -> String:
	return """extends Node

# Health System Component
signal health_changed(old_health: int, new_health: int)
signal died()
signal healed(amount: int)
signal damaged(amount: int)

@export var max_health: int = 100
@export var current_health: int = 100
@export var regeneration_rate: float = 0.0
@export var invincibility_time: float = 1.0

var is_invincible: bool = false
var invincibility_timer: Timer

func _ready():
	current_health = max_health
	setup_invincibility_timer()

func setup_invincibility_timer():
	invincibility_timer = Timer.new()
	invincibility_timer.wait_time = invincibility_time
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(invincibility_timer)

func take_damage(amount: int):
	if is_invincible or current_health <= 0:
		return

	var old_health = current_health
	current_health = max(0, current_health - amount)
	health_changed.emit(old_health, current_health)
	damaged.emit(amount)

	if current_health <= 0:
		died.emit()
	else:
		is_invincible = true
		invincibility_timer.start()

func heal(amount: int):
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	health_changed.emit(old_health, current_health)
	healed.emit(amount)

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)

func is_alive() -> bool:
	return current_health > 0

func _on_invincibility_timeout():
	is_invincible = false
"""
