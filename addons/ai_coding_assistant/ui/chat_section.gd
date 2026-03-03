@tool
extends VBoxContainer
class_name AIChatSection

signal message_sent(message: String)

var chat_history: RichTextLabel
var input_field: LineEdit
var send_button: Button

func _ready():
	_setup_ui()

func _setup_ui():
	# Create header
	var chat_header = HBoxContainer.new()
	var chat_label = Label.new()
	chat_label.text = "💬 AI Chat"
	chat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_header.add_child(chat_label)
	
	var clear_btn = Button.new()
	clear_btn.text = "🗑️"
	clear_btn.tooltip_text = "Clear Chat"
	clear_btn.flat = true
	clear_btn.pressed.connect(clear_chat)
	chat_header.add_child(clear_btn)
	add_child(chat_header)

	# Chat history area
	var chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_history = RichTextLabel.new()
	chat_history.bbcode_enabled = true
	chat_history.scroll_following = true
	chat_history.selection_enabled = true
	chat_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.add_child(chat_history)
	add_child(chat_scroll)

	# Input area
	var input_hbox = HBoxContainer.new()
	input_field = LineEdit.new()
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.placeholder_text = "Ask anything..."
	input_field.text_submitted.connect(_on_input_submitted)
	
	send_button = Button.new()
	send_button.text = "Send"
	send_button.pressed.connect(_on_send_pressed)
	
	input_hbox.add_child(input_field)
	input_hbox.add_child(send_button)
	add_child(input_hbox)

func add_message(role: String, message: String, color: Color = Color.WHITE):
	if chat_history:
		chat_history.push_color(color)
		chat_history.append_text("[b]" + role + ":[/b] ")
		chat_history.pop()
		chat_history.append_text(message + "\n\n")

func clear_chat():
	if chat_history:
		chat_history.clear()

func _on_input_submitted(text: String):
	if not text.is_empty():
		message_sent.emit(text)
		input_field.clear()

func _on_send_pressed():
	_on_input_submitted(input_field.text)
