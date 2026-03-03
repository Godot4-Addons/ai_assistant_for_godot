@tool
extends RefCounted
class_name AICodeValidator

static func validate_syntax(code: String) -> Dictionary:
	var res = {"valid": true, "errors": [], "warnings": []}
	var lines = code.split("\n")
	for i in range(lines.size()):
		var t = lines[i].strip_edges()
		if t.is_empty() or t.begins_with("#"): continue
		if (t.begins_with("func ") or t.begins_with("if ")) and not t.ends_with(":"):
			res.errors.append("Line " + str(i + 1) + ": Missing colon")
			res.valid = false
	return res

static func suggest_improvements(code: String) -> Array[String]:
	var res: Array[String] = []
	var lines = code.split("\n")
	for i in range(lines.size()):
		var t = lines[i].strip_edges()
		if t.length() > 100: res.append("Line " + str(i + 1) + " is too long")
		if "TODO" in t.to_upper(): res.append("TODO on line " + str(i + 1))
	return res
