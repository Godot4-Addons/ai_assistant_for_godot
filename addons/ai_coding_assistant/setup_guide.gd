@tool
extends Window
class_name AISetupGuide

const Data = preload("res://addons/ai_coding_assistant/config/setup_data.gd")

var step_label: Label
var instruction_text: RichTextLabel
var current_step: int = 0
var steps: Array = []

func _init():
	title = "AI Assistant Setup Guide"
	min_size = Vector2(600, 400)
	steps = Data.get_steps()
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	step_label = Label.new()
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(step_label)
	
	instruction_text = RichTextLabel.new()
	instruction_text.bbcode_enabled = true
	instruction_text.custom_minimum_size = Vector2(0, 250)
	vbox.add_child(instruction_text)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	
	var prev_btn = Button.new()
	prev_btn.text = "Previous"
	prev_btn.pressed.connect(_on_prev)
	btn_hbox.add_child(prev_btn)
	
	var next_btn = Button.new()
	next_btn.text = "Next"
	next_btn.pressed.connect(_on_next)
	btn_hbox.add_child(next_btn)
	
	_update_step()

func _update_step():
	var s = steps[current_step]
	step_label.text = s.title
	instruction_text.text = s.content

func _on_prev():
	if current_step > 0:
		current_step -= 1
		_update_step()

func _on_next():
	if current_step < steps.size() - 1:
		current_step += 1
		_update_step()
	else:
		hide()
