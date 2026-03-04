@tool
extends RefCounted
## Standalone syntax highlighter for code blocks.
## Supports GDScript, Python, JavaScript/TypeScript, C#, Bash, C/C++.
## No class_name — loaded via preload() from AIMarkdownParser.

# ─────────────────────────────────────────────────────────────────────────────
# Configurable colors (HTML hex without #)
# ─────────────────────────────────────────────────────────────────────────────

var color_keyword := "ff7085" # Rose — control flow & declarations
var color_type := "8be9fd" # Cyan — built-in types/classes
var color_string := "f1fa8c" # Yellow — string literals
var color_comment := "6272a4" # Muted blue — comments
var color_number := "bd93f9" # Purple — numeric literals
var color_function := "50fa7b" # Green — function names
var color_annotation := "ffb86c" # Orange — decorators/@annotations

# ─────────────────────────────────────────────────────────────────────────────
# Language Keyword/Type Data
# ─────────────────────────────────────────────────────────────────────────────

const GDSCRIPT_KEYWORDS := [
	"if", "elif", "else", "for", "while", "match", "break", "continue",
	"pass", "return", "class", "class_name", "extends", "is", "in",
	"as", "self", "signal", "func", "static", "const", "enum", "var",
	"breakpoint", "preload", "await", "yield", "assert", "void",
	"true", "false", "null", "not", "and", "or",
	"export", "onready", "tool", "master", "puppet", "slave",
	"remotesync", "sync", "remote",
]

const GDSCRIPT_TYPES := [
	"int", "float", "bool", "String", "Vector2", "Vector3", "Vector4",
	"Vector2i", "Vector3i", "Vector4i", "Color", "Rect2", "Rect2i",
	"Transform2D", "Transform3D", "Basis", "Quaternion", "AABB",
	"Plane", "Projection", "RID", "Callable", "Signal", "Dictionary",
	"Array", "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
	"PackedFloat32Array", "PackedFloat64Array", "PackedStringArray",
	"PackedVector2Array", "PackedVector3Array", "PackedColorArray",
	"NodePath", "StringName", "Node", "Node2D", "Node3D", "Control",
	"Resource", "Object", "RefCounted", "Variant",
	"CharacterBody2D", "CharacterBody3D", "RigidBody2D", "RigidBody3D",
	"Area2D", "Area3D", "CollisionShape2D", "CollisionShape3D",
	"Sprite2D", "Sprite3D", "AnimatedSprite2D", "Camera2D", "Camera3D",
	"Timer", "Label", "Button", "TextureRect", "RichTextLabel",
	"AudioStreamPlayer", "TileMap", "TileMapLayer",
]

const PYTHON_KEYWORDS := [
	"if", "elif", "else", "for", "while", "break", "continue", "pass",
	"return", "def", "class", "import", "from", "as", "with", "try",
	"except", "finally", "raise", "yield", "lambda", "global", "nonlocal",
	"assert", "del", "in", "is", "not", "and", "or",
	"True", "False", "None", "async", "await",
]

const PYTHON_TYPES := [
	"int", "float", "str", "bool", "list", "dict", "tuple", "set",
	"bytes", "bytearray", "type", "object", "range", "enumerate",
	"zip", "map", "filter", "print", "len", "isinstance", "super",
]

const JS_KEYWORDS := [
	"if", "else", "for", "while", "do", "switch", "case", "default",
	"break", "continue", "return", "function", "var", "let", "const",
	"class", "extends", "new", "delete", "typeof", "instanceof",
	"try", "catch", "finally", "throw", "async", "await", "yield",
	"import", "export", "from", "of", "in",
	"true", "false", "null", "undefined", "this", "super",
]

const JS_TYPES := [
	"Array", "Object", "String", "Number", "Boolean", "Map", "Set",
	"Promise", "Date", "RegExp", "Error", "Symbol", "BigInt",
	"console", "document", "window", "Math", "JSON",
]

const CSHARP_KEYWORDS := [
	"if", "else", "for", "foreach", "while", "do", "switch", "case",
	"default", "break", "continue", "return", "class", "struct", "enum",
	"interface", "namespace", "using", "new", "public", "private",
	"protected", "internal", "static", "readonly", "const", "override",
	"virtual", "abstract", "sealed", "partial", "async", "await",
	"try", "catch", "finally", "throw", "var", "out", "ref", "in",
	"is", "as", "typeof", "sizeof", "void", "get", "set",
	"true", "false", "null", "this", "base", "yield",
]

const CSHARP_TYPES := [
	"int", "float", "double", "decimal", "bool", "string", "char",
	"byte", "short", "long", "uint", "ulong", "object",
	"List", "Dictionary", "Task", "Action", "Func",
	"Vector2", "Vector3", "GodotObject", "Node", "Resource",
]

const BASH_KEYWORDS := [
	"if", "then", "else", "elif", "fi", "for", "while", "do", "done",
	"case", "esac", "in", "function", "return", "exit",
	"echo", "read", "local", "export", "source", "alias", "unalias",
	"set", "unset", "shift", "trap", "eval", "exec",
	"true", "false",
]

const C_KEYWORDS := [
	"if", "else", "for", "while", "do", "switch", "case", "default",
	"break", "continue", "return", "struct", "enum", "union", "typedef",
	"sizeof", "static", "const", "volatile", "extern", "register",
	"auto", "inline", "void", "goto",
	"#include", "#define", "#ifdef", "#ifndef", "#endif", "#pragma",
	"true", "false", "NULL",
]

const C_TYPES := [
	"int", "float", "double", "char", "long", "short", "unsigned",
	"signed", "size_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t",
	"int8_t", "int16_t", "int32_t", "int64_t", "bool",
	"FILE", "string", "vector", "map", "set", "pair",
	"std", "cout", "cin", "endl", "nullptr",
]

# ─────────────────────────────────────────────────────────────────────────────
# Language Resolution
# ─────────────────────────────────────────────────────────────────────────────

func get_keywords(lang: String) -> Array:
	match lang:
		"gdscript", "gd": return GDSCRIPT_KEYWORDS
		"python", "py": return PYTHON_KEYWORDS
		"javascript", "js", "typescript", "ts": return JS_KEYWORDS
		"csharp", "cs", "c#": return CSHARP_KEYWORDS
		"bash", "sh", "shell", "zsh": return BASH_KEYWORDS
		"c", "cpp", "c++", "h", "hpp": return C_KEYWORDS
	return GDSCRIPT_KEYWORDS

func get_types(lang: String) -> Array:
	match lang:
		"gdscript", "gd": return GDSCRIPT_TYPES
		"python", "py": return PYTHON_TYPES
		"javascript", "js", "typescript", "ts": return JS_TYPES
		"csharp", "cs", "c#": return CSHARP_TYPES
		"c", "cpp", "c++", "h", "hpp": return C_TYPES
	return GDSCRIPT_TYPES

func get_comment_prefix(lang: String) -> String:
	match lang:
		"gdscript", "gd": return "#"
		"python", "py": return "#"
		"bash", "sh", "shell", "zsh": return "#"
	return "//"

# ─────────────────────────────────────────────────────────────────────────────
# Main Highlight API
# ─────────────────────────────────────────────────────────────────────────────

func highlight(code: String, lang: String, escape_fn: Callable) -> String:
	var keywords := get_keywords(lang)
	var types := get_types(lang)
	var comment_char := get_comment_prefix(lang)
	var result := ""
	for line in code.split("\n"):
		if result != "":
			result += "\n"
		result += _highlight_line(line, keywords, types, comment_char, lang, escape_fn)
	return result

# ─────────────────────────────────────────────────────────────────────────────
# Line-Level Tokenization
# ─────────────────────────────────────────────────────────────────────────────

func _highlight_line(line: String, keywords: Array, types: Array, comment_char: String, lang: String, escape_fn: Callable) -> String:
	var escaped: String = escape_fn.call(line)

	# Phase 1: Full-line comments
	var stripped := escaped.strip_edges()
	if stripped.begins_with(escape_fn.call(comment_char)):
		return "[color=#%s]%s[/color]" % [color_comment, escaped]

	# Phase 2: Split at inline comment (respecting strings)
	var code_part := escaped
	var comment_part := ""
	var esc_comment: String = escape_fn.call(comment_char)
	var in_str := false
	var str_char := ""
	var i := 0
	while i < code_part.length():
		var ch := code_part[i]
		if not in_str:
			if ch == "\"" or ch == "'":
				in_str = true
				str_char = ch
			elif code_part.substr(i).begins_with(esc_comment):
				comment_part = "[color=#%s]%s[/color]" % [color_comment, code_part.substr(i)]
				code_part = code_part.substr(0, i)
				break
		else:
			if ch == str_char and (i == 0 or code_part[i - 1] != "\\"):
				in_str = false
		i += 1

	# Phase 3: Tokenize and colorize
	var colored := code_part

	# Strings
	var string_regex := RegEx.create_from_string("(\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''|\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*')")
	var temp := colored
	for r in string_regex.search_all(temp):
		var pos := temp.find(r.get_string())
		if pos == -1:
			continue
		temp = temp.substr(0, pos) + "[color=#%s]" % color_string + r.get_string() + "[/color]" + temp.substr(pos + r.get_string().length())
	colored = temp

	# Numbers
	colored = _apply_token_color(colored, "(?<![a-zA-Z_#])\\b(0x[0-9a-fA-F]+|0b[01]+|[0-9]+\\.?[0-9]*(?:e[+-]?[0-9]+)?)\\b", color_number)

	# Annotations
	if lang in ["gdscript", "gd", "python", "py", "java", "kotlin"]:
		colored = _apply_token_color(colored, "(@[a-zA-Z_][a-zA-Z0-9_]*)", color_annotation)

	# Keywords
	for kw in keywords:
		var escaped_kw: String = kw.replace("+", "\\+").replace("#", "\\#")
		colored = _apply_token_color(colored, "(?<![a-zA-Z_])(" + escaped_kw + ")(?![a-zA-Z0-9_])", color_keyword)

	# Types
	for tp in types:
		colored = _apply_token_color(colored, "(?<![a-zA-Z_])(" + tp + ")(?![a-zA-Z0-9_])", color_type)

	# Function calls
	temp = colored
	var func_regex := RegEx.create_from_string("([a-zA-Z_][a-zA-Z0-9_]*)\\(")
	var func_results := func_regex.search_all(temp)
	var func_positions := []
	for r in func_results:
		var before := temp.substr(0, r.get_start())
		if before.count("[color=") > before.count("[/color]"):
			continue
		func_positions.append({"start": r.get_start(1), "end": r.get_end(1), "text": r.get_string(1)})
	func_positions.reverse()
	for fp in func_positions:
		temp = temp.substr(0, fp.start) + "[color=#%s]%s[/color]" % [color_function, fp.text] + temp.substr(fp.end)
	colored = temp

	return colored + comment_part

## Applies a color tag to all regex matches not already inside a color tag.
func _apply_token_color(text: String, pattern: String, color: String) -> String:
	var regex := RegEx.create_from_string(pattern)
	var results := regex.search_all(text)
	var positions := []
	for r in results:
		var before := text.substr(0, r.get_start())
		if before.count("[color=") > before.count("[/color]"):
			continue
		positions.append({"start": r.get_start(), "end": r.get_end(), "text": r.get_string()})
	positions.reverse()
	for p in positions:
		text = text.substr(0, p.start) + "[color=#%s]%s[/color]" % [color, p.text] + text.substr(p.end)
	return text
