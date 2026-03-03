@tool
extends RefCounted
class_name AICodeFormatter

static func format_for_ai(code: String, lang: String = "gdscript") -> String:
	return "```" + lang + "\n" + code.strip_edges() + "\n```"

static func extract_code(response: String) -> String:
	var regex = RegEx.new()
	regex.compile("```(?:gdscript|gd)?\\s*\\n([\\s\\S]*?)\\n```")
	var res = regex.search(response)
	if res: return res.get_string(1).strip_edges()
	
	var lines = response.split("\n")
	var code_lines = []
	var in_block = false
	for line in lines:
		var t = line.strip_edges()
		if t.begins_with("extends ") or t.begins_with("func ") or t.begins_with("var "):
			in_block = true
		if in_block:
			code_lines.append(line)
			if t.begins_with("This ") or t.begins_with("Here"): break
	return "\n".join(code_lines).strip_edges()

static func is_code(response: String) -> bool:
	for indicator in ["```", "extends ", "func ", "var ", "@export"]:
		if indicator.to_lower() in response.to_lower(): return true
	return false

static func clean_response(response: String) -> String:
	var cleaned = response.strip_edges()
	for prefix in ["Here's ", "Sure! ", "Certainly! "]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length())
			break
	return cleaned
