@tool
extends preload("base_rule.gd")
class_name AIMarkdownHeaderRule

func process_line(line: String) -> String:
	var processed_line := line
	var regex := RegEx.create_from_string("^#+\\s*[^\\s].*")
	while true:
		var result := regex.search(processed_line)
		if not result:
			break
		var n := 0
		for _char in result.get_string():
			if _char != "#" or n == 6:
				break
			n += 1
		var n_spaces := 0
		for _char in result.get_string().substr(n):
			if _char != " ":
				break
			n_spaces += 1
		var header_format: Resource = parser.get_header_format(n)
		var _start := result.get_start()
		var opening_tags := parser.get_header_tags(header_format)
		processed_line = processed_line.erase(_start, n + n_spaces).insert(_start, opening_tags)
		var _end := result.get_end()
		processed_line = processed_line.insert(_end - (n + n_spaces) + opening_tags.length(), parser.get_header_tags(header_format, true))
		parser.debug("... header level %d" % n)
		parser.header_anchor_paragraph[parser.get_header_reference(result.get_string())] = parser.current_paragraph
		if header_format.get("draw_horizontal_rule"):
			var version := Engine.get_version_info()
			if version.hex >= 0x040500:
				processed_line += "\n[hr height=%d width=%d%% align=left color=%s]" % [
					parser.hr_height,
					parser.hr_width,
					parser.hr_color.to_html(),
				]
				parser.current_line += 1
				parser.current_paragraph += 1
	return processed_line
