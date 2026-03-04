@tool
extends RefCounted
class_name AIMarkdownParser

## Dedicated parser for converting Markdown to BBCode.
## All syntax rules are organized into regions within this file.

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

const ESCAPE_PLACEHOLDER := ";$\uFFFD:%s$;"
const ESCAPEABLE_CHARACTERS := "\\*_~`[]()\"<>#-+.!"
const ESCAPEABLE_CHARACTERS_REGEX := "[\\\\\\*\\_\\~`\\[\\]\\(\\)\\\"\\<\\>#\\-\\+\\.\\!]"
const CHECKBOX_KEY := "markdownlabel-checkbox"

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

var converted_text: String
var indent_level: int
var escaped_characters_map := {}
var current_paragraph: int = 0
var header_anchor_paragraph := {}
var within_table := false
var table_row := -1
var skip_line_break := false
var checkbox_id: int = 0
var current_line: int = 0
var checkbox_record := {}
var debug_mode := false

# Code block state
var _within_backtick_block := false
var _within_tilde_block := false
var _current_code_block_char_count: int = 0
var _code_block_language := ""
var _code_block_lines: PackedStringArray = []

# List state
var _indent_spaces := []
var _indent_types := []

# Syntax highlighting
const _SyntaxHighlighterScript = preload("syntax_highlighter.gd")
var _highlighter = _SyntaxHighlighterScript.new()
var syntax_highlighting_enabled := true

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
var code_block_bg_color := "0f172a" # Dark slate for code background

# ─────────────────────────────────────────────────────────────────────────────
# Segment Splitting (pre-parse)
# ─────────────────────────────────────────────────────────────────────────────

## Splits raw markdown into segments: [{type:"text", content:""}, {type:"code", language:"", content:""}]
## This allows the UI to render code blocks as separate styled containers.
static func split_segments(source_text: String) -> Array:
	var segments := []
	var lines := source_text.split("\n")
	var current_text_lines: PackedStringArray = []
	var current_code_lines: PackedStringArray = []
	var in_code := false
	var code_lang := ""
	var fence_char := ""
	var fence_count := 0

	for line in lines:
		var stripped := line.strip_edges()
		if not in_code:
			# Check for opening fence
			var bc := _static_count_fence(stripped, "`")
			var tc := _static_count_fence(stripped, "~")
			if bc >= 3:
				# Flush current text
				if current_text_lines.size() > 0:
					segments.append({"type": "text", "content": "\n".join(current_text_lines)})
					current_text_lines = PackedStringArray()
				in_code = true
				fence_char = "`"
				fence_count = bc
				code_lang = stripped.substr(bc).strip_edges().to_lower()
				current_code_lines = PackedStringArray()
			elif tc >= 3:
				if current_text_lines.size() > 0:
					segments.append({"type": "text", "content": "\n".join(current_text_lines)})
					current_text_lines = PackedStringArray()
				in_code = true
				fence_char = "~"
				fence_count = tc
				code_lang = stripped.substr(tc).strip_edges().to_lower()
				current_code_lines = PackedStringArray()
			else:
				current_text_lines.append(line)
		else:
			# Check for closing fence
			var cc := _static_count_fence(stripped, fence_char)
			if cc >= fence_count and stripped == fence_char.repeat(cc):
				segments.append({"type": "code", "language": code_lang, "content": "\n".join(current_code_lines)})
				current_code_lines = PackedStringArray()
				in_code = false
			else:
				current_code_lines.append(line)

	# Flush remaining
	if in_code and current_code_lines.size() > 0:
		segments.append({"type": "code", "language": code_lang, "content": "\n".join(current_code_lines)})
	if current_text_lines.size() > 0:
		segments.append({"type": "text", "content": "\n".join(current_text_lines)})
	return segments

static func _static_count_fence(stripped_line: String, character: String) -> int:
	var count := 0
	for c in stripped_line:
		if c == character:
			count += 1
		else:
			break
	return count

# ─────────────────────────────────────────────────────────────────────────────
# Main Parse Loop
# ─────────────────────────────────────────────────────────────────────────────

func parse(source_text: String) -> String:
	converted_text = ""
	var lines := source_text.split("\n")
	current_line = 0
	indent_level = -1
	_indent_spaces.clear()
	_indent_types.clear()
	_within_backtick_block = false
	_within_tilde_block = false
	_current_code_block_char_count = 0
	_code_block_language = ""
	_code_block_lines.clear()
	within_table = false
	table_row = -1
	skip_line_break = false
	checkbox_id = 0
	current_paragraph = 0
	header_anchor_paragraph.clear()
	escaped_characters_map.clear()
	checkbox_record.clear()

	for line: String in lines:
		line = line.trim_suffix("\r")
		_debug("Parsing line: '%s'" % line)
		var within_code_block := _within_tilde_block or _within_backtick_block
		if current_line > 0 and not skip_line_break and not within_code_block:
			converted_text += "\n"
			current_paragraph += 1
		skip_line_break = false
		current_line += 1

		# Handle fenced code blocks:
		if not _within_tilde_block and _denotes_fenced_code_block(line, "`"):
			if _within_backtick_block:
				if _count_fence_chars(line.strip_edges(), "`") >= _current_code_block_char_count:
					_flush_code_block()
					_within_backtick_block = false
					_debug("... closing backtick block")
					continue
			else:
				_within_backtick_block = true
				_current_code_block_char_count = _count_fence_chars(line.strip_edges(), "`")
				_code_block_language = _extract_language(line.strip_edges(), "`")
				_code_block_lines.clear()
				_debug("... opening backtick block [%s]" % _code_block_language)
				continue
		elif not _within_backtick_block and _denotes_fenced_code_block(line, "~"):
			if _within_tilde_block:
				if _count_fence_chars(line.strip_edges(), "~") >= _current_code_block_char_count:
					_flush_code_block()
					_within_tilde_block = false
					_debug("... closing tilde block")
					continue
			else:
				_within_tilde_block = true
				_current_code_block_char_count = _count_fence_chars(line.strip_edges(), "~")
				_code_block_language = _extract_language(line.strip_edges(), "~")
				_code_block_lines.clear()
				_debug("... opening tilde block [%s]" % _code_block_language)
				continue

		if within_code_block:
			_code_block_lines.append(line)
			continue

		var _processed_line := line
		_processed_line = _process_escaped_characters(_processed_line)
		_processed_line = _process_table_syntax(_processed_line)
		_processed_line = _process_list_syntax(_processed_line)
		_processed_line = _process_inline_code_syntax(_processed_line)
		_processed_line = _process_image_syntax(_processed_line)
		_processed_line = _process_link_syntax(_processed_line)
		_processed_line = _process_hr_syntax(_processed_line)
		_processed_line = _process_text_formatting_syntax(_processed_line)
		_processed_line = _process_header_syntax(_processed_line)
		_processed_line = _reset_escaped_chars(_processed_line)

		converted_text += _processed_line

	# Close remaining open code block
	if _within_backtick_block or _within_tilde_block:
		_flush_code_block()
	# Close remaining open lists
	for i in range(indent_level, -1, -1):
		converted_text += "[/%s]" % _indent_types[i]
	# Close remaining open tables
	if within_table:
		converted_text += "\n[/table]"

	return converted_text

func _extract_language(stripped_line: String, character: String) -> String:
	var fence_count := _count_fence_chars(stripped_line, character)
	var remainder := stripped_line.substr(fence_count).strip_edges()
	return remainder.to_lower()

func _flush_code_block() -> void:
	var code_text := "\n".join(_code_block_lines)
	var bg_open := "[bgcolor=#%s]" % code_block_bg_color
	var bg_close := "[/bgcolor]"
	if syntax_highlighting_enabled and _code_block_language != "":
		var highlighted := _highlighter.highlight(code_text, _code_block_language, _escape_bbcode)
		converted_text += bg_open + "[code]" + highlighted + "[/code]" + bg_close
	else:
		converted_text += bg_open + "[code]" + _escape_bbcode(code_text) + "[/code]" + bg_close
	_code_block_lines.clear()
	_code_block_language = ""

#region ── List Syntax ──────────────────────────────────────────────────────────

func _process_list_syntax(line: String) -> String:
	var processed_line := ""
	if line.length() == 0 and indent_level >= 0:
		for i in range(indent_level, -1, -1):
			converted_text += "[/%s]" % _indent_types[indent_level]
			indent_level -= 1
			_indent_spaces.pop_back()
			_indent_types.pop_back()
		converted_text += "\n"
		_debug("... empty line, closing all list tags")
		return ""
	if indent_level == -1:
		if line.length() > 2 and line[0] in "-*+" and line[1] == " ":
			indent_level = 0
			_indent_spaces.append(0)
			_indent_types.append("ul")
			converted_text += "[ul]"
			processed_line = line.substr(2)
			_debug("... opening unordered list at level 0")
			processed_line = _process_task_list_item(processed_line)
		elif line.length() > 3 and line[0] == "1" and line[1] == "." and line[2] == " ":
			indent_level = 0
			_indent_spaces.append(0)
			_indent_types.append("ol")
			converted_text += "[ol]"
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
				if n_s == _indent_spaces[indent_level]:
					processed_line = line.substr(n_s + 2)
					_debug("... adding list element at level %d" % indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
				elif n_s > _indent_spaces[indent_level]:
					indent_level += 1
					_indent_spaces.append(n_s)
					_indent_types.append("ul")
					converted_text += "[ul]"
					processed_line = line.substr(n_s + 2)
					_debug("... opening list at level %d and adding element" % indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
				else:
					for i in range(indent_level, -1, -1):
						if n_s < _indent_spaces[i]:
							converted_text += "[/%s]" % _indent_types[indent_level]
							indent_level -= 1
							_indent_spaces.pop_back()
							_indent_types.pop_back()
						else:
							break
					converted_text += "\n"
					processed_line = line.substr(n_s + 2)
					_debug("...closing lists down to level %d and adding element" % indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
		elif _char in "123456789":
			if line.length() > n_s + 3 and line[n_s + 1] == "." and line[n_s + 2] == " ":
				if n_s == _indent_spaces[indent_level]:
					processed_line = line.substr(n_s + 3)
					_debug("... adding list element at level %d" % indent_level)
					break
				elif n_s > _indent_spaces[indent_level]:
					indent_level += 1
					_indent_spaces.append(n_s)
					_indent_types.append("ol")
					converted_text += "[ol]"
					processed_line = line.substr(n_s + 3)
					_debug("... opening list at level %d and adding element" % indent_level)
					break
				else:
					for i in range(indent_level, -1, -1):
						if n_s < _indent_spaces[i]:
							converted_text += "[/%s]" % _indent_types[indent_level]
							indent_level -= 1
							_indent_spaces.pop_back()
							_indent_types.pop_back()
						else:
							break
					converted_text += "\n"
					processed_line = line.substr(n_s + 3)
					_debug("... closing lists down to level %d and adding element" % indent_level)
					break
	if processed_line.is_empty():
		for i in range(indent_level, -1, -1):
			converted_text += "[/%s]" % _indent_types[i]
			indent_level -= 1
			_indent_spaces.pop_back()
			_indent_types.pop_back()
		converted_text += "\n"
		processed_line = line
		_debug("... regular line, closing all opened lists")
	return processed_line

func _process_task_list_item(item: String) -> String:
	if item.length() <= 3 or item[0] != "[" or item[2] != "]" or item[3] != " " or not item[1] in " x":
		return item
	var processed_item := item.erase(0, 3)
	var checkbox: String
	var meta := {
		CHECKBOX_KEY: true,
		"id": checkbox_id
	}
	checkbox_record[checkbox_id] = current_line - 1
	checkbox_id += 1
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

#endregion

#region ── Inline Code ─────────────────────────────────────────────────────────

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

#endregion

#region ── Images ──────────────────────────────────────────────────────────────

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

#endregion

#region ── Links ───────────────────────────────────────────────────────────────

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

#endregion

#region ── Text Formatting (Bold/Italic/Strike) ────────────────────────────────

func _process_text_formatting_syntax(line: String) -> String:
	var processed_line := line
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

	while true:
		regex.compile("(\\*|_)(.+?)\\1")
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		var _end := result.get_end()
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

#endregion

#region ── Headers ─────────────────────────────────────────────────────────────

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
		header_anchor_paragraph[_get_header_reference(result.get_string())] = current_paragraph
		if header_format and header_format.get("draw_horizontal_rule"):
			var version := Engine.get_version_info()
			if version.hex >= 0x040500:
				processed_line += "\n[hr height=%d width=%d%% align=left color=%s]" % [
					hr_height, hr_width, hr_color.to_html(),
				]
				current_line += 1
				current_paragraph += 1
	return processed_line

#endregion

#region ── Tables ──────────────────────────────────────────────────────────────

func _process_table_syntax(line: String) -> String:
	if line.count("|") < 2:
		if within_table:
			_debug("... end of table")
			within_table = false
			return "[/table]\n" + line
		else:
			return line
	_debug("... table row: " + line)
	table_row += 1
	var split_line := line.trim_prefix("|").trim_suffix("|").split("|")
	var processed_line := ""
	if not within_table:
		processed_line += "[table=%d]\n" % split_line.size()
		within_table = true
	elif table_row == 1:
		var is_delimiter := true
		for cell in split_line:
			var stripped_cell := cell.strip_edges()
			if stripped_cell.count("-") + stripped_cell.count(":") != stripped_cell.length():
				is_delimiter = false
				break
		if is_delimiter:
			_debug("... delimiter row")
			skip_line_break = true
			return ""
	for i in range(split_line.size()):
		var cell := split_line[i].strip_edges()
		processed_line += "[cell]%s[/cell]" % cell
	return processed_line

#endregion

#region ── Horizontal Rules ───────────────────────────────────────────────────

func _process_hr_syntax(line: String) -> String:
	var version := Engine.get_version_info()
	if version.hex < 0x040500:
		return line
	var processed_line := line
	var regex := RegEx.create_from_string(r"^[ ]{0,3}([\-_*])\1{2,}\s*$")
	var result := regex.search(processed_line)
	if result:
		processed_line = "[hr height=%d width=%d%% align=%s color=%s]" % [
			hr_height, hr_width, hr_alignment, hr_color.to_html(),
		]
		_debug("... horizontal rule")
	return processed_line

#endregion

#region ── Utility Helpers ────────────────────────────────────────────────────

func _escape_bbcode(source: String) -> String:
	return source.replacen("[", ESCAPE_PLACEHOLDER).replacen("]", "[rb]").replacen(ESCAPE_PLACEHOLDER, "[lb]")

func _escape_chars(_text: String) -> String:
	var escaped_text := _text
	for _char: String in ESCAPEABLE_CHARACTERS:
		if not _char in escaped_characters_map:
			escaped_characters_map[_char] = escaped_characters_map.size()
		escaped_text = escaped_text.replacen(_char, ESCAPE_PLACEHOLDER % escaped_characters_map[_char])
	return escaped_text

func _reset_escaped_chars(_text: String, code := false) -> String:
	var unescaped_text := _text
	for _char in ESCAPEABLE_CHARACTERS:
		if not _char in escaped_characters_map:
			continue
		unescaped_text = unescaped_text.replacen(ESCAPE_PLACEHOLDER % escaped_characters_map[_char], "\\" + _char if code else _char)
	return unescaped_text

func _debug(string: String) -> void:
	if not debug_mode:
		return
	print(string)

func _denotes_fenced_code_block(line: String, character: String) -> bool:
	var stripped_line := line.strip_edges()
	var fence_count := _count_fence_chars(stripped_line, character)
	if fence_count < 3:
		return false
	var remainder := stripped_line.substr(fence_count).strip_edges()
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
	var regex := RegEx.create_from_string("\\\\" + ESCAPEABLE_CHARACTERS_REGEX)
	var processed_line := line
	while true:
		var result := regex.search(processed_line)
		if not result:
			break
		var _start := result.get_start()
		var _escaped_char := result.get_string()[1]
		if not _escaped_char in escaped_characters_map:
			escaped_characters_map[_escaped_char] = escaped_characters_map.size()
		processed_line = processed_line.erase(_start, 2).insert(_start, ESCAPE_PLACEHOLDER % escaped_characters_map[_escaped_char])
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
		if format.get("override_font_color") and format.get("font_color"):
			tags += "[color=#%s]" % format.get("font_color").to_html()
		if format.get("is_bold"): tags += "[b]"
		if format.get("is_italic"): tags += "[i]"
		if format.get("is_underlined"): tags += "[u]"
	else:
		if format.get("is_underlined"): tags += "[/u]"
		if format.get("is_italic"): tags += "[/i]"
		if format.get("is_bold"): tags += "[/b]"
		if format.get("override_font_color") and format.get("font_color"):
			tags += "[/color]"
		if format.get("font_size"): tags += "[/font_size]"
	return tags

func _get_header_reference(header_text: String) -> String:
	var regex := RegEx.create_from_string("[^a-z0-9\\s-]")
	var ref := header_text.to_lower().strip_edges().trim_prefix("#").strip_edges()
	ref = regex.sub(ref, "", true).replace(" ", "-")
	return "#" + ref

#endregion
