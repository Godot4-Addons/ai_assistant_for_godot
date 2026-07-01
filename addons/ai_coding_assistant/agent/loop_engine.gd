@tool
extends RefCounted
class_name AILoopEngine

## Convergence-based loop engine that replaces the simple iteration counter.
## Detects:
##   - Duplicate responses (via fingerprinting)
##   - Spiral errors (consecutive failures)
##   - No-progress stalls
##   - Natural conversation completion
##   - Turn budget exhaustion with self-reporting

const FINGERPRINT_WINDOW: int = 6
const SPAM_WINDOW: int = 4
const MAX_CONSECUTIVE_ERRORS: int = 4
const MAX_CONSECUTIVE_STALLS: int = 3
const TURN_BUDGET_REPORT_INTERVAL: int = 25

var max_iterations: int = 50
var max_seconds: float = 300.0

var _iteration: int = 0
var _start_time: float = 0.0
var _fingerprints: Array[String] = []
var _tool_call_hashes: Array[String] = []
var _consecutive_errors: int = 0
var _stall_count: int = 0
var _last_output_hash: String = ""
var _last_tool_results_hash: String = ""
var _no_tool_turns: int = 0
var _last_report_turn: int = 0
var _error_spiral_warned: bool = false
var _forced_abort: bool = false

signal limit_approached(message: String)
signal limit_reached(reason: String)

func reset() -> void:
	_iteration = 0
	_start_time = Time.get_ticks_msec() / 1000.0
	_fingerprints.clear()
	_tool_call_hashes.clear()
	_consecutive_errors = 0
	_stall_count = 0
	_last_output_hash = ""
	_last_tool_results_hash = ""
	_no_tool_turns = 0
	_last_report_turn = 0
	_error_spiral_warned = false
	_forced_abort = false

## Returns { allowed: bool, reason: String, warning: String, correction: String }
func check(tool_calls: Array, step_output: String, tool_results_hash: String = "") -> Dictionary:
	_iteration += 1
	var elapsed := _get_elapsed()
	var warning := ""
	var correction := ""

	if _forced_abort:
		return {"allowed": false, "reason": "Agent previously aborted.", "warning": "", "correction": ""}

	if elapsed > max_seconds:
		limit_reached.emit("Time limit reached (%.0fs)" % elapsed)
		return {"allowed": false, "reason": "Agent stopped: exceeded maximum time limit of %.0f seconds." % max_seconds, "warning": "", "correction": ""}

	if _iteration > max_iterations:
		limit_reached.emit("Iteration limit reached (%d)" % _iteration)
		return {"allowed": false, "reason": "Agent stopped: exceeded maximum %d iterations." % max_iterations, "warning": "", "correction": ""}

	# ── Response Fingerprinting (duplicate detection) ──
	var fp := _fingerprint(step_output)
	if not fp.is_empty():
		var dup_count := 0
		for f in _fingerprints:
			if f == fp:
				dup_count += 1
		if dup_count >= 2:
			correction = "⚠️ SYSTEM: You just sent a response that is very similar to previous ones. Please take a different approach."
			_warn_if_needed("Repeating same response — try a different approach.")
		_fingerprints.append(fp)
		if _fingerprints.size() > FINGERPRINT_WINDOW:
			_fingerprints.pop_front()

	# ── Tool Call Deduplication ──
	if tool_calls.size() > 0:
		var call_hash := _hash_tool_calls(tool_calls)
		var repeat_count := 0
		for h in _tool_call_hashes:
			if h == call_hash:
				repeat_count += 1
		if repeat_count >= 3:
			if tool_results_hash == _last_tool_results_hash and not tool_results_hash.is_empty():
				correction = "⚠️ SYSTEM: You have made the same tool call %d times with identical results. Please do something different or conclude the task." % repeat_count
				_warn_if_needed("Same tool call repeated %d times with identical results." % repeat_count)
		_tool_call_hashes.append(call_hash)
		if _tool_call_hashes.size() > SPAM_WINDOW:
			_tool_call_hashes.pop_front()
		_last_tool_results_hash = tool_results_hash
		_no_tool_turns = 0
	else:
		_no_tool_turns += 1

	# ── Error Spiral Detection ──
	if _has_errors(tool_results_hash):
		_consecutive_errors += 1
	else:
		_consecutive_errors = 0

	if _consecutive_errors >= MAX_CONSECUTIVE_ERRORS and not _error_spiral_warned:
		correction = "⚠️ SYSTEM ERROR: %d consecutive tool failures detected. Carefully re-read the file before retrying, or use a different approach." % _consecutive_errors
		_error_spiral_warned = true
		_warn_if_needed("Error spiral detected — %d consecutive failures." % _consecutive_errors)

	# ── No-Progress Detection ──
	if _no_tool_turns >= MAX_CONSECUTIVE_STALLS:
		correction = "⚠️ SYSTEM: You have not used any tools for %d turns. Please use the available tools to complete the task or provide your final summary." % _no_tool_turns

	# ── Natural Completion Detection ──
	if _is_natural_finish(step_output):
		return {"allowed": true, "reason": "natural_finish", "warning": warning, "correction": correction}

	# ── Stall detection (identical output) ──
	var out_hash := str(step_output.hash())
	if out_hash == _last_output_hash and not step_output.is_empty():
		_stall_count += 1
	else:
		_stall_count = 0
	_last_output_hash = out_hash

	if _stall_count >= MAX_CONSECUTIVE_STALLS:
		correction = "⚠️ SYSTEM: Output is unchanged for %d turns. Please take a concrete action or conclude the task." % _stall_count

	# ── Turn Budget Self-Reporting ──
	if _iteration - _last_report_turn >= TURN_BUDGET_REPORT_INTERVAL:
		var pct := float(_iteration) / float(max_iterations) * 100.0
		warning = "📊 Turn report: %d/%d iterations used (%.0f%%). %s" % [
			_iteration, max_iterations, pct,
			"Wrap up soon." if pct > 75 else "Continue the task."
		]
		_last_report_turn = _iteration
		limit_approached.emit(warning)

	# ── Escalating warnings at 75%+ ──
	var pct := float(_iteration) / float(max_iterations)
	if pct >= 0.85:
		warning = "⚠️ CRITICAL: %d/%d iterations used. You MUST conclude the task." % [_iteration, max_iterations]
		limit_approached.emit(warning)
	elif pct >= 0.65:
		warning = "⚠️ %d/%d iterations used. Please work toward completion." % [_iteration, max_iterations]
		limit_approached.emit(warning)

	return {"allowed": true, "reason": "", "warning": warning, "correction": correction}

func get_iteration() -> int:
	return _iteration

func get_elapsed() -> float:
	return _get_elapsed()

func get_no_tool_turns() -> int:
	return _no_tool_turns

func get_consecutive_errors() -> int:
	return _consecutive_errors

func force_abort(reason: String) -> void:
	_forced_abort = true
	limit_reached.emit(reason)

func _get_elapsed() -> float:
	return (Time.get_ticks_msec() / 1000.0) - _start_time

func _fingerprint(text: String) -> String:
	var cleaned := text.strip_edges().to_lower()
	if cleaned.is_empty():
		return ""
	var words := cleaned.split(" ", false)
	if words.size() < 5:
		return ""
	var key_words: Array[String] = []
	for w in words:
		if w.length() > 3:
			key_words.append(w)
	return str(key_words.hash())

func _hash_tool_calls(calls: Array) -> String:
	var parts: Array[String] = []
	for call in calls:
		if call is Dictionary:
			parts.append(call.get("tool", "") + "|" + JSON.stringify(call.get("args", {})))
	return "|".join(parts)

func _has_errors(tool_results_hash: String) -> bool:
	return not tool_results_hash.is_empty() and tool_results_hash.begins_with("-1")

func _is_natural_finish(output: String) -> bool:
	var lower := output.strip_edges().to_lower()
	var finish_indicators := [
		"the task is complete",
		"all goals have been achieved",
		"the project is now ready",
		"here is a summary of what was done",
		"your game is ready",
		"task finished",
		"all done",
	]
	for indicator in finish_indicators:
		if lower.contains(indicator):
			return true
	return false

func _warn_if_needed(msg: String) -> void:
	limit_approached.emit(msg)
