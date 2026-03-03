@tool
extends RefCounted
class_name MarkdownRenderer

const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")

static func to_bbcode(markdown: String) -> String:
	var bbcode = markdown
	
	# Character Escaping (Preliminary)
	# We protect BBCode snippets inside code blocks later
	
	# Horizontal Rules
	var regex = RegEx.new()
	regex.compile("^---$")
	bbcode = regex.sub(bbcode, "\n[center][color=" + AppTheme.COLOR_BG_MUTED.to_html() + "]────────────────[/color][/center]", true)

	# Code blocks - Advanced with subtle background and language labels
	var lines = bbcode.split("\n")
	var new_lines = []
	var in_code_block = false
	for line in lines:
		if line.begins_with("```"):
			var lang = line.trim_prefix("```").strip_edges()
			if !in_code_block:
				in_code_block = true
				var lang_label = lang.to_upper() if lang != "" else "CODE"
				new_lines.append("\n[font_size=10][b][color=" + AppTheme.COLOR_ACCENT_SOFT.to_html() + "]" + lang_label + "[/color][/b][/font_size]")
				new_lines.append("[bgcolor=" + AppTheme.COLOR_CODE_BG.to_html() + "][code]")
			else:
				in_code_block = false
				new_lines.append("[/code][/bgcolor]\n")
		else:
			if in_code_block:
				# Escape BBCode inside code blocks
				var escaped_line = line.replace("[", "[lb]").replace("]", "[rb]")
				new_lines.append(escaped_line)
			else:
				new_lines.append(line)
	bbcode = "\n".join(new_lines)

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
	lines = bbcode.split("\n")
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
