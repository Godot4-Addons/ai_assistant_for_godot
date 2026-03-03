@tool
extends RefCounted
class_name AIConfigDefaults

static func get_settings() -> Dictionary:
	return {
		"api_key": "",
		"provider": "gemini",
		"temperature": 0.7,
		"max_tokens": 2048,
		"auto_suggest": false,
		"save_history": true
	}

static func get_ui_state() -> Dictionary:
	return {
		"settings_collapsed": false,
		"quick_actions_collapsed": false,
		"splitter_offset": 200
	}
