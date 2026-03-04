@tool
extends AIMarkdownRule
class_name AIMarkdownListRule

func process_line(line: String) -> String:
	var processed_line := ""
	if line.length() == 0 and parser.indent_level >= 0:
		for i in range(parser.indent_level, -1, -1):
			parser.converted_text += "[/%s]" % _indent_types[parser.indent_level]
			parser.indent_level -= 1
			_indent_spaces.pop_back()
			_indent_types.pop_back()
		parser.converted_text += "\n"
		parser._debug("... empty line, closing all list tags")
		return ""
	
	if parser.indent_level == -1:
		if line.length() > 2 and line[0] in "-*+" and line[1] == " ":
			parser.indent_level = 0
			_indent_spaces.append(0)
			_indent_types.append("ul")
			parser.converted_text += "[ul]"
			processed_line = line.substr(2)
			parser._debug("... opening unordered list at level 0")
			processed_line = _process_task_list_item(processed_line)
		elif line.length() > 3 and line[0] == "1" and line[1] == "." and line[2] == " ":
			parser.indent_level = 0
			_indent_spaces.append(0)
			_indent_types.append("ol")
			parser.converted_text += "[ol]"
			processed_line = line.substr(3)
			parser._debug("... opening ordered list at level 0")
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
				if n_s == _indent_spaces[parser.indent_level]:
					processed_line = line.substr(n_s + 2)
					parser._debug("... adding list element at level %d" % parser.indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
				elif n_s > _indent_spaces[parser.indent_level]:
					parser.indent_level += 1
					_indent_spaces.append(n_s)
					_indent_types.append("ul")
					parser.converted_text += "[ul]"
					processed_line = line.substr(n_s + 2)
					parser._debug("... opening list at level %d and adding element" % parser.indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
				else:
					for i in range(parser.indent_level, -1, -1):
						if n_s < _indent_spaces[i]:
							parser.converted_text += "[/%s]" % _indent_types[parser.indent_level]
							parser.indent_level -= 1
							_indent_spaces.pop_back()
							_indent_types.pop_back()
						else:
							break
					parser.converted_text += "\n"
					processed_line = line.substr(n_s + 2)
					parser._debug("...closing lists down to level %d and adding element" % parser.indent_level)
					processed_line = _process_task_list_item(processed_line)
					break
		elif _char in "123456789":
			if line.length() > n_s + 3 and line[n_s + 1] == "." and line[n_s + 2] == " ":
				if n_s == _indent_spaces[parser.indent_level]:
					processed_line = line.substr(n_s + 3)
					parser._debug("... adding list element at level %d" % parser.indent_level)
					break
				elif n_s > _indent_spaces[parser.indent_level]:
					parser.indent_level += 1
					_indent_spaces.append(n_s)
					_indent_types.append("ol")
					parser.converted_text += "[ol]"
					processed_line = line.substr(n_s + 3)
					parser._debug("... opening list at level %d and adding element" % parser.indent_level)
					break
				else:
					for i in range(parser.indent_level, -1, -1):
						if n_s < _indent_spaces[i]:
							parser.converted_text += "[/%s]" % _indent_types[parser.indent_level]
							parser.indent_level -= 1
							_indent_spaces.pop_back()
							_indent_types.pop_back()
						else:
							break
					parser.converted_text += "\n"
					processed_line = line.substr(n_s + 3)
					parser._debug("... closing lists down to level %d and adding element" % parser.indent_level)
					break
					
	if processed_line.is_empty():
		for i in range(parser.indent_level, -1, -1):
			parser.converted_text += "[/%s]" % _indent_types[i]
			parser.indent_level -= 1
			_indent_spaces.pop_back()
			_indent_types.pop_back()
		parser.converted_text += "\n"
		processed_line = line
		parser._debug("... regular line, closing all opened lists")
	return processed_line

var _indent_spaces := []
var _indent_types := []

func reset() -> void:
	_indent_spaces.clear()
	_indent_types.clear()

func finalize() -> String:
	var closing := ""
	for i in range(parser.indent_level, -1, -1):
		closing += "[/%s]" % _indent_types[i]
	return closing

func _process_task_list_item(item: String) -> String:
	if item.length() <= 3 or item[0] != "[" or item[2] != "]" or item[3] != " " or not item[1] in " x":
		return item
	var processed_item := item.erase(0, 3)
	var checkbox: String
	var meta := {
		AIMarkdownParser._CHECKBOX_KEY: true,
		"id": parser.checkbox_id
	}
	parser.checkbox_record[parser.checkbox_id] = parser.current_line - 1 # current_line is actually the next line here
	parser.checkbox_id += 1
	if item[1] == " ":
		checkbox = parser.unchecked_item_character
		meta.checked = false
		parser._debug("... item is an unchecked task item")
	elif item[1] == "x":
		checkbox = parser.checked_item_character
		meta.checked = true
		parser._debug("... item is a checked task item")
	if parser.enable_checkbox_clicks:
		processed_item = processed_item.insert(0, "[url=%s]%s[/url]" % [JSON.stringify(meta), checkbox])
	else:
		processed_item = processed_item.insert(0, checkbox)
	return processed_item
