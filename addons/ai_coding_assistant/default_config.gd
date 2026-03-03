@tool
extends RefCounted

const Defaults = preload("res://addons/ai_coding_assistant/config/config_defaults.gd")
const Actions = preload("res://addons/ai_coding_assistant/config/action_data.gd")

static func get_default_settings(): return Defaults.get_settings()
static func get_default_ui_state(): return Defaults.get_ui_state()
static func get_quick_actions(): return Actions.get_quick_actions()
static func get_code_snippets(): return Actions.get_code_snippets()

static func validate_config(config: Dictionary) -> Dictionary:
	var def = get_default_settings()
	var res = {}
	for k in def: res[k] = config.get(k, def[k])
	return res
