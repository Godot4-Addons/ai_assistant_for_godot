@tool
extends RefCounted
class_name AIPermissionManager

## Permission system for destructive or risky agent operations.
## Provides configurable rules per tool and per path, with UI confirmation signals.

enum Permission {
	AUTO_ALLOW, ## Proceed silently
	WARN_AND_PROCEED, ## Show a note in chat but proceed
	ASK_USER, ## Emit signal for UI confirmation dialog
	DENY ## Block entirely
}

## Signal emitted when user confirmation is required.
## Caller must call pending_callback.call(true/false) within a reasonable time.
signal permission_requested(tool_name: String, args: Dictionary, description: String)

## Default per-tool permissions
var _tool_permissions: Dictionary = {
	"read_file": Permission.AUTO_ALLOW,
	"list_files": Permission.AUTO_ALLOW,
	"search_files": Permission.AUTO_ALLOW,
	"get_project_structure": Permission.AUTO_ALLOW,
	"get_project_settings": Permission.AUTO_ALLOW,
	"get_autoloads": Permission.AUTO_ALLOW,
	"get_dependencies": Permission.AUTO_ALLOW,
	"get_editor_state": Permission.AUTO_ALLOW,
	"read_scene_tree": Permission.AUTO_ALLOW,
	"get_scene_info": Permission.AUTO_ALLOW,
	"inspect_resource": Permission.AUTO_ALLOW,
	"list_resources": Permission.AUTO_ALLOW,
	"open_scene": Permission.AUTO_ALLOW,
	"open_script": Permission.AUTO_ALLOW,
	"patch_file": Permission.AUTO_ALLOW,
	"write_file": Permission.WARN_AND_PROCEED,
	"create_directory": Permission.WARN_AND_PROCEED,
	"create_resource": Permission.WARN_AND_PROCEED,
	"create_node": Permission.WARN_AND_PROCEED,
	"modify_node_property": Permission.WARN_AND_PROCEED,
	"update_blueprint": Permission.AUTO_ALLOW,
	"run_project": Permission.WARN_AND_PROCEED,
	"stop_project": Permission.AUTO_ALLOW,
	"delete_file": Permission.ASK_USER,
}

## Paths that always require user confirmation regardless of tool permission
var _protected_paths: Array[String] = [
	"project.godot",
	"export_presets.cfg",
	".godot/",
	"addons/",
]

## Paths that are fully denied
var _denied_paths: Array[String] = [
	"user://ai_agent_memory/", # Never let AI delete its own memory
]

## Set a custom permission level for a specific tool
func set_tool_permission(tool_name: String, perm: Permission) -> void:
	_tool_permissions[tool_name] = perm

## Check whether a tool action is allowed.
## Returns: { allowed: bool, needs_confirmation: bool, message: String }
func check(tool_name: String, args: Dictionary) -> Dictionary:
	var path: String = args.get("path", args.get("dir", ""))

	# Check denied paths first
	for denied in _denied_paths:
		if path.contains(denied):
			return {
				"allowed": false,
				"needs_confirmation": false,
				"message": "❌ Operation denied: path '%s' is protected." % path
			}

	# Overwrite protection for existing critical files
	if (tool_name == "write_file" or tool_name == "patch_file" or tool_name == "delete_file") and not path.is_empty():
		for protected in _protected_paths:
			if path.ends_with(protected) or path.contains(protected):
				return {
					"allowed": false,
					"needs_confirmation": true,
					"message": "⚠️ Protected path detected: '%s' requires explicit user confirmation." % path
				}

	var perm: Permission = _tool_permissions.get(tool_name, Permission.WARN_AND_PROCEED)

	match perm:
		Permission.AUTO_ALLOW:
			return {"allowed": true, "needs_confirmation": false, "message": ""}

		Permission.WARN_AND_PROCEED:
			var msg := _build_warn_message(tool_name, args)
			return {"allowed": true, "needs_confirmation": false, "message": msg}

		Permission.ASK_USER:
			return {
				"allowed": false,
				"needs_confirmation": true,
				"message": _build_warn_message(tool_name, args)
			}

		Permission.DENY:
			return {
				"allowed": false,
				"needs_confirmation": false,
				"message": "❌ Tool '%s' is disabled by policy." % tool_name
			}

	return {"allowed": true, "needs_confirmation": false, "message": ""}

## Called by UI to confirm or deny a pending operation.
## Returns a callable that the UI should call with true/false.
func request_confirmation(tool_name: String, args: Dictionary, description: String) -> void:
	permission_requested.emit(tool_name, args, description)

func _build_warn_message(tool_name: String, args: Dictionary) -> String:
	var path: String = args.get("path", args.get("dir", ""))
	match tool_name:
		"write_file":
			return "📝 Writing file: %s" % path
		"delete_file":
			return "🗑️ Deleting file: %s — are you sure?" % path
		"create_directory":
			return "📁 Creating directory: %s" % path
		"run_project":
			return "▶️ Running the project"
		"create_node":
			return "🌿 Creating node: %s" % args.get("node_name", "unknown")
		"modify_node_property":
			return "✏️ Modifying node property: %s.%s" % [args.get("node_path", ""), args.get("property", "")]
		_:
			return "🔧 Executing: %s %s" % [tool_name, JSON.stringify(args)]
