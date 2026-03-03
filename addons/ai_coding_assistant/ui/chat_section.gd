@tool
extends VBoxContainer
class_name AIChatSection

signal message_sent(message: String)
signal stop_requested
signal mode_requested(mode: String)
signal model_requested(model: String)

const MessageCard = preload("res://addons/ai_coding_assistant/ui/chat_message.gd")
const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")

var scroll_container: ScrollContainer
var chat_display: VBoxContainer
var input_field: TextEdit
var _thinking_card: AIChatMessage = null
var send_button: Button
var mode_button: OptionButton
var model_button: OptionButton

func _ready():
	_setup_ui()

func _setup_ui():
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	
	# Scroll area for messages
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)
	
	chat_display = VBoxContainer.new()
	chat_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_display.add_theme_constant_override("separation", 12)
	scroll_container.add_child(chat_display)
	
	# Premium Input Container
	var input_container = PanelContainer.new()
	var in_style = StyleBoxFlat.new()
	in_style.bg_color = AppTheme.COLOR_BG_MED
	in_style.corner_radius_top_left = 12
	in_style.corner_radius_top_right = 12
	in_style.corner_radius_bottom_left = 12
	in_style.corner_radius_bottom_right = 12
	in_style.content_margin_left = 10
	in_style.content_margin_right = 10
	in_style.content_margin_top = 10
	in_style.content_margin_bottom = 8
	input_container.add_theme_stylebox_override("panel", in_style)
	add_child(input_container)
	
	var input_vbox = VBoxContainer.new()
	input_container.add_child(input_vbox)
	
	input_field = TextEdit.new()
	input_field.placeholder_text = "Ask anything..."
	input_field.custom_minimum_size = Vector2(0, 80)
	input_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input_field.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	input_field.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	input_vbox.add_child(input_field)
	
	# Bottom Command Bar
	var cmd_hbox = HBoxContainer.new()
	cmd_hbox.add_theme_constant_override("separation", 8)
	input_vbox.add_child(cmd_hbox)
	
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.flat = true
	plus_btn.add_theme_color_override("font_color", AppTheme.COLOR_TEXT_DIM)
	cmd_hbox.add_child(plus_btn)
	
	mode_button = OptionButton.new()
	mode_button.flat = true
	mode_button.add_theme_font_size_override("font_size", 11)
	mode_button.add_item("Chat", 0)
	mode_button.add_item("Auto", 1)
	mode_button.add_item("Code", 2)
	mode_button.item_selected.connect(func(idx): mode_requested.emit(mode_button.get_item_text(idx).to_lower()))
	cmd_hbox.add_child(mode_button)
	
	model_button = OptionButton.new()
	model_button.flat = true
	model_button.add_theme_font_size_override("font_size", 11)
	model_button.item_selected.connect(func(idx): model_requested.emit(model_button.get_item_text(idx)))
	cmd_hbox.add_child(model_button)
	
	cmd_hbox.add_spacer(false)
	
	send_button = Button.new()
	send_button.text = "→"
	send_button.custom_minimum_size = Vector2(28, 28)
	var send_style = StyleBoxFlat.new()
	send_style.bg_color = AppTheme.COLOR_ACCENT
	send_style.corner_radius_top_left = 14
	send_style.corner_radius_top_right = 14
	send_style.corner_radius_bottom_left = 14
	send_style.corner_radius_bottom_right = 14
	send_button.add_theme_stylebox_override("normal", send_style)
	send_button.pressed.connect(func(): _on_send_pressed(input_field.text))
	cmd_hbox.add_child(send_button)

func show_thinking():
	if _thinking_card: return
	_thinking_card = MessageCard.new("Assistant", "Thinking...", AppTheme.COLOR_TEXT_DIM)
	chat_display.add_child(_thinking_card)
	_scroll_to_bottom()

func add_message(sender: String, text: String, color: Color = Color.WHITE):
	_remove_thinking()
	var card = MessageCard.new(sender, text, color)
	chat_display.add_child(card)
	_scroll_to_bottom()

var _last_streaming_card: AIChatMessage = null

func update_streaming_message(sender: String, text: String, color: Color = Color.WHITE):
	_remove_thinking()
	if _last_streaming_card and _last_streaming_card.get_meta("sender") == sender:
		_last_streaming_card.append_content(text)
	else:
		_last_streaming_card = MessageCard.new(sender, text, color)
		_last_streaming_card.set_meta("sender", sender)
		chat_display.add_child(_last_streaming_card)
	
	_scroll_to_bottom()

func finish_streaming():
	_last_streaming_card = null
	_remove_thinking()

func _remove_thinking():
	if _thinking_card:
		_thinking_card.queue_free()
		_thinking_card = null

func _scroll_to_bottom():
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func clear_chat():
	for child in chat_display.get_children():
		child.queue_free()

func set_models(models: Array):
	model_button.clear()
	for i in range(models.size()):
		model_button.add_item(models[i], i)

func set_model_label(name: String):
	for i in range(model_button.item_count):
		if model_button.get_item_text(i) == name:
			model_button.selected = i
			return

var _is_streaming: bool = false
func set_streaming_state(is_streaming: bool):
	_is_streaming = is_streaming
	if _is_streaming:
		send_button.text = "■"
		send_button.add_theme_color_override("font_color", Color.WHITE)
	else:
		send_button.text = "→"
		send_button.remove_theme_color_override("font_color")

func _on_send_pressed(text: String):
	if _is_streaming:
		stop_requested.emit()
		return
		
	if text.strip_edges().is_empty(): return
	input_field.clear()
	message_sent.emit(text)
