@tool
extends RefCounted
class_name AIAgentTools

# XML-based tool calling system
# <read_file path="res://test.gd" />
# <write_file path="res://test.gd">content</write_file>
# <patch_file path="res://test.gd" search="OLD_STRING" replace="NEW_STRING" />
# <delete_file path="res://test.gd" />
# <list_files path="res://" />
# <search_files pattern="MyClass" />
# <update_blueprint>content</update_blueprint>
# <open_scene path="res://main.tscn" />
# <open_script path="res://scripts/player.gd" />
# <run_project />

static func parse_and_execute(response: String, editor: Control) -> Array:
	var results = []
	var regex = RegEx.new()
	
	# Match <tool_name attr="val">content</tool_name> or <tool_name attr="val" />
	# Updated regex to handle multiple attributes more robustly
	regex.compile("<(\\w+)(\\s+[^>]+)?\\s*>(?:([\\s\\S]*?)</\\1>|/>)?")
	
	var matches = regex.search_all(response)
	for m in matches:
		var tool_name = m.get_string(1)
		var attrs_str = m.get_string(2)
		var content = m.get_string(3).strip_edges()
		
		var attrs = _parse_attributes(attrs_str)
		var result = _execute_tool(tool_name, attrs, content, editor)
		results.append(result)
		
	return results

static func _parse_attributes(attrs_str: String) -> Dictionary:
	var attrs = {}
	var regex = RegEx.new()
	regex.compile("(\\w+)=\"([^\"]*)\"")
	var matches = regex.search_all(attrs_str)
	for m in matches:
		attrs[m.get_string(1)] = m.get_string(2)
	return attrs

static func _execute_tool(tool: String, attrs: Dictionary, content: String, editor: Control) -> Dictionary:
	var ei = editor.editor_integration
	
	match tool:
		"read_file":
			var path = attrs.get("path", "")
			if path.is_empty(): return {"error": "Missing path attribute"}
			return {"tool": tool , "data": ei.read_file(path)}
			
		"write_file":
			var path = attrs.get("path", "")
			if path.is_empty(): return {"error": "Missing path attribute"}
			var ok = ei.write_file(path, content if not content.is_empty() else attrs.get("content", ""))
			return {"tool": tool , "success": ok}
		
		"patch_file":
			var path = attrs.get("path", "")
			var search = attrs.get("search", "")
			var replace = attrs.get("replace", "")
			
			if path.is_empty() or search.is_empty():
				if content.is_empty():
					return {"error": "Missing path or search attribute and content is empty"}
				else:
					replace = content
			var ok = ei.patch_file(path, search, replace)
			return {"tool": tool , "success": ok}
			
		"list_files":
			var path = attrs.get("path", "res://")
			return {"tool": tool , "data": ei.list_files(path)}
		
		"search_files":
			var pattern = attrs.get("pattern", "")
			var dir = attrs.get("dir", "res://")
			if pattern.is_empty(): return {"error": "Missing pattern attribute"}
			return {"tool": tool , "data": ei.search_files(pattern, dir)}
			
		"delete_file":
			var path = attrs.get("path", "")
			return {"tool": tool , "action": "request_delete", "path": path}
			
		"update_blueprint":
			AIProjectBlueprint.update_blueprint(content if not content.is_empty() else attrs.get("content", ""))
			return {"tool": tool , "success": true}
			
		"open_scene":
			var path = attrs.get("path", "")
			ei.open_scene(path)
			return {"tool": tool , "success": true}
			
		"open_script":
			var path = attrs.get("path", "")
			ei.open_script(path)
			return {"tool": tool , "success": true}
			
		"run_project":
			ei.run_project()
			return {"tool": tool , "success": true}
			
	return {"error": "Unknown tool: " + tool }
