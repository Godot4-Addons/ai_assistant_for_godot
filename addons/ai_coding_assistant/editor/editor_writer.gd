@tool
extends RefCounted
class_name AIEditorWriter

var editor_interface: EditorInterface
var reader: AIEditorReader
var plugin_instance: EditorPlugin

func _init(interface: EditorInterface, reader_instance: AIEditorReader, plugin: EditorPlugin = null):
	editor_interface = interface
	reader = reader_instance
	plugin_instance = plugin

func _get_undo_redo() -> EditorUndoRedoManager:
	if plugin_instance:
		return plugin_instance.get_undo_redo()
	return null

func detect_apply_type(code: String) -> Dictionary:
	var editor = reader.get_current_code_edit()
	if not editor: return {"type": "insert"}
	
	var stripped = code.strip_edges()
	
	# 1. Check for full script
	if stripped.begins_with("extends ") or stripped.begins_with("class_name "):
		return {"type": "full_replace", "confidence": 0.9}
	
	# 2. Check for function match
	var regex = RegEx.new()
	regex.compile("func\\s+([a-zA-Z0-9_]+)\\s*\\(")
	var match = regex.search(stripped)
	if match:
		var func_name = match.get_string(1)
		var existing_info = reader.find_function(func_name)
		if not existing_info.is_empty():
			return {
				"type": "function_replace", 
				"func_name": func_name,
				"confidence": 0.8
			}
			
	return {"type": "insert"}

func replace_all_text(text: String):
	var editor = reader.get_current_code_edit()
	if editor:
		var ur = _get_undo_redo()
		if ur:
			ur.create_action("AI: Replace Entire Script")
			ur.add_do_property(editor, "text", text)
			ur.add_undo_property(editor, "text", editor.text)
			ur.commit_action()
		else:
			editor.text = text
		_save_if_needed()

func write_array_to_file(path: String, lines: Array[String]) -> bool:
	return write_file(path, "\n".join(lines))

func create_backup(path: String) -> String:
	var backup_dir = "res://addons/ai_coding_assistant/backups/"
	if not DirAccess.dir_exists_absolute(backup_dir):
		DirAccess.make_dir_recursive_absolute(backup_dir)
	
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var backup_path = backup_dir + path.get_file() + "." + timestamp + ".bak"
	
	var content = reader.read_file(path)
	if not content.is_empty():
		var file = FileAccess.open(backup_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			return backup_path
	return ""

func validate_syntax(code: String) -> bool:
	# Basic check for common errors using regex
	var regex = RegEx.new()
	# Check for unmatched parentheses/brackets
	var pairs = [["\\(", "\\)"], ["\\[", "\\]"], ["\\{", "\\}"]]
	for pair in pairs:
		regex.compile(pair[0])
		var open_count = regex.search_all(code).size()
		regex.compile(pair[1])
		var close_count = regex.search_all(code).size()
		if open_count != close_count:
			return false
	return true

func insert_text_at_cursor(text: String):
	var editor = reader.get_current_code_edit()
	if editor:
		var ur = _get_undo_redo()
		if ur:
			ur.create_action("AI: Insert Code")
			ur.add_do_method(editor, "insert_text_at_caret", text)
			# For undo, we'd need to know what was replaced or the length.
			# CodeEdit's insert_text_at_caret is already undo-aware if called correctly,
			# but EditorUndoRedoManager makes it show up in the Edit menu.
			ur.add_undo_method(editor, "undo")
			ur.commit_action()
		else:
			editor.insert_text_at_caret(text)
		
		var start_line = editor.get_caret_line()
		var start_col = editor.get_caret_column()
		var lines = text.split("\n")
		var end_line = start_line + lines.size() - 1
		var end_col = lines[-1].length()
		
		if lines.size() == 1:
			end_col += start_col
			
		editor.select(start_line, start_col, end_line, end_col)
		_save_if_needed()

func replace_selection(text: String):
	insert_text_at_cursor(text)

func insert_at_line(line: int, text: String):
	var editor = reader.get_current_code_edit()
	if editor and line >= 0 and line < editor.get_line_count():
		editor.set_caret_line(line)
		editor.set_caret_column(0)
		editor.insert_text_at_caret(text + "\n")
		_save_if_needed()

func replace_line(line: int, text: String):
	var editor = reader.get_current_code_edit()
	if editor and line >= 0 and line < editor.get_line_count():
		editor.set_caret_line(line)
		editor.set_caret_column(0)
		editor.select(line, 0, line + 1, 0)
		editor.insert_text_at_caret(text + "\n")
		_save_if_needed()

func replace_function(func_name: String, text: String):
	var info = reader.find_function(func_name)
	if not info.is_empty():
		var editor = reader.get_current_code_edit()
		editor.select(info.start_line, 0, info.end_line + 1, 0)
		editor.insert_text_at_caret(text)
		_save_if_needed()

func append_text(text: String):
	var editor = reader.get_current_code_edit()
	if editor:
		var last = editor.get_line_count() - 1
		editor.set_caret_line(last)
		editor.set_caret_column(editor.get_line(last).length())
		var t = ("\n" + text) if not editor.get_line(last).is_empty() else text
		editor.insert_text_at_caret(t)
		_save_if_needed()

func _save_if_needed():
	if editor_interface:
		editor_interface.save_scene()

func write_file(path: String, content: String) -> bool:
	var dir = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file: return false
	file.store_string(content)
	
	# Reload in editor if it's the current file
	if reader.get_current_file_path() == path:
		# There isn't a direct "reload" but we can notify
		pass
	
	return true

func delete_file(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var err = DirAccess.remove_absolute(path)
	return err == OK

func patch_file(path: String, search_text: String, replace_text: String) -> bool:
	var content = reader.read_file(path)
	if content.is_empty() or not search_text in content: return false
	
	if content.begins_with("[Binary file omitted:"):
		push_error("AI Assistant: Attempted to patch a binary file: " + path)
		return false
	
	var new_content = content.replace(search_text, replace_text)
	return write_file(path, new_content)
