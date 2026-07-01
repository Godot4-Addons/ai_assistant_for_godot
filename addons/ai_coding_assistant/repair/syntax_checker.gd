@tool
extends RefCounted
class_name AISyntaxChecker

## GDScript syntax validation beyond basic bracket matching.
## Detects common issues: unbalanced brackets, missing indentation, trailing commas,
## invalid keywords, and Godot 3→4 migration patterns.

enum Severity { INFO, WARNING, ERROR }

class Issue:
	var line: int
	var column: int
	var message: String
	var severity: Severity
	var suggestion: String

	func _init(l: int, c: int, msg: String, sev: Severity = Severity.ERROR, sug: String = "") -> void:
		line = l
		column = c
		message = msg
		severity = sev
		suggestion = sug

## Validate GDScript code and return an array of Issue dicts
## Returns Array[Dictionary] with { line, column, message, severity, suggestion }
func validate(code: String) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if code.is_empty():
		return issues

	var lines := code.split("\n")
	_validate_bracket_balance(code, lines, issues)
	_validate_indentation(lines, issues)
	_validate_keywords(lines, issues)
	_validate_godot4_migration(code, lines, issues)
	_validate_trailing_commas(lines, issues)

	return issues

func has_fatal_errors(code: String) -> bool:
	for issue in validate(code):
		if issue.severity == Severity.ERROR:
			return true
	return false

func get_error_summary(code: String) -> String:
	var issues := validate(code)
	if issues.is_empty():
		return ""

	var lines: Array[String] = []
	for issue in issues:
		var sev := "ERROR" if issue.severity == Severity.ERROR else ("WARN" if issue.severity == Severity.WARNING else "INFO")
		lines.append("[%s] Line %d:%d - %s" % [sev, issue.line, issue.column, issue.message])
		if not issue.suggestion.is_empty():
			lines.append("  Suggestion: %s" % issue.suggestion)
	return "\n".join(lines)

# ── Bracket Balance ──

func _validate_bracket_balance(code: String, lines: Array, issues: Array) -> void:
	var pairs := [
		{"open": "(", "close": ")", "name": "parenthesis"},
		{"open": "[", "close": "]", "name": "bracket"},
		{"open": "{", "close": "}", "name": "brace"},
	]

	var stripped := _strip_strings_and_comments(code)

	for pair in pairs:
		var open_count := 0
		var close_count := 0
		for ch in stripped:
			if ch == pair.open:
				open_count += 1
			elif ch == pair.close:
				close_count += 1

		if open_count != close_count:
			var line_no := _find_unbalanced_line(lines, pair.open, pair.close)
			issues.append({
				"line": line_no,
				"column": 0,
				"message": "Unbalanced %s: %d open vs %d close" % [pair.name, open_count, close_count],
				"severity": Severity.ERROR,
				"suggestion": "Check that every '%s' has a matching '%s'" % [pair.open, pair.close]
			})

# ── Indentation ──

func _validate_indentation(lines: Array, issues: Array) -> void:
	var expected_indent := 0
	var in_multiline := false

	for i in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue

		var indent: int = _count_indent(line)

		if not in_multiline:
			if indent > expected_indent and expected_indent != 0:
				if indent - expected_indent not in [4, 8, 12, 16]:
					issues.append({
						"line": i + 1,
						"column": 0,
						"message": "Unexpected indentation: found %d spaces, expected multiple of 4 from previous indent level %d" % [indent, expected_indent],
						"severity": Severity.WARNING,
						"suggestion": "Use a consistent multiple of 4 spaces for indentation"
					})

		if stripped.ends_with(":") and not stripped.begins_with("#"):
			expected_indent = indent + 4

		if stripped.contains("\"\"\"") or stripped.contains("'''"):
			in_multiline = not in_multiline

# ── Keyword Validation ──

func _validate_keywords(lines: Array, issues: Array) -> void:
	var godot3_keywords := {
		"tool": "Use @tool annotation instead of 'tool' keyword",
		"export var": "Use @export var instead of 'export var'",
		"onready var": "Use @onready var instead of 'onready var'",
		"remote func": "Use @remote func instead of 'remote func'",
		"master func": "Use @master func instead of 'master func'",
		"puppet func": "Use @puppet func instead of 'puppet func'",
		"remotesync func": "Use @rpc annotation instead of 'remotesync func'",
		"sync func": "Use @rpc annotation instead of 'sync func'",
		"slave func": "Use @rpc annotation instead of 'slave func'",
	}

	var gdscript_errors := [
		"extends Node2D", "extends Node3D", "extends Spatial",
		"extends Sprite", "extends Sprite3D",
	]

	for i in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue

		for kw in godot3_keywords:
			if stripped.begins_with(kw):
				issues.append({
					"line": i + 1,
					"column": 0,
					"message": "Godot 3 syntax detected: '%s'" % kw,
					"severity": Severity.WARNING,
					"suggestion": godot3_keywords[kw]
				})

		for bad in gdscript_errors:
			if stripped.begins_with(bad):
				issues.append({
					"line": i + 1,
					"column": 0,
					"message": "'%s' is not a valid Godot 4 class" % bad,
					"severity": Severity.ERROR,
					"suggestion": "Use the correct Godot 4 class name (e.g. CharacterBody2D, Sprite2D)"
				})

# ── Godot 4 Migration Patterns ──

func _validate_godot4_migration(code: String, lines: Array, issues: Array) -> void:
	var patterns := {
		"is_on_floor()": "CharacterBody2D now uses is_on_floor() (no change needed, but ensure correct node type)",
		"Input.is_action_just_pressed": "Still valid in Godot 4, but in _process() use Input.is_action_just_pressed()",
		"KinematicBody2D": "Use CharacterBody2D instead of KinematicBody2D",
		"KinematicBody": "Use CharacterBody3D instead of KinematicBody",
		"AudioStreamPlayer2D": "Renamed to AudioStreamPlayer2D (still same name)",
		"Position2D": "Use Marker2D instead of Position2D",
		"Position3D": "Use Marker3D instead of Position3D",
		"CollisionPolygon2D": "Still valid, but ensure proper setup",
		"randomize()": "Use randf() or randi() directly — no need to call randomize()",
	}

	for i in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		for pat in patterns:
			if stripped.contains(pat):
				issues.append({
					"line": i + 1,
					"column": max(stripped.find(pat), 0),
					"message": "Potential migration issue: '%s'" % pat,
					"severity": Severity.INFO,
					"suggestion": patterns[pat]
				})

# ── Trailing Commas ──

func _validate_trailing_commas(lines: Array, issues: Array) -> void:
	for i in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		if stripped.length() > 1 and stripped.ends_with(",") and not stripped.ends_with(",\"") and not stripped.ends_with(",'"):
			var prev_char: String = stripped.substr(stripped.length() - 2, 1)
			if prev_char not in ["(", "[", "{", ","]:
				issues.append({
					"line": i + 1,
					"column": stripped.length() - 1,
					"message": "Suspicious trailing comma",
					"severity": Severity.INFO,
					"suggestion": "Remove trailing comma unless it's a single-element tuple"
				})

# ── Helpers ──

func _strip_strings_and_comments(code: String) -> String:
	var result := code
	var block_comment := RegEx.new()
	block_comment.compile("/\\*[\\s\\S]*?\\*/")
	result = block_comment.sub(result, "", true)

	var comment := RegEx.new()
	comment.compile("#.*$")
	result = comment.sub(result, "", true)

	var dq := RegEx.new()
	dq.compile("\"(?:\\\\.|[^\"])*\"")
	result = dq.sub(result, "", true)

	var sq := RegEx.new()
	sq.compile("'(?:\\\\.|[^'])*'")
	result = sq.sub(result, "", true)

	return result

func _count_indent(line: String) -> int:
	var count := 0
	for ch in line:
		if ch == " ":
			count += 1
		elif ch == "\t":
			count += 4
		else:
			break
	return count

func _find_unbalanced_line(lines: Array, open_ch: String, close_ch: String) -> int:
	var depth := 0
	for i in range(lines.size()):
		var line: String = lines[i]
		for ch in line:
			if ch == open_ch:
				depth += 1
			elif ch == close_ch:
				depth -= 1
		if depth < 0:
			return i + 1
	return lines.size()
