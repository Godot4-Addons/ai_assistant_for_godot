@tool
extends RefCounted
class_name AICodeParser

static func parse_script(text: String, cursor_line: int) -> Dictionary:
	var context = {
		"class_name": "",
		"extends": "",
		"current_function": "",
		"variables": [],
		"functions": [],
		"imports": [],
		"signals": []
	}
	
	var lines = text.split("\n")
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"): continue

		if line.begins_with("class_name "):
			context.class_name = line.substr(11).strip_edges()
		elif line.begins_with("extends "):
			context.extends = line.substr(8).strip_edges()
		elif line.begins_with("const ") and "preload(" in line:
			context.imports.append(line)
		elif line.begins_with("func "):
			var name = _extract_name(line, 5)
			context.functions.append(name)
			if i <= cursor_line: context.current_function = name
		elif line.begins_with("var ") or line.begins_with("const "):
			var info = _extract_var_info(line)
			if info: context.variables.append(info)
		elif line.begins_with("signal "):
			context.signals.append(line.substr(7).split("(")[0].strip_edges())
			
	return context

static func _extract_name(line: String, skip: int) -> String:
	return line.substr(skip).strip_edges().split("(")[0].strip_edges()

static func _extract_var_info(line: String) -> Dictionary:
	var is_const = line.begins_with("const ")
	var part = line.substr(6 if is_const else 4).strip_edges()
	var name = part.split(":")[0].split("=")[0].strip_edges()
	return {"name": name, "is_const": is_const}
