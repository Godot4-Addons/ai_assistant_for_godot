@tool
extends preload("base_rule.gd")
class_name AIMarkdownInlineRule

func process_line(line: String) -> String:
	var processed_line := line
	processed_line = _process_image_syntax(processed_line)
	processed_line = _process_link_syntax(processed_line)
	processed_line = _process_hr_syntax(processed_line)
	processed_line = _process_text_formatting_syntax(processed_line)
	return processed_line

func _process_image_syntax(line: String) -> String:
	var processed_line := line
	var regex := RegEx.new()
	while true:
		regex.compile("\\!\\[(.*?)\\]\\((.*?)\\)")
		var result := regex.search(processed_line)
		if not result:
			break
		var found_proper_match := false
		var _start := result.get_start()
		var _end := result.get_end()
		regex.compile("\\[(.*?)\\]")
		var texts := regex.search_all(result.get_string())
		for _text in texts:
			if result.get_string()[_text.get_end()] != "(":
				continue
			found_proper_match = true
			var alt_text := result.get_string(1)
			# Check if link has a title:
			regex.compile("\\\"(.*?)\\\"")
			var title_result := regex.search(result.get_string(2))
			var title: String
			var url := result.get_string(2)
			if title_result:
				title = title_result.get_string(1)
				url = url.rstrip(" ").trim_suffix(title_result.get_string()).rstrip(" ")
			url = parser._escape_chars(url)
			processed_line = processed_line.erase(_start, _end - _start).insert(_start, "[img%s%s]%s[/img]" % [
				" alt=\"%s\"" % alt_text if alt_text else "",
				" tooltip=\"%s\"" % title if title_result and title else "",
				url,
			])
			parser._debug("... image: " + result.get_string())
			break
		if not found_proper_match:
			break
	return processed_line

func _process_link_syntax(line: String) -> String:
	var processed_line := line
	var regex := RegEx.new()
	while true:
		regex.compile("\\[(.*?)\\]\\((.*?)\\)")
		var result := regex.search(processed_line)
		if not result:
			break
		var found_proper_match := false
		var _start := result.get_start()
		var _end := result.get_end()
		regex.compile("\\[(.*?)\\]")
		var texts := regex.search_all(result.get_string())
		for _text in texts:
			if result.get_string()[_text.get_end()] != "(":
				continue
			found_proper_match = true
			# Check if link has a title:
			regex.compile("\\\"(.*?)\\\"")
			var title_result := regex.search(result.get_string(2))
			var title: String
			var url := result.get_string(2)
			if title_result:
				title = title_result.get_string(1)
				url = url.rstrip(" ").trim_suffix(title_result.get_string()).rstrip(" ")
			url = parser._escape_chars(url)
			processed_line = processed_line.erase(
				_start + _text.get_start(),
				_end - _start - _text.get_start()
			).insert(
				_start + _text.get_start(),
				"[url=%s]%s[/url]" % [url, _text.get_string(1)]
			)
			if title_result and title:
				processed_line = processed_line.insert(
					_start + _text.get_start() + 12 + url.length() + _text.get_string(1).length(),
					"[/hint]"
				).insert(_start + _text.get_start(), "[hint=%s]" % title)
			parser._debug("... hyperlink: " + result.get_string())
			break
		if not found_proper_match:
			break
	while true:
		regex.compile("\\<(.*?)\\>")
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		var _end := result.get_end()
		var url := result.get_string(1)
		regex.compile("^\\s*?([^\\s]+\\@[^\\s]+\\.[^\\s]+)\\s*?$")
		var mail := regex.search(result.get_string(1))
		if mail:
			url = mail.get_string(1)
		url = parser._escape_chars(url)
		if mail:
			processed_line = processed_line.erase(_start, _end - _start).insert(_start, "[url=mailto:%s]%s[/url]" % [url, url])
			parser._debug("... mail link: " + result.get_string())
		else:
			processed_line = processed_line.erase(_start, _end - _start).insert(_start, "[url]%s[/url]" % url)
			parser._debug("... explicit link: " + result.get_string())
	return processed_line

func _process_text_formatting_syntax(line: String) -> String:
	var processed_line := line
	# Bold text
	var regex := RegEx.create_from_string("(\\*\\*|\\_\\_)(.+?)\\1")
	while true:
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		var _end := result.get_end()
		processed_line = processed_line.erase(_start, 2).insert(_start, "[b]")
		processed_line = processed_line.erase(_end - 1, 2).insert(_end - 1, "[/b]")
		parser._debug("... bold text: " + result.get_string(2))
	
	# Italic text
	while true:
		regex.compile("(\\*|_)(.+?)\\1")
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		var _end := result.get_end()
		# Sanitize nested bold+italics (Godot-specific, b and i tags must not be intertwined):
		var result_string := result.get_string(2)
		var open_b := false
		var close_b := false
		if result_string.begins_with("[b]") and result_string.find("[/b]") == -1:
			open_b = true
		elif result_string.ends_with("[/b]") and result_string.find("[b]") == -1:
			close_b = true
		if open_b:
			processed_line = processed_line.erase(_start, 4).insert(_start, "[b][i]")
			processed_line = processed_line.erase(_end - 2, 1).insert(_end - 2, "[/i]")
		elif close_b:
			processed_line = processed_line.erase(_start, 1).insert(_start, "[i]")
			processed_line = processed_line.erase(_end - 3, 5).insert(_end - 3, "[/i][/b]")
		else:
			processed_line = processed_line.erase(_start, 1).insert(_start, "[i]")
			processed_line = processed_line.erase(_end + 1, 1).insert(_end + 1, "[/i]")
		parser._debug("... italic text: " + result.get_string(2))
	
	# Strike-through text
	regex.compile("(\\~\\~)(.+?)\\1")
	while true:
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		processed_line = processed_line.erase(_start, 2).insert(_start, "[s]")
		var _end := result.get_end()
		processed_line = processed_line.erase(_end - 1, 2).insert(_end - 1, "[/s]")
		parser._debug("... strike-through text: " + result.get_string(2))
	
	return processed_line

func _process_hr_syntax(line: String) -> String:
	var version := Engine.get_version_info()
	if version.hex < 0x040500:
		return line
	var processed_line := line
	var regex := RegEx.create_from_string(r"^[ ]{0,3}([\-_*])\1{2,}\s*$")
	var result := regex.search(processed_line)
	if result:
		processed_line = "[hr height=%d width=%d%% align=%s color=%s]" % [
			parser.hr_height,
			parser.hr_width,
			parser.hr_alignment,
			parser.hr_color.to_html(),
		]
		parser._debug("... horizontal rule")
	return processed_line
