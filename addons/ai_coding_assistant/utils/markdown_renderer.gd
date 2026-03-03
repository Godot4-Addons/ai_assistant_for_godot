@tool
extends RefCounted
class_name MarkdownRenderer

const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")

static func to_bbcode(markdown: String) -> String:
	var bbcode = markdown
	
	# Code blocks
	var in_code_block = false
	var lines = bbcode.split("\n")
	var new_lines = []
	for line in lines:
		if line.begins_with("```"):
			var lang = line.trim_prefix("```").strip_edges()
			if !in_code_block:
				in_code_block = true
				if lang != "":
					new_lines.append("[font_size=11][color=" + AppTheme.COLOR_TEXT_DIM.to_html() + "]" + lang + "[/color][/font_size]")
				new_lines.append("[color=" + AppTheme.COLOR_TEXT_BOLD.to_html() + "][code]")
			else:
				in_code_block = false
				new_lines.append("[/code][/color]")
		else:
			new_lines.append(line)
	bbcode = "\n".join(new_lines)
	
	# Inline code
	var regex = RegEx.new()
	regex.compile("`([^`]+)`")
	bbcode = regex.sub(bbcode, "[color=" + AppTheme.COLOR_ACCENT_SOFT.to_html() + "][font_size=12][code]$1[/code][/font_size][/color]", true)

	# Bold
	regex.compile("\\*\\*(.*?)\\*\\*")
	bbcode = regex.sub(bbcode, "[b]$1[/b]", true)
	
	# Italic
	regex.compile("\\*(.*?)\\*")
	bbcode = regex.sub(bbcode, "[i]$1[/i]", true)
	
	# Headers
	regex.compile("^(#{1,6})\\s*(.*?)$")
	lines = bbcode.split("\n")
	for i in range(lines.size()):
		var m = regex.search(lines[i])
		if m:
			var h_level = m.get_string(1).length()
			var text = m.get_string(2).strip_edges()
			var size = 18 - (h_level * 1)
			lines[i] = "\n[font_size=" + str(size) + "][b][color=" + AppTheme.COLOR_ACCENT_SOFT.to_html() + "]" + text + "[/color][/b][/font_size]"
	bbcode = "\n".join(lines)
	
	# Horizontal Rules
	regex.compile("^---$")
	bbcode = regex.sub(bbcode, "\n[center][color=" + AppTheme.COLOR_BG_MUTED.to_html() + "]──────────────[/color][/center]\n", true)

	# Blockquotes
	regex.compile("^> (.*)$")
	bbcode = regex.sub(bbcode, "[indent][i][color=" + AppTheme.COLOR_TEXT_DIM.to_html() + "]$1[/color][/i][/indent]", true)

	# Unordered Lists
	regex.compile("^\\s*[-*]\\s+(.*)$")
	bbcode = regex.sub(bbcode, "[indent]• $1[/indent]", true)

	# Ordered Lists
	regex.compile("^\\s*(\\d+)\\.\\s+(.*)$")
	bbcode = regex.sub(bbcode, "[indent]$1. $2[/indent]", true)

	# Links
	regex.compile("\\[(.*?)\\]\\((.*?)\\)")
	bbcode = regex.sub(bbcode, "[url=$2][color=" + AppTheme.COLOR_ACCENT.to_html() + "]$1[/color][/url]", true)

	return bbcode.strip_edges()
