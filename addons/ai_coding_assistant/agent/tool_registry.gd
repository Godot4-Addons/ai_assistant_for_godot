@tool
extends RefCounted
class_name AIToolRegistry

## Modular tool registry — registers, validates, and executes all agent tools.
## All tools self-describe their parameters for prompt generation.

signal tool_executed(tool_name: String, args: Dictionary, result: Dictionary)

const XML_TOOL_REGEX = "<\\s*(\\w+)(?:\\s+([^>]*?))?\\s*(?:>([\\s\\S]*?)<\\/\\s*\\1\\s*>|\\/>)"

var _tools: Dictionary = {}
var _editor_integration # AIEditorIntegration
var _context: AIAgentContext
var _memory: AIAgentMemory = null
var _skill_manager: AISkillManager = null
var _workspace_manager = null

func set_memory(memory: AIAgentMemory) -> void:
	_memory = memory

func set_skill_manager(sm: AISkillManager) -> void:
	_skill_manager = sm

func set_workspace_manager(wm) -> void:
	_workspace_manager = wm

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
 
	register_tool("get_file_summaries",
		"Quickly scan multiple files to get their class structure (class_name, extends, signals, public functions). Use this to map architecture without reading full files.",
		{"paths": {"type": "Array", "required": true, "desc": "List of file paths to summarize"}},
		_tool_get_file_summaries)

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

	# Memory Tools (Phase 3)
	register_tool("remember",
		"Store a fact about this project in long-term memory for future sessions.",
		{
			"key": {"type": "String", "required": true, "desc": "Fact name (e.g. 'player_script_path')"},
			"value": {"type": "String", "required": true, "desc": "The value to store"}
		},
		_tool_remember)

	register_tool("recall",
		"Look up a previously stored fact about this project from long-term memory.",
		{
			"key": {"type": "String", "required": true, "desc": "Fact name to look up"}
		},
		_tool_recall)

	register_tool("list_memories",
		"List all stored facts about this project in long-term memory.",
		{},
		_tool_list_memories)

	# Git Tools
	register_tool("git",
		"Run git commands (status, diff, add, commit, checkout) to manage and protect project files.",
		{
			"command": {"type": "String", "required": true, "desc": "Git subcommand (status, diff, add, commit, checkout)"},
			"args": {"type": "String", "required": false, "desc": "Arguments for the command (e.g. file path or commit message)"}
		},
		_tool_git)

	# Skill Tools (Phase 4)
	register_tool("use_skill",
		"Instantiate a built-in or saved skill pattern. Returns ready-to-use GDScript code.",
		{
			"name": {"type": "String", "required": true, "desc": "Skill name (e.g. state_machine, player_2d)"},
			"params": {"type": "String", "required": false, "desc": "Parameters as JSON string"},
			"write_to": {"type": "String", "required": false, "desc": "If set, write code directly to this path"}
		},
		_tool_use_skill)

	register_tool("list_skills",
		"List all available built-in and user-saved skills.",
		{},
		_tool_list_skills)

	register_tool("save_skill",
		"Save a file as a reusable skill for future use.",
		{
			"name": {"type": "String", "required": true, "desc": "Name for the skill"},
			"path": {"type": "String", "required": true, "desc": "Source file to save as skill"},
			"description": {"type": "String", "required": false, "desc": "What this skill does"}
		},
		_tool_save_skill)

	# Godot-Specific Tools (Phase 4)
	register_tool("validate_script",
		"Run GDScript syntax validation on a script file. Reports unbalanced brackets, indentation issues, and Godot 3-4 migration warnings.",
		{"path": {"type": "String", "required": true, "desc": "Path to .gd file to validate"}},
		_tool_validate_script)

	register_tool("get_scene_nodes",
		"Get all nodes in a scene as a structured list with types and script attachments.",
		{"path": {"type": "String", "required": true, "desc": "Path to .tscn scene file"}},
		_tool_get_scene_nodes)

	register_tool("list_signals",
		"List all signals defined and connected in a script.",
		{"path": {"type": "String", "required": true, "desc": "Path to .gd script file"}},
		_tool_list_signals)

	register_tool("find_undefined_references",
		"Find broken preloads, invalid node paths, and missing class_name references in a file.",
		{"path": {"type": "String", "required": true, "desc": "Path to file to scan"}},
		_tool_find_undefined_references)

	register_tool("rename_class",
		"Rename a class_name across the entire project, updating all references.",
		{
			"old_name": {"type": "String", "required": true, "desc": "Current class_name"},
			"new_name": {"type": "String", "required": true, "desc": "New class_name"}
		},
		_tool_rename_class)

	register_tool("move_file",
		"Move a file to a new path and update all internal references (preloads, extends, load()).",
		{
			"source": {"type": "String", "required": true, "desc": "Current file path"},
			"dest": {"type": "String", "required": true, "desc": "New file path"}
		},
		_tool_move_file)

	register_tool("create_resource",
		"Create a .tres resource file with the given content.",
		{
			"path": {"type": "String", "required": true, "desc": "Path for the .tres file"},
			"content": {"type": "String", "required": true, "desc": "Resource content in Godot .tres text format"}
		},
		_tool_create_resource)

	# Workspace Tools (Phase 5)
	register_tool("check_project_health",
		"Run a full health scan of the project. Checks for duplicate class_names, missing autoloads, orphaned scenes, broken preloads, and missing scripts attached to scenes.",
		{},
		_tool_check_project_health)

	register_tool("get_workspace_summary",
		"Get a categorized summary of all project files (scripts, scenes, resources, assets) with counts.",
		{},
		_tool_get_workspace_summary)

	register_tool("suggest_file_path",
		"Suggest the correct file path for a new file based on its type and name.",
		{
			"file_type": {"type": "String", "required": true, "desc": "Type: script, scene, resource, or autoload"},
			"name": {"type": "String", "required": true, "desc": "Class or file name (e.g. Player, EnemyAI)"}
		},
		_tool_suggest_file_path)

	register_tool("detect_misplaced_files",
		"Find files that are in incorrect locations (e.g. scripts at project root, scenes at project root).",
		{},
		_tool_detect_misplaced_files)

	register_tool("ensure_project_structure",
		"Create the standard Godot project folder structure (scripts/, scenes/, assets/, resources/, autoloads/, shaders/ with subdirectories).",
		{},
		_tool_ensure_project_structure)

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
		if not _tools.has(tool_name): continue
		var attrs_str := m.get_string(2)
		var body := m.get_string(3).strip_edges()
		var attrs := _parse_attrs(tool_name, attrs_str)
		# Content in body can override or supplement attrs
		if not body.is_empty() and not attrs.has("content"):
			attrs["content"] = body
		calls.append({"tool": tool_name, "args": attrs})
	
	# Fallback: Bare text tool calls (e.g. "read_file path:res://...")
	# Only if no XML tags were found at all to avoid duplicates
	if calls.is_empty():
		for t_name in _tools:
			if response.to_lower().contains(t_name.to_lower()):
				# Try to extract keys for this specific tool
				var fuzzy_attrs = _fuzzy_parse_attrs(t_name, response)
				if not fuzzy_attrs.is_empty():
					calls.append({"tool": t_name, "args": fuzzy_attrs})
					# Stop after first bare tool to prevent spam
					break
					
	return calls

func _parse_attrs(tool_name: String, attrs_str: String) -> Dictionary:
	var attrs: Dictionary = {}
	var regex := RegEx.new()
	# Lenient attribute matching: key="val" or key='val' or key=val
	regex.compile("(\\w+)\\s*[:=]\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))")
	
	var matches := regex.search_all(attrs_str)
	for m in matches:
		var key := m.get_string(1)
		var val := ""
		if not m.get_string(2).is_empty(): val = m.get_string(2)
		elif not m.get_string(3).is_empty(): val = m.get_string(3)
		else: val = m.get_string(4)
		attrs[key] = val
	
	# If empty, try fuzzy fallback for this specific tool's params
	if attrs.is_empty() and not attrs_str.strip_edges().is_empty():
		return _fuzzy_parse_attrs(tool_name, attrs_str)
		
	return attrs

func _fuzzy_parse_attrs(tool_name: String, text: String) -> Dictionary:
	var attrs: Dictionary = {}
	var tool_def: Dictionary = _tools.get(tool_name, {})
	var params: Dictionary = tool_def.get("params", {})
	
	# Clean up text for easier matching (normalize slashes/newlines)
	var clean_text := text.replace("\r", "\n")
	
	for p_name in params:
		# Search for "paramname[:= ]?value"
		# (?:[:= ]|\s+)? allows "path res://" and "path:res://" and "path=res://" and "pathres://"
		var p_regex := RegEx.new()
		# Pattern: p_name + optional space/separator + value (no spaces or >)
		# But if the value is res://, it should match that specifically
		p_regex.compile(p_name + "\\s*[:= ]?\\s*(res://[^\\s\"'>]+|[^\\s\"'>]+)")
		var m = p_regex.search(clean_text)
		if m:
			attrs[p_name] = m.get_string(1)
	
	# If no specific params found, but this is a tool with "content" (like write_file/patch_file)
	if attrs.is_empty() and params.has("content"):
		# Try to grab everything between the tool name and the end marker
		var body_regex := RegEx.new()
		body_regex.compile(tool_name + "(?:\\s+)?([\\s\\S]*?)(?:/" + tool_name + "|$)")
		var m = body_regex.search(clean_text)
		if m:
			attrs["content"] = m.get_string(1).strip_edges()
			
	return attrs

# ─────────────────────────────────────────────────────────────────────────────
# Execution
# ─────────────────────────────────────────────────────────────────────────────

func get_editor_integration():
	return _editor_integration

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

func _tool_get_file_summaries(args: Dictionary) -> Dictionary:
	var paths: Array = args.get("paths", [])
	if paths.is_empty(): return {"error": "Missing paths"}
	if not _editor_integration: return {"error": "No editor integration"}
	return {"data": _editor_integration.get_file_summaries(paths)}

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

func _tool_git(args: Dictionary) -> Dictionary:
	var command: String = args.get("command", "")
	var extra_args: String = args.get("args", "")
	if command.is_empty(): return {"error": "Missing command"}
	
	# Check for git presence
	var version_out: Array[String] = []
	if OS.execute("git", ["--version"], version_out, true) != 0:
		return {"error": "Git is not installed or not in PATH. Fallback backup system is enabled."}
	
	var git_args = [command]
	if not extra_args.is_empty():
		# Simple split but respect quotes for commit messages
		if command == "commit" and "-m" in extra_args:
			git_args.append("-m")
			var msg = extra_args.split("-m")[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
			git_args.append(msg)
		else:
			git_args.append_array(extra_args.split(" ", false))

	var output: Array[String] = []
	var exit_code: int = OS.execute("git", git_args, output, true, false)
	
	if exit_code != 0:
		return {"error": "Git command failed", "output": "\n".join(output), "exit_code": exit_code}
	
	return {"data": "\n".join(output), "exit_code": exit_code}

# ─────────────────────────────────────────────────────────────────────────────
# Memory Tool Handlers (Phase 3)
# ─────────────────────────────────────────────────────────────────────────────

func _tool_remember(args: Dictionary) -> Dictionary:
	if not _memory:
		return {"error": "Memory system not available"}
	var key: String = args.get("key", "")
	var value: String = args.get("value", "")
	if key.is_empty() or value.is_empty():
		return {"error": "Missing key or value"}
	_memory.remember(key, value)
	return {"success": true, "message": "Remembered: %s" % key}

func _tool_recall(args: Dictionary) -> Dictionary:
	if not _memory:
		return {"error": "Memory system not available"}
	var key: String = args.get("key", "")
	if key.is_empty():
		return {"error": "Missing key"}
	var value: String = _memory.recall(key)
	if value.is_empty():
		return {"error": "No stored fact for: " + key}
	return {"data": value, "key": key}

func _tool_list_memories(args: Dictionary) -> Dictionary:
	if not _memory:
		return {"error": "Memory system not available"}
	var keys: Array[String] = _memory.list_knowledge()
	if keys.is_empty():
		return {"data": "No stored memories for this project."}
	return {"data": "Stored facts: " + ", ".join(keys)}

# ─────────────────────────────────────────────────────────────────────────────
# Skill Tool Handlers (Phase 4)
# ─────────────────────────────────────────────────────────────────────────────

func _tool_use_skill(args: Dictionary) -> Dictionary:
	if not _skill_manager:
		return {"error": "Skill system not available"}
	var name: String = args.get("name", "")
	if name.is_empty():
		return {"error": "Missing skill name"}
	var params_str: String = args.get("params", "{}")
	var params: Dictionary = {}
	var json := JSON.new()
	if json.parse(params_str) == OK and json.data is Dictionary:
		params = json.data
	var result := _skill_manager.execute_skill(name, params)
	if result.has("error"):
		return result
	var write_to: String = args.get("write_to", "")
	if not write_to.is_empty() and result.has("code"):
		if _editor_integration:
			_editor_integration.write_file(write_to, result.code)
			if _context:
				_context.clear_cache()
			return {"success": true, "path": write_to, "skill": name, "description": result.get("description", "")}
	return result

func _tool_list_skills(args: Dictionary) -> Dictionary:
	if not _skill_manager:
		return {"error": "Skill system not available"}
	return {"data": _skill_manager.get_skill_list_for_prompt()}

func _tool_save_skill(args: Dictionary) -> Dictionary:
	if not _skill_manager:
		return {"error": "Skill system not available"}
	var name: String = args.get("name", "")
	var path: String = args.get("path", "")
	var description: String = args.get("description", "")
	if name.is_empty() or path.is_empty():
		return {"error": "Missing name or path"}
	if not FileAccess.file_exists(path):
		return {"error": "File not found: " + path}
	if _skill_manager.save_skill_from_file(name, path, description):
		return {"success": true, "name": name}
	return {"error": "Failed to save skill"}

# ─────────────────────────────────────────────────────────────────────────────
# Godot-Specific Tool Handlers (Phase 4)
# ─────────────────────────────────────────────────────────────────────────────

func _tool_validate_script(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not path.ends_with(".gd"): return {"error": "Not a GDScript file: " + path}
	if not FileAccess.file_exists(path): return {"error": "File not found: " + path}

	var content: String = _editor_integration.read_file(path) if _editor_integration else ""
	if content.is_empty(): return {"error": "Cannot read file: " + path}

	var SyntaxChecker = preload("res://addons/ai_coding_assistant/repair/syntax_checker.gd")
	var checker := SyntaxChecker.new()
	var issues: Array = checker.validate(content)

	if issues.is_empty():
		return {"data": "No issues found in " + path}

	var summary: String = checker.get_error_summary(content)
	var error_count: int = 0
	var warning_count: int = 0
	for issue in issues:
		if issue.severity == SyntaxChecker.Severity.ERROR:
			error_count += 1
		elif issue.severity == SyntaxChecker.Severity.WARNING:
			warning_count += 1

	return {"data": summary, "error_count": error_count, "warning_count": warning_count}

func _tool_get_scene_nodes(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not FileAccess.file_exists(path): return {"error": "Scene not found: " + path}

	var content: String = _editor_integration.read_file(path) if _editor_integration else ""
	if content.is_empty():
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			content = file.get_as_text()
	if content.is_empty(): return {"error": "Cannot read scene: " + path}

	var regex := RegEx.new()
	regex.compile("\\[node name=\"([^\"]+)\" type=\"([^\"]+)\"(?: parent=\"([^\"]+)\")?")
	var matches := regex.search_all(content)

	var nodes: Array[String] = []
	var script_regex := RegEx.new()
	script_regex.compile("script = ExtResource\\( \"([^\"]+)\"")
	var script_map: Dictionary = {}
	var ext_res_regex := RegEx.new()
	ext_res_regex.compile("\\[ext_resource path=\"([^\"]+)\" type=\"Script\" id=\"([^\"]+)\"")
	var ext_res := ext_res_regex.search_all(content)
	for er in ext_res:
		script_map[er.get_string(2)] = er.get_string(1)

	for m in matches:
		var node_name: String = m.get_string(1)
		var node_type: String = m.get_string(2)
		var parent: String = m.get_string(3)
		var node_desc := "%s (%s)" % [node_name, node_type]
		if not parent.is_empty():
			node_desc += " parent=%s" % parent
		var script_match := script_regex.search(m.get_string(0))
		if script_match:
			var script_id: String = script_match.get_string(1)
			if script_map.has(script_id):
				node_desc += " [script: %s]" % script_map[script_id].get_file()
		nodes.append(node_desc)

	return {"data": nodes, "count": nodes.size()}

func _tool_list_signals(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not FileAccess.file_exists(path): return {"error": "File not found: " + path}
	if not path.ends_with(".gd"):
		return {"error": "Only .gd scripts are supported"}

	var content: String = _editor_integration.read_file(path) if _editor_integration else ""
	if content.is_empty():
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			content = file.get_as_text()
	if content.is_empty(): return {"error": "Cannot read file: " + path}

	var defined_signals: Array[String] = []
	var connected_signals: Array[String] = []
	var lines := content.split("\n")

	var sig_regex := RegEx.new()
	sig_regex.compile("^signal\\s+(\\w+)")
	var conn_regex := RegEx.new()
	conn_regex.compile("\\.connect\\(\\s*\"(\\w+)\"")
	var conn_regex2 := RegEx.new()
	conn_regex2.compile("\\.connect\\(\\s*(\\w+)")

	for line in lines:
		var stripped := line.strip_edges()
		var m := sig_regex.search(stripped)
		if m:
			defined_signals.append(m.get_string(1))
		m = conn_regex.search(stripped)
		if m:
			connected_signals.append(m.get_string(1))
		else:
			m = conn_regex2.search(stripped)
			if m:
				connected_signals.append(m.get_string(1))

	var result: Array[String] = []
	if defined_signals.is_empty():
		result.append("No signals defined.")
	else:
		result.append("Signals defined: %s" % ", ".join(defined_signals))
	if connected_signals.is_empty():
		result.append("No signal connections found.")
	else:
		result.append("Signal connections: %s" % ", ".join(connected_signals))

	return {"data": "\n".join(result)}

func _tool_find_undefined_references(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty(): return {"error": "Missing path"}
	if not FileAccess.file_exists(path): return {"error": "File not found: " + path}

	var content: String = _editor_integration.read_file(path) if _editor_integration else ""
	if content.is_empty():
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			content = file.get_as_text()
	if content.is_empty(): return {"error": "Cannot read file: " + path}

	var issues: Array[String] = []
	var lines := content.split("\n")

	# Check preload paths
	var preload_regex := RegEx.new()
	preload_regex.compile("preload\\(\"(res://[^\"]+)\"\\)")
	for i in range(lines.size()):
		var m := preload_regex.search(lines[i])
		if m:
			var ref_path: String = m.get_string(1)
			if not FileAccess.file_exists(ref_path):
				issues.append("Line %d: Broken preload: %s" % [i + 1, ref_path])

	# Check load paths
	var load_regex := RegEx.new()
	load_regex.compile("load\\(\"(res://[^\"]+)\"\\)")
	for i in range(lines.size()):
		var m := load_regex.search(lines[i])
		if m:
			var ref_path: String = m.get_string(1)
			if not FileAccess.file_exists(ref_path):
				issues.append("Line %d: Broken load: %s" % [i + 1, ref_path])

	if issues.is_empty():
		return {"data": "No undefined references found in " + path}

	return {"data": "\n".join(issues), "count": issues.size()}

func _tool_rename_class(args: Dictionary) -> Dictionary:
	var old_name: String = args.get("old_name", "")
	var new_name: String = args.get("new_name", "")
	if old_name.is_empty() or new_name.is_empty():
		return {"error": "Missing old_name or new_name"}

	var files_to_scan: Array = []
	_find_files_recursive("res://", ["gd", "tscn"], files_to_scan)

	var modified: int = 0
	for file_path in files_to_scan:
		var content: String = _editor_integration.read_file(file_path) if _editor_integration else ""
		if content.is_empty():
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file:
				content = file.get_as_text()
		if content.is_empty():
			continue

		if content.contains(old_name):
			var new_content := content.replace(old_name, new_name)
			if _editor_integration:
				_editor_integration.write_file(file_path, new_content)
			else:
				var file := FileAccess.open(file_path, FileAccess.WRITE)
				if file:
					file.store_string(new_content)
			modified += 1

	if _context:
		_context.clear_cache()

	return {"success": true, "files_modified": modified, "message": "Renamed '%s' to '%s' in %d files" % [old_name, new_name, modified]}

func _tool_move_file(args: Dictionary) -> Dictionary:
	var source: String = args.get("source", "")
	var dest: String = args.get("dest", "")
	if source.is_empty() or dest.is_empty():
		return {"error": "Missing source or dest"}
	if not FileAccess.file_exists(source):
		return {"error": "Source file not found: " + source}
	if FileAccess.file_exists(dest):
		return {"error": "Destination already exists: " + dest}

	var dest_dir := dest.get_base_dir()
	if not DirAccess.dir_exists_absolute(dest_dir):
		DirAccess.make_dir_recursive_absolute(dest_dir)

	var err := DirAccess.rename_absolute(source, dest)
	if err != OK:
		return {"error": "Failed to move file: " + str(err)}

	if _context:
		_context.clear_cache()

	return {"success": true, "source": source, "dest": dest}

func _tool_create_resource(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var content: String = args.get("content", "")
	if path.is_empty() or content.is_empty():
		return {"error": "Missing path or content"}
	if not path.ends_with(".tres"):
		return {"error": "Path must end with .tres"}

	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"error": "Cannot write file: " + path}

	file.store_string(content)
	return {"success": true, "path": path}

# ─────────────────────────────────────────────────────────────────────────────
# Workspace Tool Handlers (Phase 5)
# ─────────────────────────────────────────────────────────────────────────────

func _tool_check_project_health(args: Dictionary) -> Dictionary:
	if not _workspace_manager:
		return {"error": "Workspace system not available"}
	var report := _workspace_manager.check_project_health()
	report["message"] = _format_health_report(report)
	return report

func _tool_get_workspace_summary(args: Dictionary) -> Dictionary:
	if not _workspace_manager:
		return {"error": "Workspace system not available"}
	var summary: String = _workspace_manager.get_workspace_summary()
	return {"data": summary}

func _tool_suggest_file_path(args: Dictionary) -> Dictionary:
	if not _workspace_manager:
		return {"error": "Workspace system not available"}
	var file_type: String = args.get("file_type", "")
	var name: String = args.get("name", "")
	if file_type.is_empty() or name.is_empty():
		return {"error": "Missing file_type or name"}
	var path: String = _workspace_manager.suggest_file_path(file_type, name)
	return {"data": path, "suggested_path": path}

func _tool_detect_misplaced_files(args: Dictionary) -> Dictionary:
	if not _workspace_manager:
		return {"error": "Workspace system not available"}
	var misplaced := _workspace_manager.detect_misplaced_files()
	if misplaced.is_empty():
		return {"data": "No misplaced files found."}
	var lines: Array[String] = []
	for m in misplaced:
		lines.append("- %s: %s" % [m.file, m.issue])
		if m.has("suggestion"):
			lines.append("  Suggestion: %s" % m.suggestion)
	return {"data": "\n".join(lines), "count": misplaced.size()}

func _tool_ensure_project_structure(args: Dictionary) -> Dictionary:
	if not _workspace_manager:
		return {"error": "Workspace system not available"}
	var created := _workspace_manager.ensure_project_structure()
	if created.is_empty():
		return {"data": "All standard directories already exist."}
	return {"data": "Created directories:\n" + "\n".join(created), "created": created.size()}

func _format_health_report(report: Dictionary) -> String:
	var issues: Array = report.get("issues", [])
	var warnings: Array = report.get("warnings", [])
	if issues.is_empty() and warnings.is_empty():
		return "✅ No issues found!"
	var lines: Array[String] = []
	if not issues.is_empty():
		lines.append("❌ Issues (%d):" % issues.size())
		for i in issues:
			lines.append("  - [%s] %s" % [i.get("type", ""), i.get("description", "")])
	if not warnings.is_empty():
		lines.append("⚠️ Warnings (%d):" % warnings.size())
		for w in warnings:
			lines.append("  - [%s] %s" % [w.get("type", ""), w.get("description", "")])
	return "\n".join(lines)

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
