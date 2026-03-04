@tool
extends RefCounted
class_name AIAgentMemory

## Manages agent working memory, session history, and persistent memory.
## Handles context window budget management and intelligent history compaction.

const MEMORY_DIR = "user://ai_agent_memory/"
const SESSION_FILE = "user://ai_agent_memory/sessions.json"
const CONTEXT_BUDGET_CHARS: int = 12000
const MAX_WORKING_MEMORY_ENTRIES: int = 30
const MAX_SESSION_HISTORY: int = 50

## Working memory — tool calls and results for the current agent loop
var working_memory: Array[Dictionary] = []

## Session history — summarized past exchanges (current session)
var session_history: Array[Dictionary] = []

## Long-term memory — loaded from disk
var _persistent_sessions: Array[Dictionary] = []

func _init() -> void:
	_ensure_memory_dir()
	_load_persistent_memory()

# ─────────────────────────────────────────────────────────────────────────────
# Working Memory (Current Agent Loop)
# ─────────────────────────────────────────────────────────────────────────────

## Add a tool call and its result to working memory
func add_tool_result(tool_name: String, args: Dictionary, result: Dictionary) -> void:
	working_memory.append({
		"type": "tool",
		"tool": tool_name,
		"args": args,
		"result": result,
		"timestamp": Time.get_ticks_msec()
	})
	# Trim if oversized
	if working_memory.size() > MAX_WORKING_MEMORY_ENTRIES:
		working_memory.pop_front()

## Add an AI thought/plan step to working memory
func add_agent_thought(thought: String) -> void:
	working_memory.append({
		"type": "thought",
		"content": thought,
		"timestamp": Time.get_ticks_msec()
	})

## Get formatted working memory for the AI prompt
func get_working_memory_prompt() -> String:
	if working_memory.is_empty():
		return ""
	var lines: Array[String] = ["### WORKING MEMORY (Current Task Context)"]
	for entry in working_memory:
		if entry.type == "tool":
			var result_str := JSON.stringify(entry.result).substr(0, 500)
			lines.append("- Tool `%s`(%s) → %s" % [
				entry.tool ,
				JSON.stringify(entry.args).substr(0, 100),
				result_str
			])
		elif entry.type == "thought":
			lines.append("- Plan: %s" % entry.content.substr(0, 200))
	return "\n".join(lines)

## Clear working memory at the start of a new agent task
func clear_working_memory() -> void:
	working_memory.clear()

# ─────────────────────────────────────────────────────────────────────────────
# Session History (Current Session)
# ─────────────────────────────────────────────────────────────────────────────

## Add a completed exchange (user + assistant) to session history
func add_exchange(user_msg: String, assistant_msg: String) -> void:
	session_history.append({
		"role": "user",
		"content": user_msg,
		"time": Time.get_ticks_msec()
	})
	session_history.append({
		"role": "assistant",
		"content": assistant_msg,
		"time": Time.get_ticks_msec()
	})
	# Compact if too long
	if _measure_history_size() > CONTEXT_BUDGET_CHARS:
		compact_history()

## Get session history formatted for API (array of {role, content} dicts)
func get_api_history() -> Array:
	var result: Array = []
	for entry in session_history:
		result.append({"role": entry.role, "content": entry.content})
	return result

## Compact old entries by summarizing them
func compact_history() -> void:
	if session_history.size() <= 4:
		return
	# Keep last 4 exchanges, summarize the rest
	var to_compact := session_history.slice(0, session_history.size() - 4)
	var kept := session_history.slice(session_history.size() - 4)

	# Build summary text
	var summary_parts: Array[String] = []
	for entry in to_compact:
		var short: String = entry.content.substr(0, 150).strip_edges()
		summary_parts.append("[%s]: %s..." % [entry.role, short])

	var summary_entry := {
		"role": "system",
		"content": "### COMPACTED HISTORY SUMMARY\n" + "\n".join(summary_parts),
		"time": Time.get_ticks_msec()
	}
	session_history = [summary_entry] + kept

# ─────────────────────────────────────────────────────────────────────────────
# Persistent Memory (Cross-Session)
# ─────────────────────────────────────────────────────────────────────────────

## Save current session to disk
func save_session(task_summary: String) -> void:
	if session_history.is_empty():
		return
	var session: Dictionary = {
		"saved_at": Time.get_datetime_string_from_system(),
		"task_summary": task_summary,
		"exchanges": session_history.slice(0, min(session_history.size(), 10))
	}
	_persistent_sessions.append(session)
	# Keep only latest N sessions
	if _persistent_sessions.size() > MAX_SESSION_HISTORY:
		_persistent_sessions.pop_front()
	_write_persistent_memory()

## Load sessions from disk
func _load_persistent_memory() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return
	var file := FileAccess.open(SESSION_FILE, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.data
		if data is Array:
			_persistent_sessions.assign(data)

## Get relevant past context for a given task
func get_relevant_context(task: String) -> String:
	if _persistent_sessions.is_empty():
		return ""
	# Simple keyword matching — find sessions whose summary matches the task
	var task_words := task.to_lower().split(" ")
	var relevant: Array[String] = []
	for session in _persistent_sessions:
		var summary: String = session.get("task_summary", "").to_lower()
		var match_count := 0
		for word in task_words:
			if word.length() > 3 and summary.contains(word):
				match_count += 1
		if match_count >= 2:
			relevant.append("**Past session** (%s): %s" % [
				session.get("saved_at", ""),
				session.get("task_summary", "")
			])
	if relevant.is_empty():
		return ""
	return "### RELEVANT PAST WORK\n" + "\n".join(relevant.slice(0, 3))

## Delete sessions older than max_age_hours
func clear_old_memory(max_age_hours: int = 72) -> int:
	var now := Time.get_unix_time_from_system()
	var removed := 0
	var kept: Array[Dictionary] = []
	for session in _persistent_sessions:
		var saved: String = session.get("saved_at", "")
		if saved.is_empty():
			kept.append(session)
			continue
		var dict := Time.get_datetime_dict_from_datetime_string(saved, false)
		var unix := Time.get_unix_time_from_datetime_dict(dict)
		var age_hours := (now - unix) / 3600.0
		if age_hours <= max_age_hours:
			kept.append(session)
		else:
			removed += 1
	_persistent_sessions = kept
	if removed > 0:
		_write_persistent_memory()
	return removed

## Clear all persistent memory
func clear_all_memory() -> void:
	_persistent_sessions.clear()
	session_history.clear()
	working_memory.clear()
	_write_persistent_memory()

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _measure_history_size() -> int:
	var total := 0
	for entry in session_history:
		total += entry.get("content", "").length()
	return total

func _ensure_memory_dir() -> void:
	if not DirAccess.dir_exists_absolute(MEMORY_DIR):
		DirAccess.make_dir_recursive_absolute(MEMORY_DIR)

func _write_persistent_memory() -> void:
	_ensure_memory_dir()
	var file := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_persistent_sessions, "\t"))
