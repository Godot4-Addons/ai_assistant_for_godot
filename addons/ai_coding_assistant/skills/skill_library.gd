@tool
extends RefCounted
class_name AISkillLibrary

const SkillDef = preload("res://addons/ai_coding_assistant/skills/skill_definition.gd")

static func get_all_skills() -> Array[SkillDefinition]:
	return [
		_state_machine_skill(),
		_player_2d_skill(),
		_player_3d_skill(),
		_enemy_patrol_skill(),
		_health_system_skill(),
		_inventory_system_skill(),
		_save_load_json_skill(),
		_singleton_autoload_skill(),
		_ui_screen_skill(),
		_camera_follow_skill(),
		_object_pool_skill(),
		_event_bus_skill(),
		_dialogue_system_skill(),
	]

static func _state_machine_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "state_machine"
	s.description = "Generic enum-based state machine for any game object"
	s.tags = ["pattern", "architecture"]
	s.params = {
		"class_name": {"type": "String", "default": "GameEntity", "description": "Name of the class"},
		"extends": {"type": "String", "default": "Node", "description": "Base class"},
		"states": {"type": "Array", "default": ["idle", "active"], "description": "List of state names"}
	}
	s.suggested_path_template = "res://scripts/{{class_name}}.gd"
	s.template = """extends {{extends}}
class_name {{class_name}}

enum State { {{STATES_ENUM}} }

var current_state: State = State.{{DEFAULT_STATE}}

func _ready() -> void:
	_enter_state(current_state)

func _process(delta: float) -> void:
	_update_state(delta)

func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	_exit_state(current_state)
	current_state = new_state
	_enter_state(current_state)

func _enter_state(state: State) -> void:
	match state:
{{ENTER_CASES}}

func _exit_state(state: State) -> void:
	match state:
{{EXIT_CASES}}

func _update_state(delta: float) -> void:
	match current_state:
{{UPDATE_CASES}}
"""
	return s

static func _player_2d_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "player_2d"
	s.description = "CharacterBody2D player with movement, jump, coyote time, and jump buffer"
	s.tags = ["2d", "player", "movement"]
	s.params = {
		"class_name": {"type": "String", "default": "Player", "description": "Class name"},
		"speed": {"type": "int", "default": "200", "description": "Horizontal speed"},
		"jump_velocity": {"type": "int", "default": "-400", "description": "Jump impulse"},
		"gravity": {"type": "int", "default": "1200", "description": "Gravity acceleration"}
	}
	s.suggested_path_template = "res://scripts/{{class_name}}.gd"
	s.template = """extends CharacterBody2D
class_name {{class_name}}

@export var speed: int = {{speed}}
@export var jump_velocity: int = {{jump_velocity}}
@export var gravity: int = {{gravity}}

var coyote_time: float = 0.1
var jump_buffer: float = 0.1
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta

	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed

	if Input.is_action_just_pressed("ui_accept"):
		_jump_buffer_timer = jump_buffer
	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
	_jump_buffer_timer -= delta

	move_and_slide()
"""
	return s

static func _player_3d_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "player_3d"
	s.description = "CharacterBody3D player with movement, jump, and camera control"
	s.tags = ["3d", "player", "movement"]
	s.params = {
		"class_name": {"type": "String", "default": "Player3D", "description": "Class name"},
		"speed": {"type": "int", "default": "5", "description": "Movement speed"},
		"jump_velocity": {"type": "int", "default": "8", "description": "Jump strength"},
		"mouse_sensitivity": {"type": "float", "default": "0.002", "description": "Mouse look sensitivity"}
	}
	s.suggested_path_template = "res://scripts/{{class_name}}.gd"
	s.template = """extends CharacterBody3D
class_name {{class_name}}

@export var speed: float = {{speed}}
@export var jump_velocity: float = {{jump_velocity}}
@export var mouse_sensitivity: float = {{mouse_sensitivity}}

@onready var camera_pivot: Node3D = $CameraPivot

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -1.5, 1.5)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 15 * delta

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction.length() > 0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
"""
	return s

static func _enemy_patrol_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "enemy_patrol"
	s.description = "Enemy with patrol, chase, and attack states"
	s.tags = ["2d", "enemy", "ai"]
	s.params = {
		"class_name": {"type": "String", "default": "Enemy", "description": "Class name"},
		"speed": {"type": "int", "default": "60", "description": "Patrol speed"},
		"chase_speed": {"type": "int", "default": "120", "description": "Chase speed"},
		"detect_range": {"type": "int", "default": "200", "description": "Detection range"},
		"player_path": {"type": "String", "default": "../Player", "description": "Node path to player"}
	}
	s.suggested_path_template = "res://scripts/{{class_name}}.gd"
	s.template = """extends CharacterBody2D
class_name {{class_name}}

enum State { PATROL, CHASE, ATTACK }

@export var speed: int = {{speed}}
@export var chase_speed: int = {{chase_speed}}
@export var detect_range: int = {{detect_range}}
@export var player_path: NodePath = NodePath("{{player_path}}")

var state: State = State.PATROL
var player: Node2D
var patrol_direction: int = 1

func _ready() -> void:
	player = get_node(player_path)

func _physics_process(delta: float) -> void:
	match state:
		State.PATROL:
			velocity.x = patrol_direction * speed
			if not $RayCast2D.is_colliding():
				patrol_direction *= -1
			if player and global_position.distance_to(player.global_position) < detect_range:
				state = State.CHASE

		State.CHASE:
			if not player:
				state = State.PATROL
				return
			var dir := sign(player.global_position.x - global_position.x)
			velocity.x = dir * chase_speed
			if global_position.distance_to(player.global_position) > detect_range * 1.5:
				state = State.PATROL

	move_and_slide()
"""
	return s

static func _health_system_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "health_system"
	s.description = "Health component with damage, healing, signals, and invulnerability"
	s.tags = ["component", "gameplay"]
	s.params = {
		"class_name": {"type": "String", "default": "Health", "description": "Component class name"},
		"max_health": {"type": "int", "default": "100", "description": "Maximum health"},
		"invulnerable_time": {"type": "float", "default": "0.5", "description": "Invulnerability duration after hit"}
	}
	s.suggested_path_template = "res://scripts/components/{{class_name}}.gd"
	s.template = """extends Node
class_name {{class_name}}

signal health_changed(current: int, previous: int)
signal died()

@export var max_health: int = {{max_health}}
@export var invulnerable_time: float = {{invulnerable_time}}

var current_health: int
var is_invulnerable: bool = false

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	if is_invulnerable or amount <= 0:
		return
	var previous := current_health
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, previous)
	if current_health <= 0:
		died.emit()
	else:
		_start_invulnerability()

func heal(amount: int) -> void:
	if amount <= 0:
		return
	var previous := current_health
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, previous)

func _start_invulnerability() -> void:
	is_invulnerable = true
	await get_tree().create_timer(invulnerable_time).timeout
	is_invulnerable = false
"""
	return s

static func _inventory_system_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "inventory_system"
	s.description = "Slot-based inventory with add, remove, stack, and signal support"
	s.tags = ["component", "gameplay"]
	s.params = {
		"class_name": {"type": "String", "default": "Inventory", "description": "Inventory class name"},
		"max_slots": {"type": "int", "default": "20", "description": "Maximum inventory slots"}
	}
	s.suggested_path_template = "res://scripts/{{class_name}}.gd"
	s.template = """extends Node
class_name {{class_name}}

signal item_added(item: Dictionary, slot: int)
signal item_removed(slot: int)
signal inventory_changed()

@export var max_slots: int = {{max_slots}}

var slots: Array[Dictionary] = []

func _ready() -> void:
	slots.resize(max_slots)
	for i in range(max_slots):
		slots[i] = {"item": "", "quantity": 0}

func add_item(item_name: String, quantity: int = 1) -> bool:
	var remaining := quantity
	for i in range(max_slots):
		if slots[i].item == item_name:
			var space := 99 - slots[i].quantity
			var added := mini(remaining, space)
			slots[i].quantity += added
			remaining -= added
			if remaining <= 0:
				item_added.emit(slots[i], i)
				inventory_changed.emit()
				return true
	for i in range(max_slots):
		if slots[i].quantity == 0:
			slots[i].item = item_name
			slots[i].quantity = remaining
			item_added.emit(slots[i], i)
			inventory_changed.emit()
			return true
	return false

func remove_item(slot: int, quantity: int = 1) -> bool:
	if slot < 0 or slot >= max_slots or slots[slot].quantity <= 0:
		return false
	slots[slot].quantity -= quantity
	if slots[slot].quantity <= 0:
		slots[slot].item = ""
		slots[slot].quantity = 0
	item_removed.emit(slot)
	inventory_changed.emit()
	return true
"""
	return s

static func _save_load_json_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "save_load_json"
	s.description = "JSON-based save/load system with file dialogs"
	s.tags = ["system", "persistence"]
	s.params = {
		"class_name": {"type": "String", "default": "SaveManager", "description": "Save manager class name"},
		"save_dir": {"type": "String", "default": "user://saves", "description": "Save directory path"}
	}
	s.suggested_path_template = "res://autoloads/{{class_name}}.gd"
	s.template = """extends Node
class_name {{class_name}}

const SAVE_DIR: String = "{{save_dir}}"

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save_game(data: Dictionary, slot: String = "save_1") -> bool:
	var path := SAVE_DIR.path_join(slot + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true

func load_game(slot: String = "save_1") -> Dictionary:
	var path := SAVE_DIR.path_join(slot + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err == OK and json.data is Dictionary:
		return json.data
	return {}

func get_save_list() -> Array[String]:
	var saves: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return saves
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			saves.append(f.trim_suffix(".json"))
		f = dir.get_next()
	return saves

func delete_save(slot: String) -> bool:
	var path := SAVE_DIR.path_join(slot + ".json")
	if not FileAccess.file_exists(path):
		return false
	DirAccess.remove_absolute(path)
	return true
"""
	return s

static func _singleton_autoload_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "singleton_autoload"
	s.description = "Global manager singleton template with signal bus pattern"
	s.tags = ["pattern", "architecture"]
	s.params = {
		"class_name": {"type": "String", "default": "GameManager", "description": "Singleton class name"}
	}
	s.suggested_path_template = "res://autoloads/{{class_name}}.gd"
	s.template = """extends Node
class_name {{class_name}}

## Global singleton — add to Project Settings > Autoload

signal game_paused(is_paused: bool)
signal game_over()
signal score_changed(new_score: int)

var score: int = 0
var is_paused: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	game_paused.emit(is_paused)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func reset_game() -> void:
	score = 0
	get_tree().reload_current_scene()
"""
	return s

static func _ui_screen_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "ui_screen"
	s.description = "Animated UI screen with show/hide, transitions, and input handling"
	s.tags = ["ui", "screen"]
	s.params = {
		"class_name": {"type": "String", "default": "UIScreen", "description": "Screen class name"},
		"transition_time": {"type": "float", "default": "0.3", "description": "Transition duration"}
	}
	s.suggested_path_template = "res://scripts/ui/{{class_name}}.gd"
	s.template = """extends Control
class_name {{class_name}}

signal screen_shown()
signal screen_hidden()

@export var transition_time: float = {{transition_time}}

var _tween: Tween

func show_screen() -> void:
	visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.WHITE, transition_time).from(Color.TRANSPARENT)
	_tween.tween_callback(func(): screen_shown.emit())

func hide_screen() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.TRANSPARENT, transition_time)
	_tween.tween_callback(func():
		visible = false
		screen_hidden.emit()
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide_screen()
"""
	return s

static func _camera_follow_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "camera_follow"
	s.description = "Smooth Camera2D that follows a target with dead zone and limits"
	s.tags = ["2d", "camera"]
	s.params = {
		"class_name": {"type": "String", "default": "FollowCamera", "description": "Camera class name"},
		"follow_speed": {"type": "float", "default": "5.0", "description": "Smoothing speed"},
		"dead_zone": {"type": "float", "default": "20.0", "description": "Dead zone radius"},
		"target_path": {"type": "String", "default": "../Player", "description": "Node path to target"}
	}
	s.suggested_path_template = "res://scripts/{{class_name}}.gd"
	s.template = """extends Camera2D
class_name {{class_name}}

@export var follow_speed: float = {{follow_speed}}
@export var dead_zone: float = {{dead_zone}}
@export var target_path: NodePath = NodePath("{{target_path}}")

var target: Node2D

func _ready() -> void:
	target = get_node(target_path)

func _process(delta: float) -> void:
	if not target:
		return
	var diff := target.global_position - global_position
	if diff.length() > dead_zone:
		global_position += diff * min(1.0, follow_speed * delta)
"""
	return s

static func _object_pool_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "object_pool"
	s.description = "Generic object pool for performance (bullets, particles, enemies)"
	s.tags = ["performance", "pattern"]
	s.params = {
		"class_name": {"type": "String", "default": "ObjectPool", "description": "Pool class name"},
		"pool_size": {"type": "int", "default": "20", "description": "Number of objects to pre-allocate"},
		"scene_path": {"type": "String", "default": "", "description": "Path to the scene to instance"}
	}
	s.suggested_path_template = "res://scripts/{{class_name}}.gd"
	s.template = """extends Node
class_name {{class_name}}

@export var pool_size: int = {{pool_size}}
@export var scene_path: String = "{{scene_path}}"

var _pool: Array[Node] = []

func _ready() -> void:
	if scene_path.is_empty():
		return
	var scene := load(scene_path)
	for i in range(pool_size):
		var instance := scene.instantiate()
		instance.visible = false
		instance.set_meta("pooled", true)
		_pool.append(instance)
		add_child(instance)

func get_object() -> Node:
	for obj in _pool:
		if not obj.visible:
			obj.visible = true
			return obj
	var scene := load(scene_path)
	if scene:
		var instance := scene.instantiate()
		_pool.append(instance)
		add_child(instance)
		return instance
	return null

func return_object(obj: Node) -> void:
	obj.visible = false
	obj.set_meta("pooled", true)
"""
	return s

static func _event_bus_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "event_bus"
	s.description = "Global signal-based event bus for decoupled communication"
	s.tags = ["pattern", "architecture"]
	s.params = {
		"class_name": {"type": "String", "default": "EventBus", "description": "Event bus class name"}
	}
	s.suggested_path_template = "res://autoloads/{{class_name}}.gd"
	s.template = """extends Node
class_name {{class_name}}

## Global event bus — add to Project Settings > Autoload.
## Usage: EventBus.player_damaged.connect(_on_player_damaged)

signal player_damaged(amount: int)
signal enemy_killed(enemy: Node)
signal item_collected(item_name: String)
signal scene_changed(scene_path: String)
signal dialogue_started(dialogue_id: String)
signal dialogue_ended()
signal game_state_changed(state: String)
"""
	return s

static func _dialogue_system_skill() -> SkillDefinition:
	var s := SkillDef.new()
	s.name = "dialogue_system"
	s.description = "Branching dialogue system with JSON data and typewriter effect"
	s.tags = ["ui", "gameplay"]
	s.params = {
		"class_name": {"type": "String", "default": "DialogueSystem", "description": "Dialogue class name"},
		"data_path": {"type": "String", "default": "res://data/dialogue.json", "description": "Dialogue data file path"}
	}
	s.suggested_path_template = "res://scripts/ui/{{class_name}}.gd"
	s.template = """extends Control
class_name {{class_name}}

signal dialogue_started(dialogue_id: String)
signal dialogue_ended()

@export var data_path: String = "{{data_path}}"
@export var text_speed: float = 0.03

@onready var label: Label = $Label
@onready var name_label: Label = $NameLabel

var _data: Dictionary = {}
var _current_id: String = ""
var _current_node: Dictionary = {}
var _is_typing: bool = false

func _ready() -> void:
	visible = false
	_data = _load_dialogue_data()

func start_dialogue(dialogue_id: String) -> void:
	if not _data.has(dialogue_id):
		return
	_current_id = dialogue_id
	_current_node = _data[dialogue_id]
	visible = true
	dialogue_started.emit(dialogue_id)
	_show_current()

func _show_current() -> void:
	if _current_node.is_empty():
		return
	name_label.text = _current_node.get("speaker", "")
	_is_typing = true
	label.text = ""
	var text: String = _current_node.get("text", "")
	var tween := create_tween()
	for i in range(text.length() + 1):
		var idx := i
		tween.tween_interval(text_speed)
		tween.tween_callback(func():
			label.text = text.left(idx)
			if idx == text.length():
				_is_typing = false
		)

func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_accept"):
		return
	if _is_typing:
		_is_typing = false
		label.text = _current_node.get("text", "")
		return
	var next_id: String = _current_node.get("next", "")
	if next_id.is_empty():
		visible = false
		dialogue_ended.emit()
	elif _data.has(next_id):
		_current_node = _data[next_id]
		_show_current()

func _load_dialogue_data() -> Dictionary:
	if not FileAccess.file_exists(data_path):
		return {}
	var file := FileAccess.open(data_path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		return json.data
	return {}
"""
	return s
