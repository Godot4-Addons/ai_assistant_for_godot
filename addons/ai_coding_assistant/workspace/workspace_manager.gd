@tool
extends RefCounted
class_name AIWorkspaceManager

const FileOrganizer = preload("res://addons/ai_coding_assistant/workspace/file_organizer.gd")
const ProjectHealth = preload("res://addons/ai_coding_assistant/workspace/project_health.gd")

var _editor_integration
var _organizer: AIFileOrganizer
var _health: AIProjectHealth
var _last_snapshot: Dictionary = {}

signal workspace_changed(changed_files: Array)
signal workspace_drift_detected(description: String)

func _init(editor_integration) -> void:
	_editor_integration = editor_integration
	_organizer = FileOrganizer.new(editor_integration)
	_health = ProjectHealth.new(editor_integration)

func get_organizer() -> AIFileOrganizer:
	return _organizer

func get_health() -> AIProjectHealth:
	return _health

## Take a snapshot of all file modification times
func snapshot() -> Dictionary:
	var snap: Dictionary = {}
	var all_files := _list_all_files("res://")
	for f in all_files:
		snap[f] = FileAccess.get_modified_time(f)
	_last_snapshot = snap
	return snap

## Detect files changed since last snapshot
func get_changed_files() -> Array[String]:
	var current := snapshot()
	var changed: Array[String] = []
	for path in current:
		if not _last_snapshot.has(path):
			changed.append(path + " [NEW]")
		elif current[path] != _last_snapshot[path]:
			changed.append(path + " [MODIFIED]")
	for path in _last_snapshot:
		if not current.has(path):
			changed.append(path + " [DELETED]")
	return changed

## Get a categorized summary of project files
func get_workspace_summary() -> String:
	var files_by_type := _categorize_files()
	var total: int = 0
	for key in files_by_type:
		total += files_by_type[key].size()

	var lines: Array[String] = ["## WORKSPACE SUMMARY"]
	lines.append("Total files: %d" % total)
	lines.append("")

	if not files_by_type.scripts.is_empty():
		lines.append("### GDScript Files (%d)" % files_by_type.scripts.size())
		for f in files_by_type.scripts.slice(0, 20):
			lines.append("  - " + f)
		if files_by_type.scripts.size() > 20:
			lines.append("  ... and %d more" % (files_by_type.scripts.size() - 20))
		lines.append("")

	if not files_by_type.scenes.is_empty():
		lines.append("### Scenes (%d)" % files_by_type.scenes.size())
		for f in files_by_type.scenes:
			lines.append("  - " + f)
		lines.append("")

	if not files_by_type.resources.is_empty():
		lines.append("### Resources (%d)" % files_by_type.resources.size())
		for f in files_by_type.resources:
			lines.append("  - " + f)
		lines.append("")

	if not files_by_type.assets.is_empty():
		lines.append("### Assets (%d)" % files_by_type.assets.size())
		for f in files_by_type.assets.slice(0, 15):
			lines.append("  - " + f)

	return "\n".join(lines)

## Delegate to file_organizer
func suggest_file_path(file_type: String, class_name: String, context: String = "") -> String:
	return _organizer.suggest_path(file_type, class_name, context)

func detect_misplaced_files() -> Array[Dictionary]:
	return _organizer.detect_misplaced_files()

func ensure_project_structure() -> Array[String]:
	return _organizer.ensure_standard_dirs()

## Delegate to project_health
func check_project_health() -> Dictionary:
	var report := _health.run_full_check()
	return report.to_dict()

func _categorize_files() -> Dictionary:
	var all_files := _list_all_files("res://")
	var result := {"scripts": [], "scenes": [], "resources": [], "assets": [], "other": []}
	for f in all_files:
		match f.get_extension():
			"gd": result.scripts.append(f)
			"tscn": result.scenes.append(f)
			"tres", "res": result.resources.append(f)
			"png", "jpg", "svg", "wav", "ogg", "mp3": result.assets.append(f)
			_: result.other.append(f)
	return result

func _list_all_files(path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(path)
	if not dir:
		return results
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not f.begins_with("."):
			var full := path.path_join(f)
			if dir.current_is_dir():
				results.append_array(_list_all_files(full))
			else:
				results.append(full)
		f = dir.get_next()
	return results
