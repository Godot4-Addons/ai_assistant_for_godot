@tool
extends RefCounted

const Formatter = preload("res://addons/ai_coding_assistant/utils/code_formatter.gd")
const Validator = preload("res://addons/ai_coding_assistant/utils/code_validator.gd")

static func format_code_for_ai(c, l = "gdscript"): return Formatter.format_for_ai(c, l)
static func extract_code_from_response(r): return Formatter.extract_code(r)
static func is_code_response(r): return Formatter.is_code(r)
static func clean_ai_response(r): return Formatter.clean_response(r)
static func validate_gdscript_syntax(c): return Validator.validate_syntax(c)
static func suggest_improvements(c): return Validator.suggest_improvements(c)

static func truncate_text(t, m = 100):
	return t if t.length() <= m else t.substr(0, m - 3) + "..."
