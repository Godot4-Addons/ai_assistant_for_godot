@tool
extends RefCounted
class_name AISelectionManager

signal selection_updated(text: String)

var editor_reader: AIEditorReader
var current_selection: String = ""

func _init(reader: AIEditorReader):
	editor_reader = reader

func refresh_selection() -> String:
	if not editor_reader: return ""
	var new_selection = editor_reader.get_selected_text()
	if new_selection != current_selection:
		current_selection = new_selection
		selection_updated.emit(current_selection)
	return current_selection

func clear_selection():
	current_selection = ""
	selection_updated.emit("")

func get_formatted_selection() -> String:
	if current_selection.strip_edges().is_empty():
		return ""
	return "\n```gdscript\n%s\n```\n" % current_selection
