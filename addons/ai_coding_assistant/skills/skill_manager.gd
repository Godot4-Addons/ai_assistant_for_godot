@tool
extends RefCounted
class_name AISkillManager

const SKILLS_SAVE_DIR = "user://ai_skills/"
const BuiltinLibrary = preload("res://addons/ai_coding_assistant/skills/skill_library.gd")

var _skills: Dictionary = {}

func _init() -> void:
	_load_builtin_skills()
	_load_user_skills()

func _load_builtin_skills() -> void:
	for skill in BuiltinLibrary.get_all_skills():
		_skills[skill.name] = skill

func _load_user_skills() -> void:
	if not DirAccess.dir_exists_absolute(SKILLS_SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SKILLS_SAVE_DIR)
		return
	var dir := DirAccess.open(SKILLS_SAVE_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			var skill := _load_skill_from_file(SKILLS_SAVE_DIR + f)
			if skill:
				_skills[skill.name] = skill
		f = dir.get_next()

## Execute a skill and return the generated code
func execute_skill(name: String, params: Dictionary) -> Dictionary:
	if not _skills.has(name):
		return {"error": "Skill '%s' not found. Available: %s" % [name, get_skill_names()]}

	var skill: SkillDefinition = _skills[name]
	var code := skill.generate(params)

	return {
		"skill": name,
		"code": code,
		"suggested_path": skill.get_suggested_path(params),
		"description": skill.description
	}

## Save a file as a user skill
func save_skill_from_file(skill_name: String, file_path: String, description: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	var content := file.get_as_text()

	var skill_data := {
		"name": skill_name,
		"description": description,
		"source_file": file_path,
		"template": content,
		"params": [],
		"created_at": Time.get_datetime_string_from_system()
	}

	if not DirAccess.dir_exists_absolute(SKILLS_SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SKILLS_SAVE_DIR)

	var save_path := SKILLS_SAVE_DIR + skill_name + ".json"
	var save_file := FileAccess.open(save_path, FileAccess.WRITE)
	if not save_file:
		return false
	save_file.store_string(JSON.stringify(skill_data, "\t"))

	# Also load into memory
	var sd := SkillDefinition.new()
	sd.name = skill_name
	sd.description = description
	sd.template = content
	_skills[skill_name] = sd

	return true

func get_skill_names() -> Array[String]:
	var names: Array[String] = []
	for key in _skills:
		names.append(key)
	return names

func get_skill_list_for_prompt() -> String:
	var lines: Array[String] = [
		"## AVAILABLE SKILLS",
		"Use `<use_skill name=\"...\" params='{\"key\": \"value\"}' />` to instantiate.",
		""
	]
	for name in _skills:
		var skill: SkillDefinition = _skills[name]
		lines.append("- **%s**: %s" % [name, skill.description])
		if not skill.params.is_empty():
			var param_names: Array[String] = []
			for p in skill.params:
				param_names.append(p)
			lines.append("  Params: %s" % ", ".join(param_names))
		if not skill.tags.is_empty():
			lines.append("  Tags: %s" % ", ".join(skill.tags))
	return "\n".join(lines)

func has_skill(name: String) -> bool:
	return _skills.has(name)

func reload_skills() -> void:
	_skills.clear()
	_load_builtin_skills()
	_load_user_skills()

func _load_skill_from_file(path: String) -> SkillDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	var data = json.data
	if not data is Dictionary:
		return null

	var sd := SkillDefinition.new()
	sd.name = data.get("name", "")
	sd.description = data.get("description", "")
	sd.template = data.get("template", "")
	return sd
