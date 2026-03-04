@tool
extends RefCounted
class_name AIMarkdownParser

## Dedicated parser for converting Markdown to BBCode.
## Extracted from the MarkdownLabel component.

# ─────────────────────────────────────────────────────────────────────────────
# Constants (Moved from MarkdownLabel)
# ─────────────────────────────────────────────────────────────────────────────

const _ESCAPE_PLACEHOLDER := ";$\uFFFD:%s$;"
const _ESCAPEABLE_CHARACTERS := "\\*_~`[]()\"<>#-+.!"
const _ESCAPEABLE_CHARACTERS_REGEX := "[\\\\\\*\\_\\~`\\[\\]\\(\\)\\\"\\<\\>#\\-\\+\\.\\!]"
const _CHECKBOX_KEY := "markdownlabel-checkbox"

# ─────────────────────────────────────────────────────────────────────────────
# State (Used during parsing)
# ─────────────────────────────────────────────────────────────────────────────

var _converted_text: String
var _indent_level: int
var _escaped_characters_map := {}
var _current_paragraph: int = 0
var _header_anchor_paragraph := {}
var _within_table := false
var _table_row := -1
var _skip_line_break := false
var _checkbox_id: int = 0
var _current_line: int = 0
var checkbox_record := {}
var _debug_mode := false

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

var h1: Resource
var h2: Resource
var h3: Resource
var h4: Resource
var h5: Resource
var h6: Resource

var base_font_size: int = 16

var unchecked_item_character: String = "☐"
var checked_item_character: String = "☑"
var enable_checkbox_clicks: bool = true
var hr_height: int = 2
var hr_width: float = 90
var hr_alignment: String = "center"
var hr_color: Color = Color.WHITE

func _init() -> void:
	pass

## Main entry point for converting Markdown to BBCode.
func parse(source_text: String) -> String:
	_converted_text = ""
	var lines := source_text.split("\n")
	_current_line = 0
	_indent_level = -1
	var indent_spaces := []
	var indent_types := []
	var within_backtick_block := false
	var within_tilde_block := false
	var within_code_block := false
	var current_code_block_char_count: int
	_within_table = false
	_table_row = -1
	_skip_line_break = false
	_checkbox_id = 0
	_current_paragraph = 0
	_header_anchor_paragraph.clear()
	_escaped_characters_map.clear()
	checkbox_record.clear()

	for line: String in lines:
		line = line.trim_suffix("\r")
		_debug("Parsing line: '%s'" % line)
		within_code_block = within_tilde_block or within_backtick_block
		if _current_line > 0 and not _skip_line_break:
			_converted_text += "\n"
			_current_paragraph += 1
		_skip_line_break = false
		_current_line += 1
		
		# Handle fenced code blocks:
		if not within_tilde_block and _denotes_fenced_code_block(line, "`"):
			if within_backtick_block:
				if _count_fence_chars(line.strip_edges(), "`") >= current_code_block_char_count:
					_converted_text = _converted_text.trim_suffix("\n")
					_current_paragraph -= 1
					_converted_text += "[/code]"
					within_backtick_block = false
					_debug("... closing backtick block")
					continue
			else:
				_converted_text += "[code]"
				within_backtick_block = true
				current_code_block_char_count = _count_fence_chars(line.strip_edges(), "`")
				_debug("... opening backtick block")
				continue
		elif not within_backtick_block and _denotes_fenced_code_block(line, "~"):
			if within_tilde_block:
				if _count_fence_chars(line.strip_edges(), "~") >= current_code_block_char_count:
					_converted_text = _converted_text.trim_suffix("\n")
					_current_paragraph -= 1
					_converted_text += "[/code]"
					within_tilde_block = false
					_debug("... closing tilde block")
					continue
			else:
				_converted_text += "[code]"
				within_tilde_block = true
				current_code_block_char_count = _count_fence_chars(line.strip_edges(), "~")
				_debug("... opening tilde block")
				continue
		
		if within_code_block: # ignore any formatting inside code block
			_converted_text += _escape_bbcode(line)
			continue
		
		var _processed_line := line
		# Escape characters:
		_processed_line = _process_escaped_characters(_processed_line)
		
		# Process syntax:
		_processed_line = _process_table_syntax(_processed_line)
		_processed_line = _process_list_syntax(_processed_line, indent_spaces, indent_types)
		_processed_line = _process_inline_code_syntax(_processed_line)
		_processed_line = _process_image_syntax(_processed_line)
		_processed_line = _process_link_syntax(_processed_line)
		_processed_line = _process_hr_syntax(_processed_line)
		_processed_line = _process_text_formatting_syntax(_processed_line)
		_processed_line = _process_header_syntax(_processed_line)
		
		# Re-insert escaped characters:
		_processed_line = _reset_escaped_chars(_processed_line)
		
		_converted_text += _processed_line
	# end for line loop
	# Close any remaining open list:
	_debug("... end of text, closing all opened lists")
	for i in range(_indent_level, -1, -1):
		_converted_text += "[/%s]" % indent_types[i]
	# Close any remaining open tables:
	_debug("... end of text, closing all opened tables")
	if _within_table:
		_converted_text += "\n[/table]"
	
	return _converted_text

func _process_list_syntax(line: String, indent_spaces: Array, indent_types: Array) -> String:
	var processed_line := ""
	if line.length() == 0 and _indent_level >= 0:
		for i in range(_indent_level, -1, -1):
			_converted_text += "[/%s]" % indent_types[_indent_level]
			_indent_level -= 1
			indent_spaces.pop_back()
			indent_types.pop_back()
		_converted_text += "\n"
		_debug("... empty line, closing all list tags")
		return ""
	if _indent_level == -1:
		if line.length() > 2 and line[0] in "-*+" and line[1] == " ":
			_indent_level = 0
			indent_spaces.append(0)
			indent_types.append("ul")
			_converted_text += "[ul]"
			processed_line = line.substr(2)
			_debug("... opening unordered list at level 0")
			processed_line = _process_task_list_item(processed_line)
		elif line.length() > 3 and line[0] == "1" and line[1] == "." and line[2] == " ":
			_indent_level = 0
			indent_spaces.append(0)
			indent_types.append("ol")
			_converted_text += "[ol]"
			processed_line = line.substr(3)
			_debug("... opening ordered list at level 0")
		else:
			processed_line = line
		return processed_line
	var n_s := 0
	for _char in line:
		if _char == " " or _char == "\t":
			n_s += 1
			continue
		elif _char in "-*+":
			if line.length() > n_s + 2 and line[n_s + 1] == " ":
				if n_s == indent_spaces[_indent_level]:
					processed_line = line.substr(n_s + 2)
					_debug("... adding list element at level %d" % _indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
				elif n_s > indent_spaces[_indent_level]:
					_indent_level += 1
					indent_spaces.append(n_s)
					indent_types.append("ul")
					_converted_text += "[ul]"
					processed_line = line.substr(n_s + 2)
					_debug("... opening list at level %d and adding element" % _indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
				else:
					for i in range(_indent_level, -1, -1):
						if n_s < indent_spaces[i]:
							_converted_text += "[/%s]" % indent_types[_indent_level]
							_indent_level -= 1
							indent_spaces.pop_back()
							indent_types.pop_back()
						else:
							break
					_converted_text += "\n"
					processed_line = line.substr(n_s + 2)
					_debug("...closing lists down to level %d and adding element" % _indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
		elif _char in "123456789":
			if line.length() > n_s + 3 and line[n_s + 1] == "." and line[n_s + 2] == " ":
				if n_s == indent_spaces[_indent_level]:
					processed_line = line.substr(n_s + 3)
					_debug("... adding list element at level %d" % _indent_level)
					break
				elif n_s > indent_spaces[_indent_level]:
					_indent_level += 1
					indent_spaces.append(n_s)
					indent_types.append("ol")
					_converted_text += "[ol]"
					processed_line = line.substr(n_s + 3)
					_debug("... opening list at level %d and adding element" % _indent_level)
					break
				else:
					for i in range(_indent_level, -1, -1):
						if n_s < indent_spaces[i]:
							_converted_text += "[/%s]" % indent_types[_indent_level]
							_indent_level -= 1
							indent_spaces.pop_back()
							indent_types.pop_back()
						else:
							break
					_converted_text += "\n"
					processed_line = line.substr(n_s + 3)
					_debug("... closing lists down to level %d and adding element" % _indent_level)
					break
	#end for _char loop
	if processed_line.is_empty():
		for i in range(_indent_level, -1, -1):
			_converted_text += "[/%s]" % indent_types[i]
			_indent_level -= 1
			indent_spaces.pop_back()
			indent_types.pop_back()
		_converted_text += "\n"
		processed_line = line
		_debug("... regular line, closing all opened lists")
	return processed_line

func _process_task_list_item(item: String) -> String:
	if item.length() <= 3 or item[0] != "[" or item[2] != "]" or item[3] != " " or not item[1] in " x":
		return item
	var processed_item := item.erase(0, 3)
	var checkbox: String
	var meta := {
		_CHECKBOX_KEY: true,
		"id": _checkbox_id
	}
	checkbox_record[_checkbox_id] = _current_line - 1 # _current_line is actually the next line here
	_checkbox_id += 1
	if item[1] == " ":
		checkbox = unchecked_item_character
		meta.checked = false
		_debug("... item is an unchecked task item")
	elif item[1] == "x":
		checkbox = checked_item_character
		meta.checked = true
		_debug("... item is a checked task item")
	if enable_checkbox_clicks:
		processed_item = processed_item.insert(0, "[url=%s]%s[/url]" % [JSON.stringify(meta), checkbox])
	else:
		processed_item = processed_item.insert(0, checkbox)
	return processed_item

func _process_inline_code_syntax(line: String) -> String:
	var regex := RegEx.create_from_string("(`+)(.+?)\\1")
	var processed_line := line
	while true:
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		var _end := result.get_end()
		var unescaped_content := _reset_escaped_chars(result.get_string(2), true)
		unescaped_content = _escape_bbcode(unescaped_content)
		unescaped_content = _escape_chars(unescaped_content)
		processed_line = processed_line.erase(_start, _end - _start).insert(_start, "[code]%s[/code]" % unescaped_content)
		_debug("... in-line code: " + unescaped_content)
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
			url = _escape_chars(url)
			processed_line = processed_line.erase(_start, _end - _start).insert(_start, "[img%s%s]%s[/img]" % [
				" alt=\"%s\"" % alt_text if alt_text else "",
				" tooltip=\"%s\"" % title if title_result and title else "",
				url,
			])
			_debug("... image: " + result.get_string())
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
			url = _escape_chars(url)
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
			_debug("... hyperlink: " + result.get_string())
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
		url = _escape_chars(url)
		if mail:
			processed_line = processed_line.erase(_start, _end - _start).insert(_start, "[url=mailto:%s]%s[/url]" % [url, url])
			_debug("... mail link: " + result.get_string())
		else:
			processed_line = processed_line.erase(_start, _end - _start).insert(_start, "[url]%s[/url]" % url)
			_debug("... explicit link: " + result.get_string())
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
		_debug("... bold text: " + result.get_string(2))
	
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
		_debug("... italic text: " + result.get_string(2))
	
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
		_debug("... strike-through text: " + result.get_string(2))
	
	return processed_line

func _process_header_syntax(line: String) -> String:
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
		var header_format: Resource = _get_header_format(n)
		var _start := result.get_start()
		var opening_tags := _get_header_tags(header_format)
		processed_line = processed_line.erase(_start, n + n_spaces).insert(_start, opening_tags)
		var _end := result.get_end()
		processed_line = processed_line.insert(_end - (n + n_spaces) + opening_tags.length(), _get_header_tags(header_format, true))
		_debug("... header level %d" % n)
		_header_anchor_paragraph[_get_header_reference(result.get_string())] = _current_paragraph
		if header_format.get("draw_horizontal_rule"):
			var version := Engine.get_version_info()
			if version.hex >= 0x040500:
				processed_line += "\n[hr height=%d width=%d%% align=left color=%s]" % [
					hr_height,
					hr_width,
					hr_color.to_html(),
				]
				_current_line += 1
				_current_paragraph += 1
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
			hr_height,
			hr_width,
			hr_alignment,
			hr_color.to_html(),
		]
		_debug("... horizontal rule")
	return processed_line

func _escape_bbcode(source: String) -> String:
	return source.replacen("[", _ESCAPE_PLACEHOLDER).replacen("]", "[rb]").replacen(_ESCAPE_PLACEHOLDER, "[lb]")

func _escape_chars(_text: String) -> String:
	var escaped_text := _text
	for _char: String in _ESCAPEABLE_CHARACTERS:
		if not _char in _escaped_characters_map:
			_escaped_characters_map[_char] = _escaped_characters_map.size()
		escaped_text = escaped_text.replacen(_char, _ESCAPE_PLACEHOLDER % _escaped_characters_map[_char])
	return escaped_text

func _reset_escaped_chars(_text: String, code := false) -> String:
	var unescaped_text := _text
	for _char in _ESCAPEABLE_CHARACTERS:
		if not _char in _escaped_characters_map:
			continue
		unescaped_text = unescaped_text.replacen(_ESCAPE_PLACEHOLDER%_escaped_characters_map[_char], "\\" + _char if code else _char)
	return unescaped_text

func _debug(string: String) -> void:
	if not _debug_mode:
		return
	print(string)

func _denotes_fenced_code_block(line: String, character: String) -> bool:
	var stripped_line := line.strip_edges()
	var fence_count := _count_fence_chars(stripped_line, character)
	if fence_count < 3:
		return false
	# After the fence chars, only a language identifier (no fence chars) is allowed
	var remainder := stripped_line.substr(fence_count).strip_edges()
	# Opening: remainder can be a language id (no spaces inside). Closing: remainder is empty.
	if remainder.is_empty() or (not character in remainder and not " " in remainder):
		return true
	return false

func _count_fence_chars(stripped_line: String, character: String) -> int:
	var count := 0
	for c in stripped_line:
		if c == character:
			count += 1
		else:
			break
	return count

func _process_escaped_characters(line: String) -> String:
	var regex := RegEx.create_from_string("\\\\" + _ESCAPEABLE_CHARACTERS_REGEX)
	var processed_line := line
	while true:
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		var _escaped_char := result.get_string()[1]
		if not _escaped_char in _escaped_characters_map:
			_escaped_characters_map[_escaped_char] = _escaped_characters_map.size()
		processed_line = processed_line.erase(_start, 2).insert(_start, _ESCAPE_PLACEHOLDER % _escaped_characters_map[_escaped_char])
	return processed_line

func _process_table_syntax(line: String) -> String:
	if line.count("|") < 2:
		if _within_table:
			_debug("... end of table")
			_within_table = false
			return "[/table]\n" + line
		else:
			return line
	_debug("... table row: " + line)
	_table_row += 1
	var split_line := line.trim_prefix("|").trim_suffix("|").split("|")
	var processed_line := ""
	if not _within_table:
		processed_line += "[table=%d]\n" % split_line.size()
		_within_table = true
	elif _table_row == 1:
		# Handle delimiter row
		var is_delimiter := true
		for cell in split_line:
			var stripped_cell := cell.strip_edges()
			if stripped_cell.count("-") + stripped_cell.count(":") != stripped_cell.length():
				is_delimiter = false
				break
		if is_delimiter:
			_debug("... delimiter row")
			_skip_line_break = true
			return ""
	
	for i in range(split_line.size()):
		var cell := split_line[i].strip_edges()
		processed_line += "[cell]%s[/cell]" % cell
	return processed_line

func _get_header_format(level: int) -> Resource:
	match level:
		1: return h1
		2: return h2
		3: return h3
		4: return h4
		5: return h5
		6: return h6
	return null

func _get_header_tags(format: Resource, closing := false) -> String:
	if not format: return ""
	var tags := ""
	if not closing:
		if format.get("font_size"): tags += "[font_size=%d]" % int(format.get("font_size") * base_font_size)
		if format.get("font_color"): tags += "[color=%s]" % format.get("font_color").to_html()
		if format.get("is_bold"): tags += "[b]"
		if format.get("is_italic"): tags += "[i]"
		if format.get("is_underlined"): tags += "[u]"
	else:
		if format.get("is_underlined"): tags += "[/u]"
		if format.get("is_italic"): tags += "[/i]"
		if format.get("is_bold"): tags += "[/b]"
		if format.get("font_color"): tags += "[/color]"
		if format.get("font_size"): tags += "[/font_size]"
	return tags

func _get_header_reference(header_text: String) -> String:
	var regex := RegEx.create_from_string("[^a-z0-9\\s-]")
	var ref := header_text.to_lower().strip_edges().trim_prefix("#").strip_edges()
	ref = regex.sub(ref, "", true).replace(" ", "-")
	return "#" + ref
