@tool
extends preload("base_rule.gd")
class_name AIMarkdownCodeBlockRule

var within_backtick_block := false
var within_tilde_block := false
var current_code_block_char_count: int

func reset() -> void:
	within_backtick_block = false
	within_tilde_block = false
	current_code_block_char_count = 0

func process_line(line: String) -> String:
	# Handle fenced code blocks:
	if not within_tilde_block and parser.denotes_fenced_code_block(line, "`"):
		if within_backtick_block:
			if parser.count_fence_chars(line.strip_edges(), "`") >= current_code_block_char_count:
				parser.converted_text = parser.converted_text.trim_suffix("\n")
				parser.current_paragraph -= 1
				parser.converted_text += "[/code]"
				within_backtick_block = false
				parser.debug("... closing backtick block")
				return "" # Indicate line was handled as a toggle
		else:
			parser.converted_text += "[code]"
			within_backtick_block = true
			current_code_block_char_count = parser.count_fence_chars(line.strip_edges(), "`")
			parser.debug("... opening backtick block")
			return "" # Indicate line was handled as a toggle
	elif not within_backtick_block and parser.denotes_fenced_code_block(line, "~"):
		if within_tilde_block:
			if parser.count_fence_chars(line.strip_edges(), "~") >= current_code_block_char_count:
				parser.converted_text = parser.converted_text.trim_suffix("\n")
				parser.current_paragraph -= 1
				parser.converted_text += "[/code]"
				within_tilde_block = false
				parser.debug("... closing tilde block")
				return ""
		else:
			parser.converted_text += "[code]"
			within_tilde_block = true
			current_code_block_char_count = parser.count_fence_chars(line.strip_edges(), "~")
			parser.debug("... opening tilde block")
			return ""
	
	if within_backtick_block or within_tilde_block:
		parser.converted_text += parser.escape_bbcode(line)
		return "" # Handled by the block
		
	# Process inline code (not a toggle, just a regular line transformation)
	return _process_inline_code_syntax(line)

func _process_inline_code_syntax(line: String) -> String:
	var regex := RegEx.create_from_string("(`+)(.+?)\\1")
	var processed_line := line
	while true:
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		var _end := result.get_end()
		var unescaped_content := parser.reset_escaped_chars(result.get_string(2), true)
		unescaped_content = parser.escape_bbcode(unescaped_content)
		unescaped_content = parser.escape_chars(unescaped_content)
		processed_line = processed_line.erase(_start, _end - _start).insert(_start, "[code]%s[/code]" % unescaped_content)
		parser.debug("... in-line code: " + unescaped_content)
	return processed_line
