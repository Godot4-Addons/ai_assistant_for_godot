@tool
extends RefCounted

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
