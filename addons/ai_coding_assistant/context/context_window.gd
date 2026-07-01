@tool
extends RefCounted
class_name AIContextWindow

## Tracks the context budget allocation for each AI request.
## Estimates token usage, enforces per-section budget limits,
## and reports compression tier warnings.

signal budget_warning(message: String)

const MAX_TOKENS: int = 200_000
const RESERVE_TOKENS: int = 32_000
const AVAILABLE_TOKENS: int = MAX_TOKENS - RESERVE_TOKENS

const BUDGET_SYSTEM_PROMPT: int  = 5_000
const BUDGET_PROJECT_CTX: int    = 5_000
const BUDGET_BLUEPRINT: int      = 2_000
const BUDGET_WORKING_MEM: int    = 10_000
const BUDGET_FILE_CONTENTS: int  = 50_000
const BUDGET_TOOL_RESULTS: int   = 20_000
const BUDGET_HISTORY: int        = 76_000

var _used_tokens: int = 0
var _section_usage: Dictionary = {}

func reset() -> void:
	_used_tokens = 0
	_section_usage.clear()

func get_used() -> int:
	return _used_tokens

func get_available() -> int:
	return AVAILABLE_TOKENS

func get_remaining() -> int:
	return AVAILABLE_TOKENS - _used_tokens

func get_usage_pct() -> float:
	return float(_used_tokens) / float(AVAILABLE_TOKENS) * 100.0

## Allocate tokens for a section. Returns the max allowed for that section.
func allocate(section: String, text: String) -> int:
	var tokens: int = estimate_tokens(text)
	var budget: int = _get_budget_for_section(section)
	_section_usage[section] = tokens
	_used_tokens += tokens

	if tokens > budget:
		budget_warning.emit("[%s] exceeds budget: %d/%d tokens" % [section, tokens, budget])

	return budget

## Rough token estimation: ~4 chars per token for English/code
static func estimate_tokens(text: String) -> int:
	if text.is_empty():
		return 0
	return int(text.length() / 4.0)

## More accurate for mixed code/English
static func estimate_tokens_accurate(text: String) -> int:
	if text.is_empty():
		return 0
	return int(text.length() / 3.5)

func get_compression_tier() -> int:
	var pct := get_usage_pct()
	if pct < 70:
		return 0
	elif pct < 85:
		return 1
	elif pct < 95:
		return 2
	else:
		return 3

func get_tier_label() -> String:
	match get_compression_tier():
		0: return "Normal"
		1: return "Warning"
		2: return "Rolling Window"
		3: return "Full Summarization"
		_: return "Unknown"

func get_section_report() -> String:
	var lines: Array[String] = []
	for section in _section_usage:
		var budget: int = _get_budget_for_section(section)
		var used: int = _section_usage[section]
		var pct: float = float(used) / float(budget) * 100.0 if budget > 0 else 0.0
		lines.append("%s: %d/%d tokens (%.0f%%)" % [section, used, budget, pct])
	return "\n".join(lines)

func _get_budget_for_section(section: String) -> int:
	match section:
		"system":     return BUDGET_SYSTEM_PROMPT
		"project":    return BUDGET_PROJECT_CTX
		"blueprint":  return BUDGET_BLUEPRINT
		"working_mem": return BUDGET_WORKING_MEM
		"files":      return BUDGET_FILE_CONTENTS
		"tool_results": return BUDGET_TOOL_RESULTS
		"history":    return BUDGET_HISTORY
		_:            return 10_000
