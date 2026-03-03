@tool
extends RefCounted

# Analyzes GDScript code for context and suggestions

static func analyze_current_context() -> Dictionary:
	var context = {
		"file_path": "",
		"class_name": "",
		"current_function": "",
		"variables": [],
		"functions": [],
		"imports": [],
		"line_number": 0,
		"cursor_position": 0
	}

	var script_editor = EditorInterface.get_script_editor()
	if not script_editor:
		return context

	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return context

	var text_editor = current_editor.get_base_editor()
	if not text_editor:
		return context

	var script = current_editor.get_edited_resource()
	if script:
		context["file_path"] = script.resource_path

	var text = text_editor.get_text()
	var cursor_line = text_editor.get_caret_line()
	var cursor_column = text_editor.get_caret_column()

	context["line_number"] = cursor_line
	context["cursor_position"] = cursor_column

	# Parse the script content
	var lines = text.split("\n")
	context = _parse_script_content(lines, context, cursor_line)

	return context

static func _parse_script_content(lines: PackedStringArray, context: Dictionary, cursor_line: int) -> Dictionary:
	var current_function = ""

	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		if line.is_empty() or line.begins_with("#"):
			continue

		# Check for class declaration
		if line.begins_with("class_name "):
			context["class_name"] = line.substr(11).strip_edges()
		elif line.begins_with("class "):
			var class_match = line.substr(6).split(" ")[0]
			context["class_name"] = class_match

		# Check for extends
		elif line.begins_with("extends "):
			context["extends"] = line.substr(8).strip_edges()

		# Check for imports/preloads
		elif line.begins_with("const ") and "preload(" in line:
			context["imports"].append(line)

		# Check for function declarations
		elif line.begins_with("func "):
			var func_name = _extract_function_name(line)
			context["functions"].append(func_name)

			# Check if cursor is in this function
			if i <= cursor_line:
				current_function = func_name

		# Check for variable declarations
		elif line.begins_with("var ") or line.begins_with("const "):
			var var_info = _extract_variable_info(line)
			if var_info:
				context["variables"].append(var_info)

		# Check for signals
		elif line.begins_with("signal "):
			var signal_name = line.substr(7).split("(")[0].strip_edges()
			context["signals"] = context.get("signals", [])
			context["signals"].append(signal_name)

	context["current_function"] = current_function
	return context

static func _extract_function_name(line: String) -> String:
	var func_part = line.substr(5).strip_edges()
	var paren_pos = func_part.find("(")
	if paren_pos > 0:
		return func_part.substr(0, paren_pos)
	return func_part

static func _extract_variable_info(line: String) -> Dictionary:
	var info = {}
	var is_const = line.begins_with("const ")
	var start_pos = 6 if is_const else 4

	var var_part = line.substr(start_pos).strip_edges()
	var colon_pos = var_part.find(":")
	var equals_pos = var_part.find("=")

	var name_end = var_part.length()
	if colon_pos > 0:
		name_end = colon_pos
	elif equals_pos > 0:
		name_end = equals_pos

	info["name"] = var_part.substr(0, name_end).strip_edges()
	info["is_const"] = is_const

	# Extract type if present
	if colon_pos > 0:
		var type_start = colon_pos + 1
		var type_end = equals_pos if equals_pos > colon_pos else var_part.length()
		info["type"] = var_part.substr(type_start, type_end - type_start).strip_edges()

	return info

static func get_completion_context(text: String, cursor_pos: int) -> Dictionary:
	var context = {
		"word_before_cursor": "",
		"line_before_cursor": "",
		"is_after_dot": false,
		"is_in_function_call": false,
		"object_name": ""
	}

	if cursor_pos <= 0:
		return context

	var lines = text.substr(0, cursor_pos).split("\n")
	if lines.is_empty():
		return context

	var current_line = lines[-1]
	context["line_before_cursor"] = current_line

	# Find the word before cursor
	var word_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
	var word_start = current_line.length()

	for i in range(current_line.length() - 1, -1, -1):
		if current_line[i] in word_chars:
			word_start = i
		else:
			break

	if word_start < current_line.length():
		context["word_before_cursor"] = current_line.substr(word_start)

	# Check if we're after a dot (method/property access)
	var before_word = current_line.substr(0, word_start).strip_edges()
	if before_word.ends_with("."):
		context["is_after_dot"] = true
		# Find the object name before the dot
		var obj_end = before_word.length() - 1
		var obj_start = obj_end
		for i in range(obj_end - 1, -1, -1):
			if before_word[i] in word_chars:
				obj_start = i
			else:
				break
		if obj_start < obj_end:
			context["object_name"] = before_word.substr(obj_start, obj_end - obj_start)

	# Check if we're in a function call
	var paren_count = 0
	for i in range(current_line.length() - 1, -1, -1):
		if current_line[i] == ")":
			paren_count += 1
		elif current_line[i] == "(":
			paren_count -= 1
			if paren_count < 0:
				context["is_in_function_call"] = true
				break

	return context

static func suggest_completion(context: Dictionary, code_context: Dictionary) -> Array:
	var suggestions = []

	if context["is_after_dot"]:
		# Suggest methods/properties for the object
		var obj_name = context["object_name"]
		suggestions = _get_object_suggestions(obj_name, code_context)
	elif context["word_before_cursor"].is_empty():
		# Suggest keywords, variables, functions
		suggestions.append_array(_get_keyword_suggestions())
		suggestions.append_array(_get_variable_suggestions(code_context))
		suggestions.append_array(_get_function_suggestions(code_context))
	else:
		# Filter suggestions based on partial word
		var partial = context["word_before_cursor"].to_lower()
		var all_suggestions = []
		all_suggestions.append_array(_get_keyword_suggestions())
		all_suggestions.append_array(_get_variable_suggestions(code_context))
		all_suggestions.append_array(_get_function_suggestions(code_context))

		for suggestion in all_suggestions:
			if suggestion.to_lower().begins_with(partial):
				suggestions.append(suggestion)

	return suggestions

static func _get_keyword_suggestions() -> Array:
	return [
		"func", "var", "const", "class", "extends", "signal", "enum",
		"if", "elif", "else", "for", "while", "match", "when",
		"return", "break", "continue", "pass",
		"true", "false", "null", "self", "super",
		"and", "or", "not", "in", "is", "as",
		"export", "@export", "@onready", "@tool"
	]

static func _get_variable_suggestions(code_context: Dictionary) -> Array:
	var suggestions = []
	if "variables" in code_context:
		for var_info in code_context["variables"]:
			suggestions.append(var_info["name"])
	return suggestions

static func _get_function_suggestions(code_context: Dictionary) -> Array:
	var suggestions = []
	if "functions" in code_context:
		suggestions.append_array(code_context["functions"])
	return suggestions

static func _get_object_suggestions(obj_name: String, code_context: Dictionary) -> Array:
	# This would need to be expanded with actual Godot API knowledge
	# For now, return common suggestions
	var common_suggestions = [
		"position", "rotation", "scale", "visible", "modulate",
		"get_child", "get_children", "add_child", "remove_child",
		"connect", "disconnect", "emit_signal", "has_signal",
		"set", "get", "call", "call_deferred"
	]

	return common_suggestions
