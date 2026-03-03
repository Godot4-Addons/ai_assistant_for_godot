@tool
extends RefCounted

# High-level facade for editor interactions
const Reader = preload("res://addons/ai_coding_assistant/editor/editor_reader.gd")
const Writer = preload("res://addons/ai_coding_assistant/editor/editor_writer.gd")

var reader: AIEditorReader
var writer: AIEditorWriter
var editor_interface: EditorInterface

func _init(interface: EditorInterface):
	editor_interface = interface
	reader = Reader.new(interface)
	writer = Writer.new(interface, reader)

# Delegate methods
func get_all_text() -> String: return reader.get_all_text()
func get_selected_text() -> String: return reader.get_selected_text()
func get_current_line() -> String: return reader.get_current_line()
func get_lines_around_cursor(b = 5, a = 5) -> String: return reader.get_lines_around_cursor(b, a)
func get_function_at_cursor() -> Dictionary: return reader.get_function_at_cursor()
func get_class_info() -> Dictionary: return reader.get_class_info()
func get_current_file_path() -> String: return reader.get_current_file_path()

func insert_text_at_cursor(t: String): writer.insert_text_at_cursor(t)
func replace_selected_text(t: String): writer.replace_selection(t)
func replace_line(l: int, t: String): writer.replace_line(l, t)
func replace_function(n: String, t: String): writer.replace_function(n, t)
func append_to_file(t: String): writer.append_text(t)

func get_editor_info() -> Dictionary:
	return {
		"file_path": get_current_file_path(),
		"selected_text": get_selected_text(),
		"current_line": get_current_line(),
		"class_info": get_class_info(),
		"function_at_cursor": get_function_at_cursor()
	}

func list_files(dir: String = "res://") -> Array: return reader.list_files(dir)
func read_file(path: String) -> String: return reader.read_file(path)
func write_file(path: String, content: String) -> bool: return writer.write_file(path, content)
func delete_file(path: String) -> bool: return writer.delete_file(path)
func search_files(p: String, d: String = "res://") -> Array: return reader.search_files(p, d)
func patch_file(p: String, s: String, r: String) -> bool: return writer.patch_file(p, s, r)

func open_scene(path: String):
	if editor_interface: editor_interface.open_scene_from_path(path)

func open_script(path: String):
	if editor_interface: editor_interface.edit_resource(load(path))

func run_project():
	if editor_interface: editor_interface.play_main_scene()
