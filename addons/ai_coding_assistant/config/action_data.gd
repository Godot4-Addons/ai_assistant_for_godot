@tool
extends RefCounted
class_name AIActionData

static func get_quick_actions() -> Array[Dictionary]:
	return [
		{"name": "Player Movement", "prompt": "Create a 2D player movement script", "icon": "🏃"},
		{"name": "UI Controller", "prompt": "Create a UI controller script", "icon": "🖥️"},
		{"name": "Save System", "prompt": "Create a save system using JSON", "icon": "💾"},
		{"name": "Audio Manager", "prompt": "Create an audio manager", "icon": "🔊"}
	]

static func get_code_snippets() -> Dictionary:
	return {
		"signal": "signal signal_name(param)",
		"export": "@export var name: Type",
		"func": "func name(param):"
	}
