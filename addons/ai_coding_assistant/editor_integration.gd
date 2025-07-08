@tool
extends RefCounted

# Editor integration for reading and writing code in Godot's Code Editor
# Provides seamless interaction with the script editor

signal code_inserted(text: String)
signal code_replaced(old_text: String, new_text: String)
signal selection_changed(selected_text: String)
signal file_opened(file_path: String)
signal file_saved(file_path: String)

# Editor references
var editor_interface: EditorInterface
var script_editor: ScriptEditor
var current_editor: ScriptEditorBase
var code_edit: CodeEdit

# State tracking
var last_cursor_position: Vector2i
var last_selection: String = ""
var current_file_path: String = ""
var auto_save_enabled: bool = true

func _init(editor_interface_instance: EditorInterface = null):
	"""Initialize editor integration"""
	if editor_interface_instance:
		editor_interface = editor_interface_instance
	else:
		# Try to get it from the engine (fallback)
		var main_loop = Engine.get_main_loop()
		if main_loop and main_loop.has_method("get_editor_interface"):
			editor_interface = main_loop.get_editor_interface()

	if editor_interface:
		script_editor = editor_interface.get_script_editor()
		print("Editor integration initialized")
	else:
		push_error("Failed to get EditorInterface - plugin may not be running in editor")

func get_current_script_editor() -> ScriptEditorBase:
	"""Get the currently active script editor"""
	if not script_editor:
		return null
	
	current_editor = script_editor.get_current_editor()
	return current_editor

func get_current_code_edit() -> CodeEdit:
	"""Get the current CodeEdit node"""
	var editor = get_current_script_editor()
	if not editor:
		return null
	
	code_edit = editor.get_base_editor()
	return code_edit

func get_current_file_path() -> String:
	"""Get the path of the currently open file"""
	var editor = get_current_script_editor()
	if not editor:
		return ""
	
	var script = editor.get_edited_resource()
	if script and script.resource_path:
		current_file_path = script.resource_path
		return current_file_path
	
	return ""

func get_all_text() -> String:
	"""Get all text from the current editor"""
	var editor = get_current_code_edit()
	if not editor:
		print("No active code editor found")
		return ""
	
	return editor.text

func get_selected_text() -> String:
	"""Get currently selected text"""
	var editor = get_current_code_edit()
	if not editor:
		return ""
	
	var selected = editor.get_selected_text()
	if selected != last_selection:
		last_selection = selected
		selection_changed.emit(selected)
	
	return selected

func get_current_line() -> String:
	"""Get the text of the current line"""
	var editor = get_current_code_edit()
	if not editor:
		return ""
	
	var cursor_line = editor.get_caret_line()
	return editor.get_line(cursor_line)

func get_lines_around_cursor(lines_before: int = 5, lines_after: int = 5) -> String:
	"""Get context lines around the cursor"""
	var editor = get_current_code_edit()
	if not editor:
		return ""
	
	var cursor_line = editor.get_caret_line()
	var total_lines = editor.get_line_count()
	
	var start_line = max(0, cursor_line - lines_before)
	var end_line = min(total_lines - 1, cursor_line + lines_after)
	
	var context_lines = []
	for i in range(start_line, end_line + 1):
		var prefix = ">>> " if i == cursor_line else "    "
		context_lines.append(prefix + editor.get_line(i))
	
	return "\n".join(context_lines)

func get_function_at_cursor() -> Dictionary:
	"""Get information about the function at cursor position"""
	var editor = get_current_code_edit()
	if not editor:
		return {}
	
	var cursor_line = editor.get_caret_line()
	var total_lines = editor.get_line_count()
	
	# Search backwards for function definition
	var func_start = -1
	var func_name = ""
	for i in range(cursor_line, -1, -1):
		var line = editor.get_line(i).strip_edges()
		if line.begins_with("func "):
			func_start = i
			# Extract function name
			var func_parts = line.split("(")[0].split(" ")
			if func_parts.size() >= 2:
				func_name = func_parts[1]
			break
	
	if func_start == -1:
		return {}
	
	# Search forwards for function end (next function or end of file)
	var func_end = total_lines - 1
	for i in range(func_start + 1, total_lines):
		var line = editor.get_line(i).strip_edges()
		if line.begins_with("func ") or line.begins_with("class "):
			func_end = i - 1
			break
	
	# Get function text
	var func_lines = []
	for i in range(func_start, func_end + 1):
		func_lines.append(editor.get_line(i))
	
	return {
		"name": func_name,
		"start_line": func_start,
		"end_line": func_end,
		"text": "\n".join(func_lines)
	}

func get_class_info() -> Dictionary:
	"""Get information about the current class"""
	var editor = get_current_code_edit()
	if not editor:
		return {}
	
	var class_name_found = ""
	var extends_class = ""
	var class_line = -1
	
	# Search for class declaration
	for i in range(editor.get_line_count()):
		var line = editor.get_line(i).strip_edges()
		if line.begins_with("class_name "):
			class_name_found = line.split(" ")[1]
			class_line = i
		elif line.begins_with("extends "):
			extends_class = line.split(" ")[1]
	
	# Get all function names
	var functions = []
	for i in range(editor.get_line_count()):
		var line = editor.get_line(i).strip_edges()
		if line.begins_with("func "):
			var func_parts = line.split("(")[0].split(" ")
			if func_parts.size() >= 2:
				functions.append(func_parts[1])
	
	# Get all variable declarations
	var variables = []
	for i in range(editor.get_line_count()):
		var line = editor.get_line(i).strip_edges()
		if line.begins_with("var ") or line.begins_with("@export var "):
			var var_parts = line.split(":")
			if var_parts.size() > 0:
				var var_name = var_parts[0].split(" ")[-1]
				variables.append(var_name)
	
	return {
		"class_name": class_name_found,
		"extends": extends_class,
		"file_path": get_current_file_path(),
		"functions": functions,
		"variables": variables,
		"line_count": editor.get_line_count()
	}

func insert_text_at_cursor(text: String) -> bool:
	"""Insert text at the current cursor position"""
	var editor = get_current_code_edit()
	if not editor:
		print("No active code editor found")
		return false
	
	editor.insert_text_at_caret(text)
	code_inserted.emit(text)
	
	if auto_save_enabled:
		save_current_file()
	
	print("Inserted text at cursor: ", text.substr(0, 50) + "...")
	return true

func replace_selected_text(new_text: String) -> bool:
	"""Replace the currently selected text"""
	var editor = get_current_code_edit()
	if not editor:
		print("No active code editor found")
		return false
	
	var old_text = editor.get_selected_text()
	if old_text.is_empty():
		print("No text selected")
		return false
	
	editor.insert_text_at_caret(new_text)
	code_replaced.emit(old_text, new_text)
	
	if auto_save_enabled:
		save_current_file()
	
	print("Replaced selected text: ", old_text.substr(0, 30) + "... -> " + new_text.substr(0, 30) + "...")
	return true

func replace_line(line_number: int, new_text: String) -> bool:
	"""Replace a specific line with new text"""
	var editor = get_current_code_edit()
	if not editor:
		return false
	
	if line_number < 0 or line_number >= editor.get_line_count():
		print("Invalid line number: ", line_number)
		return false
	
	var old_text = editor.get_line(line_number)
	
	# Select the entire line
	editor.set_caret_line(line_number)
	editor.set_caret_column(0)
	editor.select_all()
	editor.set_selection_mode(TextEdit.SELECTION_MODE_LINE)
	editor.select(line_number, 0, line_number + 1, 0)
	
	# Replace with new text
	editor.insert_text_at_caret(new_text + "\n")
	code_replaced.emit(old_text, new_text)
	
	if auto_save_enabled:
		save_current_file()
	
	return true

func replace_function(func_name: String, new_function_text: String) -> bool:
	"""Replace an entire function with new code"""
	var func_info = find_function(func_name)
	if func_info.is_empty():
		print("Function not found: ", func_name)
		return false
	
	var editor = get_current_code_edit()
	if not editor:
		return false
	
	# Select the entire function
	editor.select(func_info["start_line"], 0, func_info["end_line"] + 1, 0)
	
	# Replace with new function
	editor.insert_text_at_caret(new_function_text)
	code_replaced.emit(func_info["text"], new_function_text)
	
	if auto_save_enabled:
		save_current_file()
	
	print("Replaced function: ", func_name)
	return true

func find_function(func_name: String) -> Dictionary:
	"""Find a function by name and return its info"""
	var editor = get_current_code_edit()
	if not editor:
		return {}
	
	var total_lines = editor.get_line_count()
	
	for i in range(total_lines):
		var line = editor.get_line(i).strip_edges()
		if line.begins_with("func " + func_name + "("):
			# Found function start, now find end
			var func_end = total_lines - 1
			for j in range(i + 1, total_lines):
				var next_line = editor.get_line(j).strip_edges()
				if next_line.begins_with("func ") or next_line.begins_with("class "):
					func_end = j - 1
					break
			
			# Get function text
			var func_lines = []
			for k in range(i, func_end + 1):
				func_lines.append(editor.get_line(k))
			
			return {
				"name": func_name,
				"start_line": i,
				"end_line": func_end,
				"text": "\n".join(func_lines)
			}
	
	return {}

func append_to_file(text: String) -> bool:
	"""Append text to the end of the current file"""
	var editor = get_current_code_edit()
	if not editor:
		return false
	
	# Move cursor to end of file
	var last_line = editor.get_line_count() - 1
	editor.set_caret_line(last_line)
	editor.set_caret_column(editor.get_line(last_line).length())
	
	# Add newline if needed
	if not editor.get_line(last_line).is_empty():
		text = "\n" + text
	
	editor.insert_text_at_caret(text)
	code_inserted.emit(text)
	
	if auto_save_enabled:
		save_current_file()
	
	return true

func save_current_file() -> bool:
	"""Save the currently open file"""
	if not editor_interface:
		return false
	
	var current_script = get_current_script_editor()
	if not current_script:
		return false
	
	# Save the file
	editor_interface.save_scene()
	file_saved.emit(get_current_file_path())
	
	return true

func set_auto_save(enabled: bool):
	"""Enable or disable auto-save after modifications"""
	auto_save_enabled = enabled
	print("Auto-save ", "enabled" if enabled else "disabled")

func get_cursor_position() -> Vector2i:
	"""Get current cursor position (line, column)"""
	var editor = get_current_code_edit()
	if not editor:
		return Vector2i(-1, -1)
	
	return Vector2i(editor.get_caret_line(), editor.get_caret_column())

func set_cursor_position(line: int, column: int = 0):
	"""Set cursor position"""
	var editor = get_current_code_edit()
	if not editor:
		return
	
	editor.set_caret_line(line)
	editor.set_caret_column(column)

func select_lines(start_line: int, end_line: int):
	"""Select a range of lines"""
	var editor = get_current_code_edit()
	if not editor:
		return
	
	editor.select(start_line, 0, end_line + 1, 0)

func get_editor_info() -> Dictionary:
	"""Get comprehensive information about the current editor state"""
	return {
		"file_path": get_current_file_path(),
		"cursor_position": get_cursor_position(),
		"selected_text": get_selected_text(),
		"current_line": get_current_line(),
		"class_info": get_class_info(),
		"function_at_cursor": get_function_at_cursor(),
		"total_lines": get_current_code_edit().get_line_count() if get_current_code_edit() else 0
	}
