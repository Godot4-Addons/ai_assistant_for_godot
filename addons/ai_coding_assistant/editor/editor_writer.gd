@tool
extends RefCounted
class_name AIEditorWriter

var editor_interface: EditorInterface
var reader: AIEditorReader

func _init(interface: EditorInterface, reader_instance: AIEditorReader):
	editor_interface = interface
	reader = reader_instance

func insert_text_at_cursor(text: String):
	var editor = reader.get_current_code_edit()
	if editor:
		var start_line = editor.get_caret_line()
		var start_col = editor.get_caret_column()
		
		# Replace selection if one exists, otherwise just insert
		editor.insert_text_at_caret(text)
		
		var lines = text.split("\n")
		var end_line = start_line + lines.size() - 1
		var end_col = lines[-1].length()
		
		if lines.size() == 1:
			end_col += start_col
			
		editor.select(start_line, start_col, end_line, end_col)
		_save_if_needed()

func replace_selection(text: String):
	insert_text_at_cursor(text)

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
