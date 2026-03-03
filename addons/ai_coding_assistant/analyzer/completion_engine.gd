@tool
extends RefCounted
class_name AICompletionEngine

static func get_completion_context(text: String, cursor_pos: int) -> Dictionary:
	var ctx = {"word": "", "line": "", "dot": false, "obj": ""}
	if cursor_pos <= 0: return ctx
	
	var lines = text.substr(0, cursor_pos).split("\n")
	var line = lines[-1]
	ctx.line = line
	
	var word_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
	var start = line.length()
	for i in range(line.length() - 1, -1, -1):
		if line[i] in word_chars: start = i
		else: break
	
	if start < line.length(): ctx.word = line.substr(start)
	
	var before = line.substr(0, start).strip_edges()
	if before.ends_with("."):
		ctx.dot = true
		var o_end = before.length() - 1
		var o_start = o_end
		for i in range(o_end - 1, -1, -1):
			if before[i] in word_chars: o_start = i
			else: break
		if o_start < o_end: ctx.obj = before.substr(o_start, o_end - o_start)
		
	return ctx

static func suggest(ctx: Dictionary, code_ctx: Dictionary) -> Array:
	if ctx.dot: return ["position", "rotation", "scale", "visible", "get_child", "add_child"]
	
	var all = ["func", "var", "if", "else", "return", "true", "false", "null", "self"]
	if "variables" in code_ctx:
		for v in code_ctx.variables: all.append(v.name)
	if "functions" in code_ctx:
		all.append_array(code_ctx.functions)
		
	if ctx.word.is_empty(): return all
	var res = []
	var partial = ctx.word.to_lower()
	for s in all:
		if s.to_lower().begins_with(partial): res.append(s)
	return res
