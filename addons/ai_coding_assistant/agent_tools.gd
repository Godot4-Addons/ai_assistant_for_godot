@tool
extends RefCounted
class_name AIAgentTools

# XML-based tool calling system
# <read_file path="res://test.gd" />
# <write_file path="res://test.gd">content</write_file>
# <delete_file path="res://test.gd" />
# <list_files path="res://" />
# <update_blueprint>content</update_blueprint>

static func parse_and_execute(response: String, editor: Control) -> Array:
	var results = []
	var regex = RegEx.new()
	
	# Match <tool_name attr="val">content</tool_name> or <tool_name attr="val" />
	# This is a broad regex to catch various tool tags
	regex.compile("<(\\w+)(?:\\s+(\\w+)=\"([^\"]+)\")?\\s*>(?:([\\s\\S]*?)</\\1>|/>)?")
	
	var matches = regex.search_all(response)
	for m in matches:
		var tool_name = m.get_string(1)
		var attr_name = m.get_string(2)
		var attr_val = m.get_string(3)
		var content = m.get_string(4).strip_edges()
		
		var result = _execute_tool(tool_name, attr_name, attr_val, content, editor)
		results.append(result)
		
	return results

static func _execute_tool(tool: String, attr: String, val: String, content: String, editor: Control) -> Dictionary:
	var ei = editor.editor_integration
	
	match tool:
		"read_file":
			var path = val if attr == "path" else ""
			if path.is_empty(): return {"error": "Missing path attribute"}
			return {"tool": tool , "data": ei.read_file(path)}
			
		"write_file":
			var path = val if attr == "path" else ""
			if path.is_empty(): return {"error": "Missing path attribute"}
			var ok = ei.write_file(path, content)
			return {"tool": tool , "success": ok}
			
		"list_files":
			var path = val if attr == "path" else "res://"
			return {"tool": tool , "data": ei.list_files(path)}
			
		"delete_file":
			var path = val if attr == "path" else ""
			# TODO: Permission check
			return {"tool": tool , "action": "request_delete", "path": path}
			
		"update_blueprint":
			AIProjectBlueprint.update_blueprint(content)
			return {"tool": tool , "success": true}
			
	return {"error": "Unknown tool: " + tool }
