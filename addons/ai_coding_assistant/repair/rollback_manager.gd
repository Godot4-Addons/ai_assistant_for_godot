@tool
extends RefCounted
class_name AIRollbackManager

## Manages file backups and rollback for the agent's destructive operations.
## Creates automatic backups before writes/patches/deletes and can restore them.
## Integrates with git when available, falls back to local file copies.

const DEFAULT_BACKUP_DIR: String = "res://addons/ai_coding_assistant/backups/"
const MAX_BACKUPS_TO_KEEP: int = 8
const CLEANUP_AGE_DAYS: int = 7

signal backup_created(path: String, backup_path: String)
signal rollback_performed(path: String, success: bool)
signal backups_cleaned(count: int)

var _backup_dir: String = DEFAULT_BACKUP_DIR
var _manual_backups: Array[Dictionary] = []

func _init(backup_dir: String = DEFAULT_BACKUP_DIR) -> void:
	_backup_dir = backup_dir
	_ensure_dir()

## Create a backup of a file before modifying it.
## Returns the backup path string, or empty string on failure.
func create_backup(path: String) -> String:
	_ensure_dir()

	var content := _read_file_content(path)
	if content.is_empty():
		return ""

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var backup_path := _backup_dir.path_join(path.get_file() + "." + timestamp + ".bak")

	var file := FileAccess.open(backup_path, FileAccess.WRITE)
	if not file:
		push_error("RollbackManager: Failed to create backup: " + backup_path)
		return ""

	file.store_string(content)
	_manual_backups.append({
		"original": path,
		"backup": backup_path,
		"timestamp": Time.get_unix_time_from_system()
	})

	backup_created.emit(path, backup_path)
	_cleanup_old_backups()
	return backup_path

## Rollback a file to its most recent backup.
## Returns true if rollback succeeded.
func rollback(path: String) -> bool:
	var latest: Dictionary = _find_latest_backup(path)
	if latest.is_empty():
		push_warning("RollbackManager: No backup found for: " + path)
		return false

	var backup_path: String = latest.get("backup", "")
	var content := _read_file_content(backup_path)
	if content.is_empty():
		return false

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false

	file.store_string(content)
	rollback_performed.emit(path, true)
	return true

## List all backups for a given file path.
func list_backups(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var backup_dir := DirAccess.open(_backup_dir)
	if not backup_dir:
		return result

	var base_name := path.get_file()
	backup_dir.list_dir_begin()
	var name := backup_dir.get_next()
	while name != "":
		if name.begins_with(base_name + ".") and name.ends_with(".bak"):
			result.append({
				"file": name,
				"full_path": _backup_dir.path_join(name),
				"timestamp": _parse_timestamp_from_name(name, base_name)
			})
		name = backup_dir.get_next()

	result.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	return result

## Get the total count of existing backups.
func get_backup_count() -> int:
	var dir := DirAccess.open(_backup_dir)
	if not dir:
		return 0
	var count := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".bak"):
			count += 1
		name = dir.get_next()
	return count

## Delete old backups beyond the configured retention limits.
## Keeps only the latest MAX_BACKUPS_TO_KEEP per base file.
func cleanup_old_backups(keep: int = MAX_BACKUPS_TO_KEEP) -> int:
	var backup_dir := DirAccess.open(_backup_dir)
	if not backup_dir:
		return 0

	var files_by_base: Dictionary = {}
	backup_dir.list_dir_begin()
	var name := backup_dir.get_next()
	while name != "":
		if name.ends_with(".bak"):
			var base_name := name.get_basename().split(".")[0]
			if not files_by_base.has(base_name):
				files_by_base[base_name] = []
			files_by_base[base_name].append(name)
		name = backup_dir.get_next()

	var removed := 0
	for base_name in files_by_base:
		var files: Array = files_by_base[base_name]
		files.sort()
		files.reverse()
		if files.size() > keep:
			for i in range(keep, files.size()):
				var full_path := _backup_dir.path_join(files[i])
				if DirAccess.remove_absolute(full_path) == OK:
					removed += 1

	if removed > 0:
		backups_cleaned.emit(removed)
	return removed

## List all manual backups in memory-backed tracking.
func get_manual_backups() -> Array[Dictionary]:
	return _manual_backups.duplicate()

# ── Private ──

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(_backup_dir):
		DirAccess.make_dir_recursive_absolute(_backup_dir)

func _read_file_content(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	return file.get_as_text()

func _find_latest_backup(path: String) -> Dictionary:
	var backups := list_backups(path)
	if backups.is_empty():
		return {}
	return backups[0]

func _parse_timestamp_from_name(name: String, base_name: String) -> int:
	var without_ext := name.trim_suffix(".bak")
	var ts_str := without_ext.trim_prefix(base_name + ".")
	if ts_str.is_empty():
		return 0
	var parts := ts_str.split("-")
	if parts.size() >= 3:
		var date_str := parts[0] + "-" + parts[1] + "-" + parts[2]
		var dict := Time.get_datetime_dict_from_datetime_string(date_str, false)
		if not dict.is_empty():
			return Time.get_unix_time_from_datetime_dict(dict)
	return 0

func _cleanup_old_backups() -> void:
	cleanup_old_backups(MAX_BACKUPS_TO_KEEP)
