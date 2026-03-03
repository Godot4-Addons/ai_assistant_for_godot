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
		editor.insert_text_at_caret(text)
		_save_if_needed()

func replace_selection(text: String):
	var editor = reader.get_current_code_edit()
	if editor and not editor.get_selected_text().is_empty():
		editor.insert_text_at_caret(text)
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
