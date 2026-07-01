@tool
extends RefCounted
class_name AIProjectHealth

var _editor_integration

func _init(editor_integration) -> void:
	_editor_integration = editor_integration

class HealthReport:
	var issues: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []

	func add_issue(type: String, file: String, description: String, fix: String = "") -> void:
		issues.append({"type": type, "file": file, "description": description, "fix": fix})

	func add_warning(type: String, file: String, description: String) -> void:
		warnings.append({"type": type, "file": file, "description": description})

	func to_string() -> String:
		var lines: Array[String] = ["## PROJECT HEALTH REPORT"]
		if issues.is_empty() and warnings.is_empty():
			return lines[0] + "\n✅ No issues found!"
		if not issues.is_empty():
			lines.append("\n### ❌ Issues (%d)" % issues.size())
			for i in issues:
				lines.append("- [%s] %s: %s" % [i.type, i.file, i.description])
				if not i.fix.is_empty():
					lines.append("  Fix: %s" % i.fix)
		if not warnings.is_empty():
			lines.append("\n### ⚠️ Warnings (%d)" % warnings.size())
			for w in warnings:
				lines.append("- [%s] %s: %s" % [w.type, w.file, w.description])
		return "\n".join(lines)

	func to_dict() -> Dictionary:
		return {"issues": issues, "warnings": warnings}

var _report: HealthReport = null

func run_full_check() -> HealthReport:
	_report = HealthReport.new()
	_check_duplicate_class_names(_report)
	_check_missing_autoloads(_report)
	_check_orphaned_scenes(_report)
	_check_broken_preloads(_report)
	_check_missing_scripts(_report)
	return _report

func get_last_report() -> HealthReport:
	return _report

func _check_duplicate_class_names(report: HealthReport) -> void:
	var scripts := _list_by_extension("res://", "gd")
	var class_names: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("class_name (\\w+)")

	for script_path in scripts:
		var file := FileAccess.open(script_path, FileAccess.READ)
		if not file:
			continue
		var content := file.get_as_text()
		var m := regex.search(content)
		if m:
			var cname: String = m.get_string(1)
			if class_names.has(cname):
				report.add_issue("duplicate_class", script_path,
					"class_name '%s' also defined in %s" % [cname, class_names[cname]],
					"Rename one of the classes")
			else:
				class_names[cname] = script_path

func _check_missing_autoloads(report: HealthReport) -> void:
	for key in ProjectSettings.get_property_list():
		var pname: String = key.get("name", "")
		if pname.begins_with("autoload/"):
			var path: String = ProjectSettings.get_setting(pname, "")
			var clean_path := path.trim_prefix("*")
			if not FileAccess.file_exists(clean_path):
				report.add_issue("missing_autoload", clean_path,
					"Autoload '%s' references non-existent file" % pname.trim_prefix("autoload/"),
					"Create the file or remove the autoload from Project Settings > Autoload")

func _check_orphaned_scenes(report: HealthReport) -> void:
	var all_scenes := _list_by_extension("res://", "tscn")
	var all_scripts := _list_by_extension("res://", "gd")
	var all_files: Array[String] = []
	all_files.append_array(all_scenes)
	all_files.append_array(all_scripts)

	# Check each scene — if it's not referenced anywhere, it may be orphaned
	var project_settings_text := ""
	var ps_file := FileAccess.open("res://project.godot", FileAccess.READ)
	if ps_file:
		project_settings_text = ps_file.get_as_text()

	for scene_path in all_scenes:
		var referenced := false
		# Check if referenced by other files
		for f in all_files:
			if f == scene_path:
				continue
			var file := FileAccess.open(f, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				if content.contains(scene_path):
					referenced = true
					break

		# Check if it's the main scene
		if not referenced and project_settings_text.contains(scene_path):
			referenced = true

		if not referenced:
			report.add_warning("orphaned_scene", scene_path,
				"Scene is not referenced by any other file — may be unused")

func _check_broken_preloads(report: HealthReport) -> void:
	var all_scripts := _list_by_extension("res://", "gd")
	var preload_regex := RegEx.new()
	preload_regex.compile("preload\\(\"(res://[^\"]+)\"\\)")

	for script_path in all_scripts:
		var file := FileAccess.open(script_path, FileAccess.READ)
		if not file:
			continue
		var content := file.get_as_text()
		var matches := preload_regex.search_all(content)
		for m in matches:
			var ref_path: String = m.get_string(1)
			if not FileAccess.file_exists(ref_path):
				report.add_issue("broken_preload", script_path,
					"Broken preload: %s" % ref_path,
					"Fix the path or recreate the resource")

func _check_missing_scripts(report: HealthReport) -> void:
	var all_scenes := _list_by_extension("res://", "tscn")
	var ext_res_regex := RegEx.new()
	ext_res_regex.compile("script = ExtResource\\( \"([^\"]+)\"\\)")
	var ext_def_regex := RegEx.new()
	ext_def_regex.compile("\\[ext_resource path=\"([^\"]+)\" type=\"Script\" id=\"([^\"]+)\"")

	for scene_path in all_scenes:
		var file := FileAccess.open(scene_path, FileAccess.READ)
		if not file:
			continue
		var content := file.get_as_text()

		# Build script ID -> path map
		var script_map: Dictionary = {}
		var defs := ext_def_regex.search_all(content)
		for d in defs:
			script_map[d.get_string(2)] = d.get_string(1)

		# Check each script reference
		var refs := ext_res_regex.search_all(content)
		for r in refs:
			var script_id: String = r.get_string(1)
			if script_map.has(script_id):
				var script_path: String = script_map[script_id]
				if not FileAccess.file_exists(script_path):
					report.add_issue("missing_script", scene_path,
						"Missing script: %s (referenced in %s)" % [script_path, scene_path.get_file()],
						"Create the script or re-attach in the editor")

func _list_by_extension(path: String, ext: String) -> Array[String]:
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
				results.append_array(_list_by_extension(full, ext))
			elif f.get_extension() == ext:
				results.append(full)
		f = dir.get_next()
	return results
