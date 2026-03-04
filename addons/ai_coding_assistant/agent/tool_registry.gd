@tool
extends RefCounted
class_name AIToolRegistry

## Modular tool registry — registers, validates, and executes all agent tools.
## All tools self-describe their parameters for prompt generation.

signal tool_executed(tool_name: String, args: Dictionary, result: Dictionary)

const XML_TOOL_REGEX = "<(\\w+)(?:\\s+([^>]*?))?\\s*(?:>([\\s\\S]*?)<\\/\\1>|\\/>)"

var _tools: Dictionary = {}
var _editor_integration # AIEditorIntegration
var _context: AIAgentContext

func _init(editor_integration, agent_context: AIAgentContext) -> void:
	_editor_integration = editor_integration
	_context = agent_context
	_register_all_tools()

# ─────────────────────────────────────────────────────────────────────────────
# Registration
# ─────────────────────────────────────────────────────────────────────────────

func register_tool(name: String, description: String, params: Dictionary, handler: Callable) -> void:
	_tools[name] = {
		"description": description,
		"params": params, # { param_name: { type, required, description } }
		"handler": handler,
	}

func _register_all_tools() -> void:
	# File Tools
	register_tool("read_file",
		"Read the complete contents of a file.",
		{"path": {"type": "String", "required": true, "desc": "File path (e.g. res://scripts/player.gd)"}},
		_tool_read_file)

	register_tool("write_file",
		"Create a new file or overwrite an existing one with the given content.",
		{
			"path": {"type": "String", "required": true, "desc": "File path to write"},
			"content": {"type": "String", "required": true, "desc": "Full file content"}
		},
		_tool_write_file)

	register_tool("patch_file",
		"Surgically replace a specific block of text in an existing file. Prefer this over write_file for edits.",
		{
			"path": {"type": "String", "required": true, "desc": "File path to patch"},
			"search": {"type": "String", "required": true, "desc": "Exact text to find and replace"},
			"replace": {"type": "String", "required": true, "desc": "Replacement text"}
		},
		_tool_patch_file)

	register_tool("delete_file",
		"Delete a file from the project. Requires user confirmation.",
		{"path": {"type": "String", "required": true, "desc": "File path to delete"}},
		_tool_delete_file)

	register_tool("list_files",
		"List files and subdirectories in a directory.",
		{"path": {"type": "String", "required": false, "desc": "Directory path (default: res://)"}},
		_tool_list_files)

	register_tool("search_files",
		"Search all project files using a regex pattern. Returns matching lines with file paths.",
		{
			"pattern": {"type": "String", "required": true, "desc": "Regex pattern to search for"},
			"dir": {"type": "String", "required": false, "desc": "Directory to search in (default: res://)"}
		},
		_tool_search_files)

	register_tool("create_directory",
		"Create a new directory (and any missing parents).",
		{"path": {"type": "String", "required": true, "desc": "Directory path to create"}},
		_tool_create_directory)

	# Project Tools
	register_tool("get_project_structure",
		"Get a full annotated file tree of the project.",
		{"depth": {"type": "int", "required": false, "desc": "Max depth (default 3)"}},
		_tool_get_project_structure)

	register_tool("get_project_settings",
		"Get key project settings (main scene, display, physics, etc.).",
		{},
		_tool_get_project_settings)

	register_tool("get_autoloads",
		"List all autoloaded singletons in the project.",
		{},
		_tool_get_autoloads)

	register_tool("get_dependencies",
		"List files that a given script or scene depends on.",
		{"path": {"type": "String", "required": true, "desc": "Path to inspect dependencies for"}},
		_tool_get_dependencies)

	# Scene Tools
	register_tool("get_scene_info",
		"Parse a .tscn file and return node hierarchy and properties.",
		{"path": {"type": "String", "required": true, "desc": "Path to the .tscn scene file"}},
		_tool_get_scene_info)

	register_tool("list_resources",
		"List all .tres resource files in the project.",
		{"dir": {"type": "String", "required": false, "desc": "Directory to search (default: res://)"}},
		_tool_list_resources)

	register_tool("inspect_resource",
		"Read a .tres or .res resource file and show its exported properties.",
		{"path": {"type": "String", "required": true, "desc": "Resource file path"}},
		_tool_inspect_resource)

	# Editor Tools
	register_tool("open_scene",
		"Open a scene in the Godot editor.",
		{"path": {"type": "String", "required": true, "desc": "Path to .tscn file to open"}},
		_tool_open_scene)

	register_tool("open_script",
		"Open a script in the Godot script editor.",
		{"path": {"type": "String", "required": true, "desc": "Path to .gd file to open"}},
		_tool_open_script)

	register_tool("run_project",
		"Run the Godot project (play main scene).",
		{},
		_tool_run_project)

	register_tool("stop_project",
		"Stop the running Godot project.",
		{},
		_tool_stop_project)

	register_tool("get_editor_state",
		"Get the current editor state: active script, open files, cursor position.",
		{},
		_tool_get_editor_state)

	# Blueprint
	register_tool("update_blueprint",
		"Update the project .ai_blueprint.md with architectural notes, decisions, and current goals. Always keep this updated.",
		{"content": {"type": "String", "required": true, "desc": "Full updated blueprint content in Markdown"}},
		_tool_update_blueprint)

# ─────────────────────────────────────────────────────────────────────────────
# Prompt Generation
# ─────────────────────────────────────────────────────────────────────────────

func get_tool_schemas() -> String:
	var lines: Array[String] = [
		"## AVAILABLE TOOLS",
		"Use XML tags to call tools. Self-closing format: `<tool_name attr=\"val\" />`",
		"Content format: `<tool_name attr=\"val\">content</tool_name>`",
		""
	]
	for tool_name in _tools:
		var t: Dictionary = _tools[tool_name]
		lines.append("### `<%s>`" % tool_name)
		lines.append(t.description)
		if not t.params.is_empty():
			lines.append("Params:")
			for pname in t.params:
				var p: Dictionary = t.params[pname]
				var req: String = " *(required)*" if p.get("required", false) else ""
				lines.append("  - `%s` (%s)%s: %s" % [pname, p.get("type", "String"), req, p.get("desc", "")])
		lines.append("")
	return "\n".join(lines)

# ─────────────────────────────────────────────────────────────────────────────
# Parsing
# ─────────────────────────────────────────────────────────────────────────────

func parse_tool_calls(response: String) -> Array[Dictionary]:
	var calls: Array[Dictionary] = []
	var regex := RegEx.new()
	regex.compile(XML_TOOL_REGEX)
	var matches := regex.search_all(response)
	for m in matches:
		var tool_name := m.get_string(1)
		if not _tools.has(tool_name):
			continue
		var attrs_str := m.get_string(2)
		var body := m.get_string(3).strip_edges()
		var attrs := _parse_attrs(attrs_str)
		# Content in body can override or supplement attrs
		if not body.is_empty() and not attrs.has("content"):
			attrs["content"] = body
		calls.append({"tool": tool_name, "args": attrs})
	return calls

func _parse_attrs(attrs_str: String) -> Dictionary:
	var attrs: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("(\\w+)=\"([^\"]*)\"")
	var matches := regex.search_all(attrs_str)
	for m in matches:
		attrs[m.get_string(1)] = m.get_string(2)
	return attrs

# ─────────────────────────────────────────────────────────────────────────────
# Execution
# ─────────────────────────────────────────────────────────────────────────────

func execute_tool(tool_name: String, args: Dictionary) -> Dictionary:
	if not _tools.has(tool_name):
		return {"error": "Unknown tool: " + tool_name}
	var handler: Callable = _tools[tool_name].handler
	var result: Dictionary = {}
	result = handler.call(args)
	tool_executed.emit(tool_name, args, result)
	return result

func format_result_for_prompt(tool_name: String, args: Dictionary, result: Dictionary) -> String:
	var path := args.get("path", args.get("dir", ""))
	var header := "TOOL `%s`%s →" % [tool_name, (" [%s]" % path if not path.is_empty() else "")]
	if result.has("error"):
		return "%s ERROR: %s" % [header, result.error]
	if result.has("data"):
		var data_str := str(result.data)
		if data_str.length() > 2000:
			data_str = data_str.substr(0, 2000) + "\n... [truncated]"
		return "%s\n%s" % [header, data_str]
	if result.has("success"):
		return "%s %s" % [header, "OK ✓" if result.success else "FAILED"]
	return "%s %s" % [header, JSON.stringify(result)]

# ─────────────────────────────────────────────────────────────────────────────
# Tool Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _tool_read_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not _editor_integration: return {"error": "No editor integration"}
	var content: String = _editor_integration.read_file(path)
	if content.is_empty(): return {"error": "File not found or empty: " + path}
	return {"data": content}

func _tool_write_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var content: String = args.get("content", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not _editor_integration: return {"error": "No editor integration"}
	var ok: bool = _editor_integration.write_file(path, content)
	if ok: _context.clear_cache()
	return {"success": ok, "path": path}

func _tool_patch_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var search: String = args.get("search", "")
	var replace: String = args.get("replace", args.get("content", ""))
	if path.is_empty() or search.is_empty(): return {"error": "Missing path or search"}
	if not _editor_integration: return {"error": "No editor integration"}
	var ok: bool = _editor_integration.patch_file(path, search, replace)
	if not ok: return {"error": "patch_file failed — search text not found in: " + path}
	_context.clear_cache()
	return {"success": true, "path": path}

func _tool_delete_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not _editor_integration: return {"error": "No editor integration"}
	var ok: bool = _editor_integration.delete_file(path)
	if ok: _context.clear_cache()
	return {"success": ok, "path": path}

func _tool_list_files(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "res://")
	if not _editor_integration: return {"error": "No editor integration"}
	return {"data": _editor_integration.list_files(path)}

func _tool_search_files(args: Dictionary) -> Dictionary:
	var pattern: String = args.get("pattern", "")
	var dir: String = args.get("dir", "res://")
	if pattern.is_empty(): return {"error": "Missing pattern"}
	if not _editor_integration: return {"error": "No editor integration"}
	return {"data": _editor_integration.search_files(pattern, dir)}

func _tool_create_directory(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	var err := DirAccess.make_dir_recursive_absolute(path)
	return {"success": err == OK, "path": path}

func _tool_get_project_structure(args: Dictionary) -> Dictionary:
	if not _context: return {"error": "No context available"}
	var depth: int = int(args.get("depth", 3))
	return {"data": _context.get_file_tree(depth)}

func _tool_get_project_settings(args: Dictionary) -> Dictionary:
	var settings: Dictionary = {
		"name": ProjectSettings.get_setting("application/config/name", ""),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"display_width": ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
		"display_height": ProjectSettings.get_setting("display/window/size/viewport_height", 720),
		"physics_fps": ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60),
	}
	return {"data": settings}

func _tool_get_autoloads(args: Dictionary) -> Dictionary:
	if not _context: return {"error": "No context available"}
	return {"data": {"autoloads": _context._get_autoloads()}}

func _tool_get_dependencies(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not FileAccess.file_exists(path): return {"error": "File not found: " + path}
	var deps := ResourceLoader.get_dependencies(path)
	return {"data": deps}

func _tool_get_scene_info(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not _context: return {"error": "No context available"}
	return {"data": _context.get_scene_summary(path)}

func _tool_list_resources(args: Dictionary) -> Dictionary:
	var dir: String = args.get("dir", "res://")
	if not _context: return {"error": "No context available"}
	var results: Array = []
	_find_files_recursive(dir, ["tres", "res"], results)
	return {"data": results}

func _tool_inspect_resource(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not FileAccess.file_exists(path): return {"error": "Resource not found: " + path}
	# Read the .tres text format
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {"error": "Cannot open resource: " + path}
	return {"data": file.get_as_text().substr(0, 2000)}

func _tool_open_scene(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not _editor_integration: return {"error": "No editor integration"}
	_editor_integration.open_scene(path)
	return {"success": true}

func _tool_open_script(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not _editor_integration: return {"error": "No editor integration"}
	_editor_integration.open_script(path)
	return {"success": true}

func _tool_run_project(args: Dictionary) -> Dictionary:
	if not _editor_integration: return {"error": "No editor integration"}
	_editor_integration.run_project()
	return {"success": true}

func _tool_stop_project(args: Dictionary) -> Dictionary:
	if not _editor_integration: return {"error": "No editor integration"}
	var ei = _editor_integration.editor_interface
	if ei: ei.stop_playing_scene()
	return {"success": true}

func _tool_get_editor_state(args: Dictionary) -> Dictionary:
	if not _context: return {"error": "No context available"}
	return {"data": _context.get_editor_state()}

func _tool_update_blueprint(args: Dictionary) -> Dictionary:
	var content: String = args.get("content", "")
	if content.is_empty(): return {"error": "Missing content"}
	AIProjectBlueprint.update_blueprint(content)
	return {"success": true}

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _find_files_recursive(path: String, extensions: Array, results: Array) -> void:
	var dir := DirAccess.open(path)
	if not dir: return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := path.path_join(name)
			if dir.current_is_dir():
				_find_files_recursive(full, extensions, results)
			else:
				if name.get_extension() in extensions:
					results.append(full)
		name = dir.get_next()
