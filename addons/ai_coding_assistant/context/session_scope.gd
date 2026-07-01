@tool
extends RefCounted
class_name AISessionScope

var session_id: String
var context_snapshot: Dictionary = {}
var pinned_files: Array[String] = []

func pin_file(path: String) -> void:
	if path not in pinned_files:
		pinned_files.append(path)

func unpin_file(path: String) -> void:
	pinned_files.erase(path)

func is_pinned(path: String) -> bool:
	return path in pinned_files

func serialize() -> Dictionary:
	return {
		"session_id": session_id,
		"pinned_files": pinned_files,
		"context_snapshot": context_snapshot
	}

func deserialize(data: Dictionary) -> void:
	session_id = data.get("session_id", "")
	pinned_files = data.get("pinned_files", [])
	context_snapshot = data.get("context_snapshot", {})
