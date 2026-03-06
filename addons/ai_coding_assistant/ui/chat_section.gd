@tool
extends VBoxContainer
class_name AIChatSection

signal message_sent(message: String)
signal stop_requested
signal clear_requested
signal mode_requested(mode: String)
signal model_requested(model: String)
signal apply_code_requested(code: String)

const MessageCard = preload("res://addons/ai_coding_assistant/ui/chat_message.gd")
const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")

var scroll_container: ScrollContainer
var chat_display: VBoxContainer
var input_field: TextEdit
var send_button: Button
var mode_button: OptionButton
var model_button: OptionButton

var _available_modes: Dictionary = {}

var _thinking_card: AIChatMessage = null
var _last_streaming_card: AIChatMessage = null
var _is_streaming: bool = false

# Agent status bar
var _agent_status_bar: PanelContainer = null
var _agent_status_label: Label = null

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	# ── Scroll area ──
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)

	chat_display = VBoxContainer.new()
	chat_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_display.add_theme_constant_override("separation", 10)
	chat_display.child_entered_tree.connect(func(node):
		if node is MessageCard:
			node.apply_code_requested.connect(func(code): apply_code_requested.emit(code))
	)
	scroll_container.add_child(chat_display)

	# ── Agent status bar (hidden by default) ──
	_agent_status_bar = PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	bar_style.border_color = AppTheme.COLOR_ACCENT
	bar_style.border_width_bottom = 1
	bar_style.content_margin_left = 10
	bar_style.content_margin_right = 10
	bar_style.content_margin_top = 5
	bar_style.content_margin_bottom = 5
	_agent_status_bar.add_theme_stylebox_override("panel", bar_style)
	_agent_status_bar.visible = false
	add_child(_agent_status_bar)

	_agent_status_label = Label.new()
	_agent_status_label.add_theme_font_size_override("font_size", 11)
	_agent_status_label.add_theme_color_override("font_color", AppTheme.COLOR_ACCENT_SOFT)
	_agent_status_bar.add_child(_agent_status_label)

	# ── Input container ──
	var input_container := PanelContainer.new()
	var in_style := StyleBoxFlat.new()
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

	var input_vbox := VBoxContainer.new()
	input_container.add_child(input_vbox)

	input_field = TextEdit.new()
	input_field.placeholder_text = "Ask anything... (Shift+Enter = new line)"
	input_field.custom_minimum_size = Vector2(0, 80)
	input_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input_field.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	input_field.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	input_vbox.add_child(input_field)

	# ── Command bar ──
	var cmd_hbox := HBoxContainer.new()
	cmd_hbox.add_theme_constant_override("separation", 6)
	input_vbox.add_child(cmd_hbox)

	var clear_btn := Button.new()
	clear_btn.text = "🗑️"
	clear_btn.flat = true
	clear_btn.tooltip_text = "Clear history"
	clear_btn.pressed.connect(func():
		clear_chat()
		clear_requested.emit()
	)
	cmd_hbox.add_child(clear_btn)

	mode_button = OptionButton.new()
	mode_button.flat = true
	mode_button.add_theme_font_size_override("font_size", 11)
	_update_mode_list()
	mode_button.item_selected.connect(func(idx):
		var mode_id = mode_button.get_item_metadata(idx)
		mode_requested.emit(mode_id)
	)
	cmd_hbox.add_child(mode_button)

	model_button = OptionButton.new()
	model_button.flat = true
	model_button.add_theme_font_size_override("font_size", 11)
	model_button.item_selected.connect(func(idx): model_requested.emit(model_button.get_item_text(idx)))
	cmd_hbox.add_child(model_button)

	cmd_hbox.add_spacer(false)

	send_button = Button.new()
	send_button.text = "→"
	send_button.custom_minimum_size = Vector2(32, 32)
	var send_style := StyleBoxFlat.new()
	send_style.bg_color = AppTheme.COLOR_ACCENT
	send_style.corner_radius_top_left = 16
	send_style.corner_radius_top_right = 16
	send_style.corner_radius_bottom_left = 16
	send_style.corner_radius_bottom_right = 16
	send_button.add_theme_stylebox_override("normal", send_style)
	send_button.pressed.connect(func(): _on_send_pressed(input_field.text))
	cmd_hbox.add_child(send_button)

# ─────────────────────────────────────────────────────────────────────────────
# Agent Status UI
# ─────────────────────────────────────────────────────────────────────────────

func set_agent_status(message: String) -> void:
	if _agent_status_bar:
		_agent_status_label.text = message
		_agent_status_bar.visible = true

func clear_agent_status() -> void:
	if _agent_status_bar:
		_agent_status_bar.visible = false

func add_agent_note(message: String) -> void:
	_remove_thinking()
	var card := MessageCard.new("🤖 Agent", message, Color(0.4, 0.8, 1.0))
	chat_display.add_child(card)
	_scroll_to_bottom()

func add_tool_card(tool_name: String, message: String, is_error: bool = false) -> void:
	var color := AppTheme.COLOR_ERROR if is_error else Color(0.3, 0.9, 0.5)
	var label := "❌ " + tool_name if is_error else "🔧 " + tool_name
	var card := MessageCard.new(label, message, color)
	chat_display.add_child(card)
	_scroll_to_bottom()

func show_confirmation(description: String, callback: Callable) -> void:
	_remove_thinking()

	# Build confirmation card
	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.2, 0.15, 0.05, 0.95)
	pstyle.border_color = Color(1.0, 0.7, 0.0)
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.content_margin_left = 12
	pstyle.content_margin_right = 12
	pstyle.content_margin_top = 10
	pstyle.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", pstyle)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚠️ Agent Permission Required"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(title)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(desc_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	vbox.add_child(btns)

	var allow_btn := Button.new()
	allow_btn.text = "✅ Allow"
	var a_style := StyleBoxFlat.new()
	a_style.bg_color = Color(0.1, 0.5, 0.1)
	a_style.corner_radius_top_left = 4
	a_style.corner_radius_top_right = 4
	a_style.corner_radius_bottom_left = 4
	a_style.corner_radius_bottom_right = 4
	allow_btn.add_theme_stylebox_override("normal", a_style)
	btns.add_child(allow_btn)

	var deny_btn := Button.new()
	deny_btn.text = "❌ Deny"
	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.5, 0.1, 0.1)
	d_style.corner_radius_top_left = 4
	d_style.corner_radius_top_right = 4
	d_style.corner_radius_bottom_left = 4
	d_style.corner_radius_bottom_right = 4
	deny_btn.add_theme_stylebox_override("normal", d_style)
	btns.add_child(deny_btn)

	# Wire buttons — remove panel after choice
	allow_btn.pressed.connect(func():
		panel.queue_free()
		callback.call(true)
	)
	deny_btn.pressed.connect(func():
		panel.queue_free()
		callback.call(false)
	)

	chat_display.add_child(panel)
	_scroll_to_bottom()

# ─────────────────────────────────────────────────────────────────────────────
# Standard Chat UI
# ─────────────────────────────────────────────────────────────────────────────

func show_thinking() -> void:
	if _thinking_card: return
	_thinking_card = MessageCard.new("Assistant", "Thinking...", AppTheme.COLOR_TEXT_DIM)
	chat_display.add_child(_thinking_card)
	_scroll_to_bottom()

func add_message(sender: String, text: String, color: Color = Color.WHITE) -> void:
	_remove_thinking()
	var card := MessageCard.new(sender, text, color)
	chat_display.add_child(card)
	_scroll_to_bottom()

func update_streaming_message(sender: String, text: String, color: Color = Color.WHITE) -> void:
	_remove_thinking()
	if _last_streaming_card and _last_streaming_card.get_meta("sender", "") == sender:
		_last_streaming_card.append_content(text)
	else:
		_last_streaming_card = MessageCard.new(sender, text, color)
		_last_streaming_card.set_meta("sender", sender)
		chat_display.add_child(_last_streaming_card)
	_scroll_to_bottom()

func finish_streaming() -> void:
	if _last_streaming_card:
		_last_streaming_card.finalize_streaming()
	_last_streaming_card = null
	_remove_thinking()

func _remove_thinking() -> void:
	if _thinking_card:
		_thinking_card.queue_free()
		_thinking_card = null

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(scroll_container):
		return
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func clear_chat() -> void:
	for child in chat_display.get_children():
		child.queue_free()

func set_available_modes(modes: Dictionary) -> void:
	_available_modes = modes
	_update_mode_list()

func _update_mode_list() -> void:
	if not mode_button: return
	
	mode_button.clear()
	var i = 0
	for id in _available_modes:
		var data = _available_modes[id]
		mode_button.add_item(data.icon + " " + data.label, i)
		mode_button.set_item_metadata(i, id)
		i += 1

func append_to_input(text: String) -> void:
	if text.is_empty(): return
	var current := input_field.text
	if not current.is_empty() and not current.ends_with("\n"):
		current += "\n"
	
	var formatted := "\n```gdscript\n%s\n```\n" % text
	input_field.text = current + formatted
	input_field.set_caret_line(input_field.get_line_count())
	input_field.grab_focus()

func set_models(models: Array) -> void:
	model_button.clear()
	for i in range(models.size()):
		model_button.add_item(models[i], i)

func set_model_label(name: String) -> void:
	for i in range(model_button.item_count):
		if model_button.get_item_text(i) == name:
			model_button.selected = i
			return

func set_streaming_state(is_streaming: bool) -> void:
	_is_streaming = is_streaming
	if _is_streaming:
		send_button.text = "■"
		send_button.add_theme_color_override("font_color", Color.WHITE)
	else:
		send_button.text = "→"
		send_button.remove_theme_color_override("font_color")

func _on_send_pressed(text: String) -> void:
	if _is_streaming:
		stop_requested.emit()
		return
	if text.strip_edges().is_empty(): return
	input_field.clear()
	message_sent.emit(text)
