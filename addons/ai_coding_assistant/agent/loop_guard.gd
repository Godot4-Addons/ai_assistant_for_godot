@tool
extends RefCounted
class_name AILoopGuard

## Loop protection and circuit breaker for the agentic loop.
## Prevents infinite loops, repetitive actions, stalls, and runaway execution.

const DEFAULT_MAX_ITERATIONS: int = 15
const DEFAULT_MAX_SECONDS: float = 120.0
const REPEAT_DETECT_WINDOW: int = 5
const MAX_CONSECUTIVE_STALLS: int = 3

var max_iterations: int = DEFAULT_MAX_ITERATIONS
var max_seconds: float = DEFAULT_MAX_SECONDS

var _iteration: int = 0
var _start_time: float = 0.0
var _tool_hash_history: Array[String] = []
var _stall_count: int = 0
var _last_output_hash: String = ""

signal limit_approached(message: String)
signal limit_reached(reason: String)

func reset() -> void:
	_iteration = 0
	_start_time = Time.get_ticks_msec() / 1000.0
	_tool_hash_history.clear()
	_stall_count = 0
	_last_output_hash = ""

## Call before each agent step.
## Returns: { allowed: bool, reason: String, warning: String }
func check(tool_calls: Array, step_output: String) -> Dictionary:
	_iteration += 1
	var elapsed := _get_elapsed()
	var warning := ""

	# Hard time limit
	if elapsed > max_seconds:
		limit_reached.emit("Time limit reached (%.0fs)" % elapsed)
		return {
			"allowed": false,
			"reason": "Agent stopped: exceeded maximum time limit of %.0f seconds." % max_seconds,
			"warning": ""
		}

	# Hard iteration limit
	if _iteration > max_iterations:
		limit_reached.emit("Iteration limit reached (%d)" % _iteration)
		return {
			"allowed": false,
			"reason": "Agent stopped: exceeded maximum %d iterations." % max_iterations,
			"warning": ""
		}

	# Escalating warnings at 50% and 75%
	var pct := float(_iteration) / float(max_iterations)
	if pct >= 0.75:
		warning = "⚠️ WARNING: Approaching iteration limit (%d/%d). Finalize now." % [_iteration, max_iterations]
		limit_approached.emit(warning)
	elif pct >= 0.5:
		warning = "Note: %d/%d iterations used. Stay focused on the task." % [_iteration, max_iterations]

	# Repetition detection — hash the tool calls
	if tool_calls.size() > 0:
		var call_hash := _hash_tool_calls(tool_calls)
		var repeat_count := 0
		for h in _tool_hash_history:
			if h == call_hash:
				repeat_count += 1
		if repeat_count >= 3:
			return {
				"allowed": false,
				"reason": "Agent stopped: same tool call repeated %d times. Possible loop detected. Try a different approach." % repeat_count,
				"warning": ""
			}
		_tool_hash_history.append(call_hash)
		if _tool_hash_history.size() > REPEAT_DETECT_WINDOW:
			_tool_hash_history.pop_front()

	# Stall detection — identical output hash for 3 consecutive steps
	var out_hash := str(step_output.hash())
	if out_hash == _last_output_hash and not step_output.is_empty():
		_stall_count += 1
	else:
		_stall_count = 0
	_last_output_hash = out_hash

	if _stall_count >= MAX_CONSECUTIVE_STALLS:
		return {
			"allowed": false,
			"reason": "Agent stopped: output unchanged for %d consecutive steps. No progress detected." % _stall_count,
			"warning": ""
		}

	return {"allowed": true, "reason": "", "warning": warning}

func get_iteration() -> int:
	return _iteration

func get_elapsed() -> float:
	return _get_elapsed()

func _get_elapsed() -> float:
	return (Time.get_ticks_msec() / 1000.0) - _start_time

func _hash_tool_calls(calls: Array) -> String:
	var parts: Array[String] = []
	for call in calls:
		if call is Dictionary:
			parts.append(call.get("tool", "") + "|" + JSON.stringify(call.get("args", {})))
	return "|".join(parts)
