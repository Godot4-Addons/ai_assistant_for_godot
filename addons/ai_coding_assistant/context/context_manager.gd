@tool
extends RefCounted
class_name AIContextManager

## Orchestrates all context going into each AI request.
## Enforces budget limits, applies compression when needed,
## manages file content cache with timestamp invalidation,
## and provides a "do not re-read" guard.

const ContextWindow = preload("res://addons/ai_coding_assistant/context/context_window.gd")
const ContextCompressor = preload("res://addons/ai_coding_assistant/context/context_compressor.gd")
const SessionScope = preload("res://addons/ai_coding_assistant/context/session_scope.gd")

signal compression_applied(tier: int, message: String)

var _window: AIContextWindow
var _compressor: AIContextCompressor
var _scope: AISessionScope
var _file_cache: Dictionary = {}
var _read_files: Array[String] = []

func _init() -> void:
	_window = ContextWindow.new()
	_compressor = ContextCompressor.new()
	_scope = SessionScope.new()

func get_window() -> AIContextWindow:
	return _window

func get_scope() -> AISessionScope:
	return _scope

func get_compressor() -> AIContextCompressor:
	return _compressor

## Build the final context string for the next AI call.
## sections are keyed: system, project, blueprint, working_mem, files, tool_results, history
func build(sections: Dictionary) -> String:
	_window.reset()
	var parts: Array[String] = []

	if sections.has("system"):
		var text: String = sections["system"]
		_window.allocate("system", text)
		parts.append("## SYSTEM\n" + text)

	if sections.has("project"):
		var text: String = sections["project"]
		_window.allocate("project", text)
		parts.append(text)

	if sections.has("blueprint"):
		var text: String = sections["blueprint"]
		_window.allocate("blueprint", text)
		parts.append("### BLUEPRINT\n" + text)

	if sections.has("working_mem"):
		var text: String = sections["working_mem"]
		_window.allocate("working_mem", text)
		parts.append(text)

	if sections.has("files"):
		var text: String = sections["files"]
		_window.allocate("files", text)
		parts.append("### FILE CONTENTS\n" + text)

	if sections.has("tool_results"):
		var text: String = sections["tool_results"]
		_window.allocate("tool_results", text)
		parts.append(text)

	if sections.has("history"):
		var text: String = _compress_history_if_needed(sections["history"])
		_window.allocate("history", text)
		if not text.is_empty():
			parts.append("### CONVERSATION HISTORY\n" + text)

	return "\n\n".join(parts.filter(func(s): return not s.is_empty()))

## Cache-aware file reading
func read_file_cached(path: String, reader) -> String:
	if path in _scope.pinned_files and _file_cache.has(path):
		return _file_cache[path].content

	var mtime: float = 0.0
	if FileAccess.file_exists(path):
		mtime = FileAccess.get_modified_time(path)

	if _file_cache.has(path) and _file_cache[path].timestamp == mtime:
		return _file_cache[path].content

	var content: String = reader.read_file(path)
	if not content.is_empty():
		_file_cache[path] = {"content": content, "timestamp": mtime}
		if path not in _read_files:
			_read_files.append(path)

	return content

func invalidate_cache(path: String) -> void:
	_file_cache.erase(path)
	_read_files.erase(path)

func invalidate_all() -> void:
	_file_cache.clear()
	_read_files.clear()

## Returns list of files already read (for prompt injection)
func get_read_files_list() -> Array[String]:
	return _read_files.duplicate()

## Check if a file should be read (not already in context)
func should_read_file(path: String) -> bool:
	return path not in _read_files

func get_tier() -> int:
	return _window.get_compression_tier()

func get_tier_label() -> String:
	return _window.get_tier_label()

func get_token_report() -> String:
	return _window.get_section_report()

## Pin a file to always stay in context
func pin_file(path: String) -> void:
	_scope.pin_file(path)

func unpin_file(path: String) -> void:
	_scope.unpin_file(path)

func get_token_estimate(text: String) -> int:
	return ContextWindow.estimate_tokens(text)

# ── Private ──

func _compress_history_if_needed(history: String) -> String:
	if history.is_empty():
		return ""

	var tokens := ContextWindow.estimate_tokens(history)
	var tier := _window.get_compression_tier()

	if tier < 1:
		return history

	if tier == 1:
		return history

	var turns: Array = _parse_history_to_turns(history)
	if turns.is_empty():
		return history

	if tier >= 2:
		var keep := 10 if tier == 2 else 4
		var result := _compressor.rolling_window(turns, keep)
		var compressed: String = ""
		for turn in result:
			compressed += "[%s]: %s\n" % [turn.get("role", ""), turn.get("content", "")]
		compression_applied.emit(tier, "Applied rolling window compression (tier %d)" % tier)
		return compressed

	return history

func _parse_history_to_turns(history: String) -> Array:
	var turns: Array = []
	for line in history.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("[user]:"):
			turns.append({"role": "user", "content": trimmed.trim_prefix("[user]:").strip_edges()})
		elif trimmed.begins_with("[assistant]:"):
			turns.append({"role": "assistant", "content": trimmed.trim_prefix("[assistant]:").strip_edges()})
	return turns
