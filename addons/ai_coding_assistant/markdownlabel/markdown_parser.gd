@tool
extends RefCounted
class_name AIMarkdownParser

## Dedicated parser for converting Markdown to BBCode.
## Uses a modular rule-based architecture.

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

const ESCAPE_PLACEHOLDER := ";$\uFFFD:%s$;"
const ESCAPEABLE_CHARACTERS := "\\*_~`[]()\"<>#-+.!"
const ESCAPEABLE_CHARACTERS_REGEX := "[\\\\\\*\\_\\~`\\[\\]\\(\\)\\\"\\<\\>#\\-\\+\\.\\!]"
const CHECKBOX_KEY := "markdownlabel-checkbox"

# ─────────────────────────────────────────────────────────────────────────────
# State (Used during parsing)
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

var rules: Array = []

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
	rules.append(preload("rules/code_block_rule.gd").new(self ))
	rules.append(preload("rules/table_rule.gd").new(self ))
	rules.append(preload("rules/list_rule.gd").new(self ))
	rules.append(preload("rules/header_rule.gd").new(self ))
	rules.append(preload("rules/inline_rule.gd").new(self ))

## Main entry point for converting Markdown to BBCode.
func parse(source_text: String) -> String:
	converted_text = ""
	for r in rules: r.reset()
	
	var lines := source_text.split("\n")
	current_line = 0
	indent_level = -1
	skip_line_break = false
	current_paragraph = 0
	header_anchor_paragraph.clear()
	escaped_characters_map.clear()
	checkbox_record.clear()

	for line: String in lines:
		line = line.trim_suffix("\r")
		_debug("Parsing line: '%s'" % line)
		
		if current_line > 0 and not skip_line_break:
			converted_text += "\n"
			current_paragraph += 1
		skip_line_break = false
		current_line += 1
		
		var processed_line := line
		
		# Escape phase
		processed_line = _process_escaped_characters(processed_line)
		
		# Rule phase
		for rule in rules:
			processed_line = rule.process_line(processed_line)
			if processed_line.is_empty(): # Rule indicates line was fully handled or absorbed
				break
				
		# Finalize line if not absorbed
		if not processed_line.is_empty():
			processed_line = _reset_escaped_chars(processed_line)
			converted_text += processed_line
			
	# Finalization phase (close open tags)
	for rule in rules:
		converted_text += rule.finalize()
	
	return converted_text

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

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
