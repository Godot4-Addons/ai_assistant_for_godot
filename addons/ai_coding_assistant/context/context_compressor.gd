@tool
extends RefCounted
class_name AIContextCompressor

## Compresses context when it exceeds budget thresholds.
## Three strategies: rolling window (drop old turns),
## summarization (AI-generated summary of old turns),
## semantic pruning (keep only relevant turns).

const ContextWindow = preload("res://addons/ai_coding_assistant/context/context_window.gd")

## Rolling window: keep only the last N turns.
func rolling_window(turns: Array, keep: int) -> Array:
	if turns.size() <= keep:
		return turns
	return turns.slice(turns.size() - keep)

## Summarization: compress old turns into a summary string.
## Returns { history: Array, summary: String }
func summarize(turns: Array, keep_recent: int) -> Dictionary:
	if turns.size() <= keep_recent:
		return {"history": turns, "summary": ""}

	var split := turns.size() - keep_recent
	var old_turns := turns.slice(0, split)
	var recent_turns := turns.slice(split)

	var summary_lines: Array[String] = []
	for turn in old_turns:
		var role: String = turn.get("role", "")
		var content: String = turn.get("content", "")
		var short: String = content.substr(0, 150).strip_edges()
		summary_lines.append("[%s]: %s..." % [role, short])

	var summary_entry := {
		"role": "system",
		"content": "### COMPRESSED HISTORY SUMMARY\n" + "\n".join(summary_lines)
	}

	return {
		"history": [summary_entry] + recent_turns,
		"summary": summary_entry.content
	}

## Semantic pruning: keep only turns relevant to the current task.
func prune_by_relevance(turns: Array, current_task: String, keep_tokens: int) -> Array:
	if turns.is_empty():
		return turns

	var scored: Array = []
	for i in range(turns.size()):
		var turn = turns[i]
		var content: String = turn.get("content", "")
		var score := _relevance_score(content, current_task)
		scored.append({"turn": turn, "index": i, "score": score})

	scored.sort_custom(func(a, b): return a.score > b.score)

	var kept: Array = []
	var used: int = 0
	for item in scored:
		var tokens: int = ContextWindow.estimate_tokens(item.turn.get("content", ""))
		if used + tokens <= keep_tokens:
			kept.append(item.turn)
			used += tokens

	kept.sort_custom(func(a, b): return a.index < b.index)
	return kept

## Estimate tokens for a string
static func estimate_tokens_str(text: String) -> int:
	return ContextWindow.estimate_tokens(text)

func _relevance_score(content: String, task: String) -> float:
	var content_lower := content.to_lower()
	var task_words := task.to_lower().split(" ", false)
	if task_words.is_empty():
		return 0.0

	var match_count: int = 0
	for word in task_words:
		if word.length() > 3 and content_lower.contains(word):
			match_count += 1

	return float(match_count) / float(task_words.size())
