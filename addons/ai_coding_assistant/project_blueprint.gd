@tool
extends RefCounted
class_name AIProjectBlueprint

const BLUEPRINT_PATH = "res://.ai_blueprint.md"

static func get_blueprint() -> String:
	if not FileAccess.file_exists(BLUEPRINT_PATH):
		return _create_default_blueprint()
	
	var file = FileAccess.open(BLUEPRINT_PATH, FileAccess.READ)
	return file.get_as_text() if file else ""

static func update_blueprint(content: String):
	var file = FileAccess.open(BLUEPRINT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(content)

static func _create_default_blueprint() -> String:
	var default = """# Project Blueprint

## Architecture
- [Describe the core architecture here]

## Naming Conventions
- Variables: snake_case
- Classes: PascalCase
- Files: snake_case

## Important Files
- [List critical files here]

## Current Goals
- [AI tracks current tasks here]
"""
	update_blueprint(default)
	return default
