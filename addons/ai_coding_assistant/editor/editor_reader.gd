@tool
extends RefCounted
class_name AIEditorReader

var editor_interface: EditorInterface
var script_editor: ScriptEditor

func _init(interface: EditorInterface):
	editor_interface = interface
	if editor_interface:
		script_editor = editor_interface.get_script_editor()

func get_current_script_editor() -> ScriptEditorBase:
	if not script_editor: return null
	return script_editor.get_current_editor()

func get_current_code_edit() -> CodeEdit:
	var editor = get_current_script_editor()
	if not editor: return null
	return editor.get_base_editor()

func get_current_file_path() -> String:
	var editor = get_current_script_editor()
	if not editor: return ""
	var script = editor.get_edited_resource()
	return script.resource_path if script else ""

func get_all_text() -> String:
	var editor = get_current_code_edit()
	return editor.text if editor else ""

func get_selected_text() -> String:
	var editor = get_current_code_edit()
	return editor.get_selected_text() if editor else ""

func get_current_line() -> String:
	var editor = get_current_code_edit()
	if not editor: return ""
	return editor.get_line(editor.get_caret_line())

func get_lines_around_cursor(before: int = 5, after: int = 5) -> String:
	var editor = get_current_code_edit()
	if not editor: return ""
	var line = editor.get_caret_line()
	var start = max(0, line - before)
	var end = min(editor.get_line_count() - 1, line + after)
	var context = []
	for i in range(start, end + 1):
		context.append((">>> " if i == line else "    ") + editor.get_line(i))
	return "\n".join(context)

func find_function(func_name: String) -> Dictionary:
	var editor = get_current_code_edit()
	if not editor: return {}
	var lines = editor.get_line_count()
	for i in range(lines):
		var l = editor.get_line(i).strip_edges()
		if l.begins_with("func " + func_name + "("):
			var end = lines - 1
			for j in range(i + 1, lines):
				var nl = editor.get_line(j).strip_edges()
				if nl.begins_with("func ") or nl.begins_with("class "):
					end = j - 1
					break
			var content = []
			for k in range(i, end + 1): content.append(editor.get_line(k))
			return {"name": func_name, "start_line": i, "end_line": end, "text": "\n".join(content)}
	return {}

func get_function_at_cursor() -> Dictionary:
	var editor = get_current_code_edit()
	if not editor: return {}
	var cur = editor.get_caret_line()
	var start = -1
	var name = ""
	for i in range(cur, -1, -1):
		var l = editor.get_line(i).strip_edges()
		if l.begins_with("func "):
			start = i
			name = l.split("(")[0].split(" ")[1]
			break
	if start == -1: return {}
	var end = editor.get_line_count() - 1
	for i in range(start + 1, editor.get_line_count()):
		var l = editor.get_line(i).strip_edges()
		if l.begins_with("func ") or l.begins_with("class "):
			end = i - 1
			break
	var content = []
	for i in range(start, end + 1): content.append(editor.get_line(i))
	return {"name": name, "start_line": start, "end_line": end, "text": "\n".join(content)}

func get_class_info() -> Dictionary:
	var editor = get_current_code_edit()
	if not editor: return {}
	var info = {"name": "", "extends": "", "functions": [], "variables": []}
	for i in range(editor.get_line_count()):
		var l = editor.get_line(i).strip_edges()
		if l.begins_with("class_name "): info.name = l.split(" ")[1]
		elif l.begins_with("extends "): info.extends = l.split(" ")[1]
		elif l.begins_with("func "): info.functions.append(l.split("(")[0].split(" ")[1])
		elif l.begins_with("var ") or l.begins_with("@export var "):
			info.variables.append(l.split(":")[0].split(" ")[-1])
	return info

func list_files(dir_path: String = "res://") -> Array:
	var dir = DirAccess.open(dir_path)
	if not dir: return []
	
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			if dir.current_is_dir():
				files.append(file_name + "/")
			else:
				files.append(file_name)
		file_name = dir.get_next()
	return files

const TEXT_EXTENSIONS: Array[String] = [
	"gd", "tscn", "tres", "godot", "md", "txt", "json", "csv",
	"cfg", "ini", "import", "log", "gitignore", "gdshader"
]

func read_file(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	
	# Prevent Godot UTF-8 parsing errors on binary files
	var ext := path.get_extension().to_lower()
	if ext != "" and not TEXT_EXTENSIONS.has(ext):
		return "[Binary file omitted: %s]" % path
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return ""
	return file.get_as_text()

func search_files(pattern: String, dir_path: String = "res://") -> Array:
	var results = []
	var files = _get_all_files(dir_path)
	var regex = RegEx.new()
	var err = regex.compile(pattern)
	if err != OK: return [ {"error": "Invalid regex pattern"}]
	
	for path in files:
		var content = read_file(path)
		if content.is_empty(): continue
		
		var matches = regex.search_all(content)
		if matches.size() > 0:
			var file_results = {"path": path, "matches": []}
			# Sample up to 3 matches for brevity in prompt context
			for i in range(min(matches.size(), 3)):
				var m = matches[i]
				var line_num = content.substr(0, m.get_start()).count("\n") + 1
				var start = max(0, content.rfind("\n", m.get_start()))
				var end = content.find("\n", m.get_end())
				if end == -1: end = content.length()
				var line_text = content.substr(start, end - start).strip_edges()
				file_results.matches.append({"line": line_num, "text": line_text})
			results.append(file_results)
	return results

func _get_all_files(path: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):
				if dir.current_is_dir():
					files.append_array(_get_all_files(path.path_join(file_name)))
				else:
					files.append(path.path_join(file_name))
			file_name = dir.get_next()
	return files
