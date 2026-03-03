@tool
extends RefCounted
class_name MarkdownRenderer

const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")

static func render_to_vbox(vbox: VBoxContainer, markdown: String):
	# Clear existing segments
	for child in vbox.get_children():
		child.queue_free()
	
	var segments = _split_into_segments(markdown)
	
	for segment in segments:
		if segment.type == "code":
			_add_code_segment(vbox, segment.content, segment.lang)
		else:
			_add_text_segment(vbox, segment.content)

static func _split_into_segments(markdown: String) -> Array:
	var segments = []
	var parts = markdown.split("```")
	
	for i in range(parts.size()):
		var content = parts[i]
		if i % 2 == 1: # Code block
			var lines = content.split("\n", true, 1)
			var lang = lines[0].strip_edges()
			var code = lines[1] if lines.size() > 1 else ""
			segments.append({"type": "code", "content": code.strip_edges(), "lang": lang})
		else: # Text block
			if not content.strip_edges().is_empty():
				segments.append({"type": "text", "content": content.strip_edges()})
	return segments

static func _add_text_segment(vbox: VBoxContainer, text: String):
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = to_bbcode(text)
	label.fit_content = true
	label.selection_enabled = true
	label.add_theme_font_size_override("normal_font_size", 13)
	label.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	vbox.add_child(label)

static func _add_code_segment(vbox: VBoxContainer, code: String, lang: String):
	var panel = PanelContainer.new()
	AppTheme.apply_code_panel_style(panel)
	vbox.add_child(panel)
	
	var inner_vbox = VBoxContainer.new()
	panel.add_child(inner_vbox)
	
	var header = HBoxContainer.new()
	var lang_label = Label.new()
	lang_label.text = lang.to_upper() if not lang.is_empty() else "CODE"
	lang_label.add_theme_color_override("font_color", AppTheme.COLOR_ACCENT_SOFT)
	lang_label.add_theme_font_size_override("font_size", 10)
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lang_label)
	
	var copy_btn = Button.new()
	copy_btn.text = "📋"
	copy_btn.flat = true
	copy_btn.tooltip_text = "Copy Code"
	copy_btn.pressed.connect(func(): DisplayServer.clipboard_set(code))
	header.add_child(copy_btn)
	inner_vbox.add_child(header)
	
	var code_label = RichTextLabel.new()
	code_label.bbcode_enabled = true
	
	var displayed_code = code
	if lang.to_lower() in ["gdscript", "gd"]:
		displayed_code = highlight_gdscript(code)
	else:
		# Escape BBCode characters inside generic code segments
		displayed_code = "[code]" + code.replace("[", "[lb]").replace("]", "[rb]") + "[/code]"
		
	code_label.text = displayed_code
	code_label.fit_content = true
	code_label.selection_enabled = true
	code_label.add_theme_font_size_override("normal_font_size", 12)
	inner_vbox.add_child(code_label)

static func highlight_gdscript(code: String) -> String:
	var bbcode = code.replace("[", "[lb]").replace("]", "[rb]")
	var regex = RegEx.new()
	
	# Pass 1: Comments (Protect them)
	var comments = []
	regex.compile("#.*")
	var result = regex.search_all(bbcode)
	for i in range(result.size()):
		var m = result[result.size() - 1 - i]
		var placeholder = "{C%d}" % i
		comments.append("[color=" + AppTheme.COLOR_SYNTAX_COMMENT.to_html() + "]" + m.get_string() + "[/color]")
		bbcode = bbcode.erase(m.get_start(), m.get_string().length())
		bbcode = bbcode.insert(m.get_start(), placeholder)

	# Pass 2: Strings (Protect them)
	var strings = []
	regex.compile("\".*?\"|'.*?'")
	result = regex.search_all(bbcode)
	for i in range(result.size()):
		var m = result[result.size() - 1 - i]
		var placeholder = "{S%d}" % i
		strings.append("[color=" + AppTheme.COLOR_SYNTAX_STRING.to_html() + "]" + m.get_string() + "[/color]")
		bbcode = bbcode.erase(m.get_start(), m.get_string().length())
		bbcode = bbcode.insert(m.get_start(), placeholder)

	# Keywords
	var keywords = [
		"extends", "class_name", "const", "var", "func", "static", "onready",
		"if", "elif", "else", "for", "while", "match", "return", "pass",
		"break", "continue", "and", "or", "not", "in", "is", "as", "yield",
		"await", "signal", "enum", "export", "tool", "breakpoint", "self"
	]
	var kw_pattern = "\\b(" + "|".join(keywords) + ")\\b"
	regex.compile(kw_pattern)
	bbcode = regex.sub(bbcode, "[color=" + AppTheme.COLOR_SYNTAX_KEYWORD.to_html() + "]$1[/color]", true)
	
	# Numbers
	regex.compile("\\b\\d+\\.?\\d*\\b")
	bbcode = regex.sub(bbcode, "[color=" + AppTheme.COLOR_SYNTAX_NUMBER.to_html() + "]$0[/color]", true)
	
	# Functions
	regex.compile("(\\b[a-zA-Z_][a-zA-Z0-9_]*\\b)\\s*\\(")
	bbcode = regex.sub(bbcode, "[color=" + AppTheme.COLOR_SYNTAX_FUNCTION.to_html() + "]$1[/color](", true)
	
	# Member variables/Dots
	regex.compile("\\.([a-zA-Z_][a-zA-Z0-9_]*\\b)")
	bbcode = regex.sub(bbcode, ".[color=" + AppTheme.COLOR_SYNTAX_MEMBER.to_html() + "]$1[/color]", true)

	# Restore Strings and Comments
	for i in range(strings.size()):
		bbcode = bbcode.replace("{S%d}" % i, strings[i])
	for i in range(comments.size()):
		bbcode = bbcode.replace("{C%d}" % i, comments[i])
		
	return "[code]" + bbcode + "[/code]"

static func to_bbcode(markdown: String) -> String:
	var bbcode = markdown
	
	# Horizontal Rules
	var regex = RegEx.new()
	regex.compile("^---$")
	bbcode = regex.sub(bbcode, "\n[center][color=" + AppTheme.COLOR_BG_MUTED.to_html() + "]────────────────[/color][/center]", true)

	# Blockquotes - Simulated vertical bar
	regex.compile("(?m)^> (.*)$")
	bbcode = regex.sub(bbcode, "[color=" + AppTheme.COLOR_QUOTE_BAR.to_html() + "]┃[/color] [i][color=" + AppTheme.COLOR_TEXT_DIM.to_html() + "]$1[/color][/i]", true)

	# Nested Lists (Simplified support for up to 2 levels)
	# Level 2
	regex.compile("(?m)^  [-*+] (.*)$")
	bbcode = regex.sub(bbcode, "[indent][indent]• $1[/indent][/indent]", true)
	regex.compile("(?m)^  (\\d+)\\. (.*)$")
	bbcode = regex.sub(bbcode, "[indent][indent]$1. $2[/indent][/indent]", true)
	
	# Level 1
	regex.compile("(?m)^[-*+] (.*)$")
	bbcode = regex.sub(bbcode, "[indent]• $1[/indent]", true)
	regex.compile("(?m)^(\\d+)\\. (.*)$")
	bbcode = regex.sub(bbcode, "[indent]$1. $2[/indent]", true)

	# Inline code - Subtle background and color
	regex.compile("`([^`]+)`")
	bbcode = regex.sub(bbcode, "[bgcolor=" + AppTheme.COLOR_CODE_BG.to_html() + "][color=" + AppTheme.COLOR_ACCENT_SOFT.to_html() + "][code]$1[/code][/color][/bgcolor]", true)

	# Strikethrough
	regex.compile("~~(.*?)~~")
	bbcode = regex.sub(bbcode, "[s]$1[/s]", true)

	# Bold & Italic
	regex.compile("\\*\\*(.*?)\\*\\*")
	bbcode = regex.sub(bbcode, "[b]$1[/b]", true)
	regex.compile("\\*(.*?)\\*")
	bbcode = regex.sub(bbcode, "[i]$1[/i]", true)

	# Headers
	regex.compile("(?m)^(#{1,6})\\s*(.*?)$")
	var lines = bbcode.split("\n")
	for i in range(lines.size()):
		var m = regex.search(lines[i])
		if m:
			var h_level = m.get_string(1).length()
			var text = m.get_string(2).strip_edges()
			var size = 18 - (h_level * 1)
			lines[i] = "\n[font_size=" + str(size) + "][b][color=" + AppTheme.COLOR_ACCENT_SOFT.to_html() + "]" + text + "[/color][/b][/font_size]"
	bbcode = "\n".join(lines)

	# Links
	regex.compile("\\[(.*?)\\]\\((.*?)\\)")
	bbcode = regex.sub(bbcode, "[url=$2][color=" + AppTheme.COLOR_ACCENT.to_html() + "]$1[/color][/url]", true)

	# Basic Table Support (Very rough approximation using monospace)
	if "|" in bbcode and "-|-" in bbcode:
		regex.compile("(?m)^\\|?(.*\\|.*)\\|?$")
		bbcode = regex.sub(bbcode, "[code]$1[/code]", true)

	return bbcode.strip_edges()
