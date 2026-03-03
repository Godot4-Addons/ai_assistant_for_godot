@tool
extends RichTextLabel
class_name AIDiffDisplay

const Calculator = preload("res://addons/ai_coding_assistant/utils/diff_calculator.gd")

func display_diff(original: String, modified: String):
	clear()
	var orig_lines = original.split("\n")
	var mod_lines = modified.split("\n")
	var diff = Calculator.compute_diff(orig_lines, mod_lines)
	
	append_text("[b]Changes Summary:[/b]\n\n")
	var stats = {"add": 0, "remove": 0, "modify": 0}
	
	for change in diff:
		stats[change.type] += 1
		var color = "green" if change.type == "add" else ("red" if change.type == "remove" else "yellow")
		var prefix = "+" if change.type == "add" else ("-" if change.type == "remove" else "~")
		append_text("[color=" + color + "]" + prefix + " " + change.text + "[/color]\n")
		
	append_text("\n[b]Statistics:[/b]\n")
	append_text("[color=green]Additions: " + str(stats.add) + "[/color]\n")
	append_text("[color=red]Deletions: " + str(stats.remove) + "[/color]\n")
	append_text("[color=yellow]Modifications: " + str(stats.modify) + "[/color]\n")
