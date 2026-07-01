@tool
extends RefCounted
class_name AIDamageRepair

## Central damage repair coordinator for the agent.
## Diagnoses and fixes common failure modes:
##   - Patch mismatches (search text not found)
##   - File not found
##   - Syntax errors after write/patch
##   - Dangling references after deletion
##   - Integration with loop engine for spiral recovery

const SyntaxChecker = preload("res://addons/ai_coding_assistant/repair/syntax_checker.gd")
const RollbackManager = preload("res://addons/ai_coding_assistant/repair/rollback_manager.gd")

signal repair_attempted(tool_name: String, args: Dictionary, error: String, suggestion: String)
signal repair_failed(tool_name: String, args: Dictionary, error: String)

var _syntax_checker: AISyntaxChecker
var _rollback: AIRollbackManager
var _max_repair_attempts: int = 2
var _repair_count: int = 0

func _init(max_attempts: int = 2) -> void:
	_syntax_checker = SyntaxChecker.new()
	_rollback = RollbackManager.new()
	_max_repair_attempts = max_attempts

## Main entry point: given a failed tool execution, attempt to diagnose and repair.
## Returns: { repaired: bool, message: String, corrected_args: Dictionary }
## If repaired=false, the caller should report the error to the user.
func diagnose_and_repair(tool_name: String, args: Dictionary, error_msg: String, editor_integration) -> Dictionary:
	_repair_count += 1
	if _repair_count > _max_repair_attempts:
		repair_failed.emit(tool_name, args, "Max repair attempts exceeded")
		return {"repaired": false, "message": "Repair limit reached.", "corrected_args": {}}

	# 1. Patch Mismatch Repair
	if tool_name == "patch_file" and _is_patch_mismatch(error_msg):
		var result := _repair_patch_mismatch(args, editor_integration)
		if result.repaired:
			return result

	# 2. File Not Found Repair
	if tool_name in ["read_file", "write_file", "patch_file", "delete_file"] and _is_file_not_found(error_msg):
		var result := _repair_file_not_found(args, editor_integration)
		if result.repaired:
			return result

	# 3. Syntax Error Repair (post-write/patch validation)
	if tool_name in ["write_file", "patch_file"] and _is_syntax_error(error_msg):
		var result := _repair_syntax_error(tool_name, args, editor_integration)
		if result.repaired:
			return result

	# 4. Dangling Reference Repair (post-delete)
	if tool_name == "delete_file" and _is_dangling_reference(error_msg):
		var result := _repair_dangling_reference(args, editor_integration)
		if result.repaired:
			return result

	repair_attempted.emit(tool_name, args, error_msg, "No automatic repair available")
	return {"repaired": false, "message": "No automatic repair available for: " + error_msg, "corrected_args": args}

## Validate a GDScript file after write or patch.
## Returns empty string if valid, or error summary if issues found.
func validate_script(path: String, editor_integration) -> String:
	if not path.ends_with(".gd"):
		return ""

	var content: String = editor_integration.read_file(path)
	if content.is_empty():
		return ""

	var errors: Array = _syntax_checker.validate(content)
	if errors.is_empty():
		return ""

	var fatal_only: Array = []
	for e in errors:
		if e.severity == AISyntaxChecker.Severity.ERROR:
			fatal_only.append(e)

	if fatal_only.is_empty():
		return ""

	return _syntax_checker.get_error_summary(content)

## Validate after write/patch and report issues
func post_execute_validation(tool_name: String, args: Dictionary, editor_integration) -> Dictionary:
	if tool_name not in ["write_file", "patch_file"]:
		return {"valid": true, "issues": ""}

	var path: String = args.get("path", "")
	if path.is_empty():
		return {"valid": true, "issues": ""}

	var summary := validate_script(path, editor_integration)
	if summary.is_empty():
		return {"valid": true, "issues": ""}

	return {"valid": false, "issues": summary}

## Check for dangling references after a delete_file operation.
## Returns list of files that reference the deleted path.
func detect_dangling_references(deleted_path: String, editor_integration) -> Array[String]:
	var refs: Array[String] = []
	var base_name: String = deleted_path.get_file()

	var files: Array = editor_integration.search_files(base_name, "res://")
	for match in files:
		var parts: String = str(match)
		if not parts.is_empty() and not parts.contains(deleted_path):
			var file_path := parts.split(":")[0].strip_edges()
			if not file_path.is_empty() and file_path.get_extension() in ["gd", "tscn"]:
				refs.append(file_path)

	return refs

## Reset repair counter (should be called when a new agent task starts).
func reset_repair_count() -> void:
	_repair_count = 0

func get_repair_count() -> int:
	return _repair_count

func get_rollback_manager() -> AIRollbackManager:
	return _rollback

# ── Repair Strategies ──

func _repair_patch_mismatch(args: Dictionary, editor_integration) -> Dictionary:
	var path: String = args.get("path", "")
	var search: String = args.get("search", "")
	var replace: String = args.get("replace", args.get("content", ""))

	if path.is_empty() or search.is_empty():
		return {"repaired": false, "message": "Missing path or search text", "corrected_args": {}}

	var content: String = editor_integration.read_file(path)
	if content.is_empty():
		return {"repaired": false, "message": "Cannot read file: " + path, "corrected_args": {}}

	# Try to find the search text with relaxed matching
	if not content.contains(search):
		var fuzzy_match: String = _fuzzy_find(content, search)
		if not fuzzy_match.is_empty():
			var corrected_args: Dictionary = args.duplicate()
			corrected_args["search"] = fuzzy_match
			repair_attempted.emit("patch_file", args,
				"Search text not found; fuzzy-matched to nearby text",
				"Using fuzzy match instead")
			return {"repaired": true, "message": "Fuzzy-matched search text", "corrected_args": corrected_args}

	# Try with stripped whitespace
	var search_stripped: String = search.strip_edges()
	var content_stripped: String = content.strip_edges()
	if content_stripped.contains(search_stripped) and search_stripped != search:
		var corrected_args: Dictionary = args.duplicate()
		corrected_args["search"] = search_stripped
		repair_attempted.emit("patch_file", args,
			"Search text not found (whitespace mismatch); using stripped version",
			"Using whitespace-normalized match")
		return {"repaired": true, "message": "Whitespace-adjusted match", "corrected_args": corrected_args}

	return {"repaired": false, "message": "Search text not found in file", "corrected_args": args}

func _repair_file_not_found(args: Dictionary, editor_integration) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty():
		return {"repaired": false, "message": "Missing path", "corrected_args": {}}

	var file_name: String = path.get_file()
	var search_result: Array = editor_integration.search_files(file_name, "res://")
	if search_result.is_empty():
		return {"repaired": false, "message": "File not found anywhere in project: " + file_name, "corrected_args": {}}

	var first_match: String = str(search_result[0])
	var found_path: String = first_match.split(":")[0].strip_edges()
	if found_path.is_empty():
		return {"repaired": false, "message": "Could not parse search result", "corrected_args": {}}

	var corrected_args: Dictionary = args.duplicate()
	corrected_args["path"] = found_path
	repair_attempted.emit("read_file", args,
		"File not found at specified path",
		"Found file at: " + found_path)
	return {"repaired": true, "message": "Redirected to: " + found_path, "corrected_args": corrected_args}

func _repair_syntax_error(tool_name: String, args: Dictionary, editor_integration) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty():
		return {"repaired": false, "message": "Missing path", "corrected_args": {}}

	var content: String = editor_integration.read_file(path)
	if content.is_empty():
		return {"repaired": false, "message": "Cannot read file for repair", "corrected_args": {}}

	# Simple auto-fixes for common issues
	var fixes: Array[Dictionary] = []

	# Fix: Godot 3 -> 4 class names
	if content.contains("KinematicBody2D"):
		fixes.append({"search": "KinematicBody2D", "replace": "CharacterBody2D"})
	if content.contains("KinematicBody"):
		fixes.append({"search": "KinematicBody", "replace": "CharacterBody3D"})
	if content.contains("Position2D"):
		fixes.append({"search": "Position2D", "replace": "Marker2D"})
	if content.contains("Position3D"):
		fixes.append({"search": "Position3D", "replace": "Marker3D"})

	var new_content: String = content
	for fix in fixes:
		new_content = new_content.replace(fix.search, fix.replace)

	if new_content != content:
		editor_integration.write_file(path, new_content)
		repair_attempted.emit(tool_name, args,
			"Syntax error detected",
			"Auto-fixed %d Godot 4 migration patterns" % fixes.size())
		return {"repaired": true, "message": "Applied %d auto-fixes" % fixes.size(), "corrected_args": args}

	return {"repaired": false, "message": "No auto-fix available", "corrected_args": args}

func _repair_dangling_reference(args: Dictionary, editor_integration) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty():
		return {"repaired": false, "message": "Missing path", "corrected_args": {}}

	var refs := detect_dangling_references(path, editor_integration)
	if refs.is_empty():
		return {"repaired": true, "message": "No dangling references found", "corrected_args": args}

	repair_attempted.emit("delete_file", args,
		"Dangling references detected",
		"Found %d references to deleted file in: %s" % [refs.size(), ", ".join(refs)])

	return {"repaired": true, "message": "Warning: %d files may reference deleted file. Check: %s" % [refs.size(), ", ".join(refs)], "corrected_args": args}

# ── Helpers ──

func _is_patch_mismatch(error: String) -> bool:
	return "search text not found" in error.to_lower() or "patch_file failed" in error.to_lower()

func _is_file_not_found(error: String) -> bool:
	return "file not found" in error.to_lower() or "cannot read" in error.to_lower()

func _is_syntax_error(error: String) -> bool:
	return "syntax" in error.to_lower() or "parse" in error.to_lower()

func _is_dangling_reference(error: String) -> bool:
	return "reference" in error.to_lower()

func _fuzzy_find(content: String, search: String) -> String:
	var search_words := search.strip_edges().split(" ", false)
	if search_words.size() < 3:
		return ""

	var lines := content.split("\n")
	for line in lines:
		var match_count := 0
		for word in search_words:
			if line.to_lower().contains(word.to_lower()):
				match_count += 1
		if match_count >= search_words.size() * 0.6:
			return line.strip_edges()

	return ""
