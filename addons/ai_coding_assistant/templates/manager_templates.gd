@tool
extends RefCounted

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
