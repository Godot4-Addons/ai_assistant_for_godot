@tool
extends RefCounted
class_name AIAgentContext

## Smart project context builder for the agent.
## Gives the AI full awareness of the Godot project structure.

const MAX_FILE_TREE_DEPTH: int = 4
const MAX_FILES_PER_DIR: int = 50
const SKIP_DIRS: Array = [".godot", ".git", ".import", "addons"]

var editor_interface: EditorInterface

# Caching for low-resource environments
var _cache: Dictionary = {}

func _init(ei: EditorInterface = null) -> void:
	editor_interface = ei

func clear_cache() -> void:
	_cache.clear()

# ─────────────────────────────────────────────────────────────────────────────
# Full Project Context
# ─────────────────────────────────────────────────────────────────────────────

## Build a complete structured project context string for the AI system prompt
func build_project_context() -> String:
	if _cache.has("project_context"):
		return _cache["project_context"]
		
	var parts: Array[String] = ["## PROJECT CONTEXT"]
	parts.append(_get_project_info())
	parts.append(_get_file_tree("res://", 0))
	if editor_interface:
		parts.append(_get_open_files())
		
	var result := "\n\n".join(parts)
	_cache["project_context"] = result
	return result

## Build a lightweight context (just structure, no file contents)
func build_quick_context() -> String:
	if _cache.has("quick_context"):
		return _cache["quick_context"]
		
	var parts: Array[String] = ["## PROJECT OVERVIEW"]
	parts.append(_get_project_info())
	parts.append(_get_scene_list())
	parts.append(_get_script_list())
	
	var result := "\n\n".join(parts)
	_cache["quick_context"] = result
	return result

# ─────────────────────────────────────────────────────────────────────────────
# Project Info
# ─────────────────────────────────────────────────────────────────────────────

func _get_project_info() -> String:
	var info: Array[String] = ["### Project Info"]
	info.append("- Name: " + ProjectSettings.get_setting("application/config/name", "Unnamed"))
	info.append("- Version: " + str(ProjectSettings.get_setting("application/config/version", "")))

	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if not main_scene.is_empty():
		info.append("- Main Scene: " + main_scene)

	# Physics
	var phys_2d: bool = ProjectSettings.has_setting("physics/2d/default_gravity")
	var phys_3d: bool = ProjectSettings.has_setting("physics/3d/default_gravity")
	if phys_2d or phys_3d:
		info.append("- Physics: " + ("2D" if phys_2d else "") + (" + 3D" if phys_3d else ""))

	# Autoloads
	var autoloads := _get_autoloads()
	if not autoloads.is_empty():
		info.append("- Autoloads: " + ", ".join(autoloads))

	# Input actions (sampled)
	var actions := _get_input_actions()
	if not actions.is_empty():
		info.append("- Input Actions: " + ", ".join(actions.slice(0, 10)))

	return "\n".join(info)

func _get_autoloads() -> Array[String]:
	var autoloads: Array[String] = []
	for key in ProjectSettings.get_property_list():
		var pname: String = key.get("name", "")
		if pname.begins_with("autoload/"):
			var node_name := pname.split("/")[-1]
			autoloads.append(node_name)
	return autoloads

func _get_input_actions() -> Array[String]:
	var actions: Array[String] = []
	for key in ProjectSettings.get_property_list():
		var pname: String = key.get("name", "")
		if pname.begins_with("input/"):
			actions.append(pname.split("/")[-1])
	return actions

# ─────────────────────────────────────────────────────────────────────────────
# File Tree
# ─────────────────────────────────────────────────────────────────────────────

func get_file_tree(depth: int = MAX_FILE_TREE_DEPTH) -> String:
	return _get_file_tree("res://", 0, depth)

func _get_file_tree(path: String, depth: int, max_depth: int = MAX_FILE_TREE_DEPTH) -> String:
	if depth > max_depth:
		return ""

	var dir := DirAccess.open(path)
	if not dir:
		return ""

	var lines: Array[String] = []
	if depth == 0:
		lines.append("### File Tree")

	var indent := "  ".repeat(depth)
	dir.list_dir_begin()
	var entries: Array[String] = []
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			entries.append(name)
		name = dir.get_next()
	entries.sort()

	var count := 0
	for entry in entries:
		if count >= MAX_FILES_PER_DIR:
			lines.append(indent + "  ... (%d more)" % (entries.size() - count))
			break
		var full_path := path.path_join(entry)
		if dir.current_is_dir():
			# Re-check
			var sub_dir := DirAccess.open(full_path)
			if sub_dir:
				if entry in SKIP_DIRS and depth == 0:
					lines.append(indent + "📁 " + entry + "/ [skipped]")
				else:
					lines.append(indent + "📁 " + entry + "/")
					lines.append(_get_file_tree(full_path, depth + 1, max_depth))
			count += 1
		else:
			var ext := entry.get_extension()
			var icon := _get_file_icon(ext)
			lines.append(indent + icon + " " + entry)
			count += 1

	return "\n".join(lines)

func _get_file_icon(ext: String) -> String:
	match ext:
		"gd": return "📜"
		"tscn": return "🎬"
		"tres": return "📦"
		"gdshader": return "✨"
		"png", "jpg", "svg": return "🖼️"
		"ogg", "mp3", "wav": return "🔊"
		"glb", "gltf", "obj": return "🗿"
		_: return "📄"

# ─────────────────────────────────────────────────────────────────────────────
# Scene & Script Listings
# ─────────────────────────────────────────────────────────────────────────────

func _get_scene_list() -> String:
	var scenes := _find_files_by_ext("res://", "tscn")
	if scenes.is_empty():
		return ""
	var lines: Array[String] = ["### Scenes"]
	for s in scenes.slice(0, 20):
		lines.append("- " + s)
	return "\n".join(lines)

func _get_script_list() -> String:
	var scripts := _find_files_by_ext("res://", "gd")
	if scripts.is_empty():
		return ""
	var lines: Array[String] = ["### Scripts"]
	for s in scripts.slice(0, 30):
		lines.append("- " + s)
	return "\n".join(lines)

func get_scene_summary(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Scene not found: " + path
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return "Cannot read scene: " + path
	var content := file.get_as_text()
	# Extract node info from .tscn format
	var lines: Array[String] = ["### Scene: " + path.get_file()]
	var regex := RegEx.new()
	regex.compile("\\[node name=\"([^\"]+)\" type=\"([^\"]+)\"")
	var matches := regex.search_all(content)
	for m in matches.slice(0, 20):
		lines.append("- Node: %s (%s)" % [m.get_string(1), m.get_string(2)])
	return "\n".join(lines)

# ─────────────────────────────────────────────────────────────────────────────
# Editor State
# ─────────────────────────────────────────────────────────────────────────────

func _get_open_files() -> String:
	if not editor_interface:
		return ""
	var se := editor_interface.get_script_editor()
	if not se:
		return ""
	var lines: Array[String] = ["### Open Files"]
	var editors := se.get_open_scripts()
	for script in editors:
		if script:
			lines.append("- " + script.resource_path)
	return "\n".join(lines)

func get_editor_state() -> Dictionary:
	if not editor_interface:
		return {}
	var se := editor_interface.get_script_editor()
	var current_path := ""
	if se:
		var cur := se.get_current_editor()
		if cur:
			var res: Resource = cur.get_edited_resource()
			if res:
				current_path = res.resource_path
	return {
		"current_script": current_path,
		"selected_scene": "",
	}

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _find_files_by_ext(path: String, ext: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(path)
	if not dir:
		return results
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := path.path_join(name)
			if dir.current_is_dir():
				if not name in SKIP_DIRS:
					results.append_array(_find_files_by_ext(full, ext))
			elif name.ends_with("." + ext):
				results.append(full)
		name = dir.get_next()
	return results

func list_files_in(dir_path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := dir_path.path_join(name)
			if dir.current_is_dir():
				result.append({"name": name, "type": "dir", "path": full})
			else:
				result.append({"name": name, "type": "file", "path": full,
					"size": FileAccess.get_file_as_bytes(full).size()})
		name = dir.get_next()
	return result
