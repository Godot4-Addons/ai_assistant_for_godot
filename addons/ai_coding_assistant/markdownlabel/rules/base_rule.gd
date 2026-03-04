@tool
extends RefCounted
class_name AIMarkdownRule

## Base class for Markdown parsing rules.

var parser

func _init(p_parser) -> void:
	parser = p_parser

## Processes a single line. Returns the processed line.
func process_line(line: String) -> String:
	return line

## Called before starting to parse a new text.
func reset() -> void:
	pass

## Called after all lines have been processed.
func finalize() -> String:
	return ""
