@tool
extends PanelContainer
class_name AIChatMessage

const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")
const MarkdownRenderer = preload("res://addons/ai_coding_assistant/utils/markdown_renderer.gd")

var sender_label: Label
var time_label: Label
var body_container: VBoxContainer
var _full_text: String = ""

func _init(sender: String, content: String, color: Color):
	_setup_ui(sender, content, color)

func _setup_ui(sender: String, content: String, color: Color):
	AppTheme.apply_card_style(self )
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	sender_label = Label.new()
	sender_label.text = sender
	sender_label.add_theme_color_override("font_color", color)
	sender_label.add_theme_font_size_override("font_size", 11)
	header.add_child(sender_label)
	
	header.add_spacer(false)
	
	time_label = Label.new()
	var time = Time.get_time_dict_from_system()
	time_label.text = "%02d:%02d" % [time.hour, time.minute]
	time_label.add_theme_color_override("font_color", AppTheme.COLOR_TEXT_DIM)
	time_label.add_theme_font_size_override("font_size", 10)
	header.add_child(time_label)
	
	body_container = VBoxContainer.new()
	body_container.add_theme_constant_override("separation", 6)
	vbox.add_child(body_container)
	
	set_content(content)

func set_content(text: String):
	_full_text = text
	MarkdownRenderer.render_to_vbox(body_container, _full_text)

func append_content(new_text: String):
	_full_text += new_text
	# Re-rendering everything is safer for streaming with code blocks
	MarkdownRenderer.render_to_vbox(body_container, _full_text)
