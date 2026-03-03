@tool
extends Window
class_name AIDiffViewer

signal changes_accepted(new_code: String)
signal changes_rejected()

const Display = preload("res://addons/ai_coding_assistant/ui/diff_display.gd")

var original_text: TextEdit
var modified_text: TextEdit
var diff_display: AIDiffDisplay

func _init():
	title = "Code Diff Viewer"
	size = Vector2(800, 600)
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var hsplit = HSplitContainer.new()
	hsplit.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(hsplit)
	
	original_text = TextEdit.new()
	original_text.editable = false
	hsplit.add_child(original_text)
	
	modified_text = TextEdit.new()
	modified_text.editable = true
	modified_text.text_changed.connect(_on_text_changed)
	hsplit.add_child(modified_text)
	
	diff_display = Display.new()
	diff_display.bbcode_enabled = true
	diff_display.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(diff_display)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	
	var rej_btn = Button.new()
	rej_btn.text = "Reject"
	rej_btn.pressed.connect(func(): changes_rejected.emit(); hide())
	btn_hbox.add_child(rej_btn)
	
	var acc_btn = Button.new()
	acc_btn.text = "Accept"
	acc_btn.pressed.connect(func(): changes_accepted.emit(modified_text.text); hide())
	btn_hbox.add_child(acc_btn)

func show_diff(orig: String, mod: String):
	original_text.text = orig
	modified_text.text = mod
	diff_display.display_diff(orig, mod)
	popup_centered()

func _on_text_changed():
	diff_display.display_diff(original_text.text, modified_text.text)
