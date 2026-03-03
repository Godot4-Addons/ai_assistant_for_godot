@tool
extends RefCounted

# Code templates for quick generation - Refactored for modularity

const Movement = preload("res://addons/ai_coding_assistant/templates/movement_templates.gd")
const System = preload("res://addons/ai_coding_assistant/templates/system_templates.gd")
const Manager = preload("res://addons/ai_coding_assistant/templates/manager_templates.gd")
const UI = preload("res://addons/ai_coding_assistant/templates/ui_templates.gd")

static func get_template(template_name: String) -> String:
	match template_name:
		"player_movement":
			return Movement.get_player_movement_template()
		"singleton":
			return UI.get_singleton_template()
		"ui_controller":
			return UI.get_ui_controller_template()
		"state_machine":
			return System.get_state_machine_template()
		"inventory_system":
			return System.get_inventory_system_template()
		"save_system":
			return Manager.get_save_system_template()
		"audio_manager":
			return Manager.get_audio_manager_template()
		"scene_manager":
			return Manager.get_scene_manager_template()
		"input_handler":
			return Manager.get_input_handler_template()
		"health_system":
			return System.get_health_system_template()
		_:
			return ""

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
