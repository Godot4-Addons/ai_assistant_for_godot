@tool
extends RefCounted
class_name AIFileOrganizer

var _editor_integration

func _init(editor_integration) -> void:
	_editor_integration = editor_integration

## Suggest the correct path for a new file based on type and name
func suggest_path(file_type: String, class_name: String, context: String = "") -> String:
	var base_name := class_name.to_snake_case()
	match file_type:
		"script":
			if "player" in base_name or "enemy" in base_name or "npc" in base_name:
				return "res://scripts/characters/%s.gd" % base_name
			elif "ui" in base_name or "hud" in base_name or "menu" in base_name:
				return "res://scripts/ui/%s.gd" % base_name
			elif "manager" in base_name or "system" in base_name:
				return "res://autoloads/%s.gd" % base_name
			else:
				return "res://scripts/%s.gd" % base_name
		"scene":
			if "player" in base_name or "enemy" in base_name:
				return "res://scenes/characters/%s.tscn" % base_name
			elif "level" in base_name or "map" in base_name or "world" in base_name:
				return "res://scenes/levels/%s.tscn" % base_name
			elif "ui" in base_name or "menu" in base_name:
				return "res://scenes/ui/%s.tscn" % base_name
			else:
				return "res://scenes/%s.tscn" % base_name
		"resource":
			return "res://resources/%s.tres" % base_name
		"autoload":
			return "res://autoloads/%s.gd" % base_name
		_:
			return "res://%s" % base_name

## Detect files in wrong locations
func detect_misplaced_files() -> Array[Dictionary]:
	var misplaced: Array[Dictionary] = []
	var all_scripts := _list_by_extension("res://", "gd")
	for script_path in all_scripts:
		if script_path.get_base_dir() == "res://" and script_path.get_file() not in ["example_script.gd", "install.gd"]:
			misplaced.append({
				"file": script_path,
				"issue": "Script at project root",
				"suggestion": suggest_path("script", script_path.get_basename())
			})

	var all_scenes := _list_by_extension("res://", "tscn")
	for scene_path in all_scenes:
		if scene_path.get_base_dir() == "res://":
			misplaced.append({
				"file": scene_path,
				"issue": "Scene at project root",
				"suggestion": suggest_path("scene", scene_path.get_basename())
			})
	return misplaced

## Ensure all standard project directories exist
func ensure_standard_dirs() -> Array[String]:
	var created: Array[String] = []
	var dirs := [
		"res://scripts/",
		"res://scripts/characters/",
		"res://scripts/ui/",
		"res://scripts/systems/",
		"res://scripts/components/",
		"res://scenes/",
		"res://scenes/characters/",
		"res://scenes/levels/",
		"res://scenes/ui/",
		"res://assets/",
		"res://assets/audio/",
		"res://assets/audio/music/",
		"res://assets/audio/sfx/",
		"res://assets/images/",
		"res://assets/fonts/",
		"res://resources/",
		"res://autoloads/",
		"res://shaders/",
	]
	for d in dirs:
		if not DirAccess.dir_exists_absolute(d):
			DirAccess.make_dir_recursive_absolute(d)
			created.append(d)
	return created

func _list_by_extension(path: String, ext: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(path)
	if not dir:
		return results
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not f.begins_with("."):
			var full := path.path_join(f)
			if dir.current_is_dir():
				results.append_array(_list_by_extension(full, ext))
			elif f.get_extension() == ext:
				results.append(full)
		f = dir.get_next()
	return results
