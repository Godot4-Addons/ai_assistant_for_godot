@tool
extends AIMarkdownRule
class_name AIMarkdownTableRule

func process_line(line: String) -> String:
	if line.count("|") < 2:
		if parser.within_table:
			parser._debug("... end of table")
			parser.within_table = false
			return "[/table]\n" + line
		else:
			return line
			
	parser._debug("... table row: " + line)
	parser.table_row += 1
	var split_line := line.trim_prefix("|").trim_suffix("|").split("|")
	var processed_line := ""
	
	if not parser.within_table:
		processed_line += "[table=%d]\n" % split_line.size()
		parser.within_table = true
	elif parser.table_row == 1:
		# Handle delimiter row
		var is_delimiter := true
		for cell in split_line:
			var stripped_cell := cell.strip_edges()
			if stripped_cell.count("-") + stripped_cell.count(":") != stripped_cell.length():
				is_delimiter = false
				break
		if is_delimiter:
			parser._debug("... delimiter row")
			parser.skip_line_break = true
			return ""
	
	for i in range(split_line.size()):
		var cell := split_line[i].strip_edges()
		processed_line += "[cell]%s[/cell]" % cell
	return processed_line

func reset() -> void:
	parser.within_table = false
	parser.table_row = -1

func finalize() -> String:
	if parser.within_table:
		return "\n[/table]"
	return ""
