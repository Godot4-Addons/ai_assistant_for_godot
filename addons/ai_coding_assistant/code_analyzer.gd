@tool
extends RefCounted

const Parser = preload("res://addons/ai_coding_assistant/analyzer/code_parser.gd")
const AIEngine = preload("res://addons/ai_coding_assistant/analyzer/completion_engine.gd")

static func analyze_current_context() -> Dictionary:
	var script_editor = EditorInterface.get_script_editor()
	if not script_editor or not script_editor.get_current_editor(): return {}
	
	var editor = script_editor.get_current_editor().get_base_editor()
	var script = script_editor.get_current_editor().get_edited_resource()
	
	var context = Parser.parse_script(editor.text, editor.get_caret_line())
	context.file_path = script.resource_path if script else ""
	context.line_number = editor.get_caret_line()
	context.cursor_position = editor.get_caret_column()
	
	return context

static func get_completion_context(text: String, cursor_pos: int) -> Dictionary:
	return AIEngine.get_completion_context(text, cursor_pos)

static func suggest_completion(ctx: Dictionary, code_ctx: Dictionary) -> Array:
	return AIEngine.suggest(ctx, code_ctx)
