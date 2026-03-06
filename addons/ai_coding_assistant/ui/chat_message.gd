@tool
extends PanelContainer
class_name AIChatMessage

const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")
const MarkdownLabelClass = preload("res://addons/ai_coding_assistant/markdownlabel/markdownlabel.gd")
const CodeHighlighterScript = preload("res://addons/ai_coding_assistant/markdownlabel/syntax_highlighter.gd")

signal apply_code_requested(code: String)

var sender_label: Label
var time_label: Label
var body_container: VBoxContainer
var _full_text: String = ""
var _is_streaming: bool = false
var _stream_label: RichTextLabel = null
var _highlighter = CodeHighlighterScript.new()

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
	body_container.add_theme_constant_override("separation", 4)
	vbox.add_child(body_container)
	
	set_content(content)

func set_content(text: String):
	_full_text = text
	for child in body_container.get_children():
		child.queue_free()
	
	var segments: Array = AIMarkdownParser.split_segments(_full_text)
	for seg in segments:
		if seg.type == "code":
			_add_code_block(seg.language, seg.content)
		elif seg.type == "text":
			var content_str: String = seg.content
			if content_str.strip_edges().is_empty():
				continue
			_add_markdown_label(content_str)

func _add_markdown_label(content: String) -> void:
	var md_label = MarkdownLabelClass.new()
	md_label.fit_content = true
	md_label.selection_enabled = true
	md_label.context_menu_enabled = true
	md_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	md_label.add_theme_font_size_override("normal_font_size", 12)
	body_container.add_child(md_label)
	md_label.markdown_text = content

func _add_code_block(language: String, code: String) -> void:
	# Outer panel with dark bg, rounded corners, border
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#0d1117") # GitHub dark bg
	style.border_color = Color("#30363d") # Subtle border
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	body_container.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	
	# Header bar with language label + copy button
	var header_bar = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color("#161b22") # Slightly lighter header
	header_style.corner_radius_top_left = 6
	header_style.corner_radius_top_right = 6
	header_style.content_margin_left = 12
	header_style.content_margin_right = 8
	header_style.content_margin_top = 6
	header_style.content_margin_bottom = 6
	header_bar.add_theme_stylebox_override("panel", header_style)
	vbox.add_child(header_bar)
	
	var header_hbox = HBoxContainer.new()
	header_bar.add_child(header_hbox)
	
	# Language label
	var lang_label = Label.new()
	lang_label.text = language if language != "" else "code"
	lang_label.add_theme_color_override("font_color", Color("#8b949e"))
	lang_label.add_theme_font_size_override("font_size", 10)
	header_hbox.add_child(lang_label)
	
	header_hbox.add_spacer(false)
	
	# Copy button
	var copy_btn = Button.new()
	copy_btn.text = "  📋 Copy  "
	copy_btn.flat = true
	copy_btn.add_theme_font_size_override("font_size", 10)
	copy_btn.add_theme_color_override("font_color", Color("#8b949e"))
	copy_btn.add_theme_color_override("font_hover_color", Color("#c9d1d9"))
	copy_btn.pressed.connect(func(): _copy_code(code, copy_btn))
	header_hbox.add_child(copy_btn)
	
	# Apply button
	var apply_btn = Button.new()
	apply_btn.text = "  ✨ Apply  "
	apply_btn.flat = true
	apply_btn.add_theme_font_size_override("font_size", 10)
	apply_btn.add_theme_color_override("font_color", Color("#8b949e"))
	apply_btn.add_theme_color_override("font_hover_color", Color("#58a6ff"))
	apply_btn.pressed.connect(func(): _apply_code(code, apply_btn))
	header_hbox.add_child(apply_btn)
	
	# Code content area
	var code_panel = PanelContainer.new()
	var code_style = StyleBoxFlat.new()
	code_style.bg_color = Color("#0d1117")
	code_style.corner_radius_bottom_left = 6
	code_style.corner_radius_bottom_right = 6
	code_style.content_margin_left = 12
	code_style.content_margin_right = 12
	code_style.content_margin_top = 8
	code_style.content_margin_bottom = 8
	code_panel.add_theme_stylebox_override("panel", code_style)
	vbox.add_child(code_panel)
	
	var code_label = RichTextLabel.new()
	code_label.bbcode_enabled = true
	code_label.fit_content = true
	code_label.scroll_active = false
	code_label.selection_enabled = true
	code_label.context_menu_enabled = true
	code_label.deselect_on_focus_loss_enabled = true
	code_label.add_theme_font_size_override("normal_font_size", 12)
	code_label.add_theme_font_size_override("mono_font_size", 12)
	code_label.add_theme_color_override("default_color", Color("#c9d1d9"))
	code_label.add_theme_color_override("selection_color", Color(0.23, 0.51, 0.96, 0.35))
	code_label.add_theme_color_override("font_selected_color", Color.WHITE)
	code_panel.add_child(code_label)
	
	# Apply syntax highlighting
	var escape_fn := func(text: String) -> String:
		return text.replace("[", "\uFFFD").replace("]", "[rb]").replace("\uFFFD", "[lb]")
	
	if language != "":
		code_label.text = "[code]" + _highlighter.highlight(code, language, escape_fn) + "[/code]"
	else:
		code_label.text = "[code]" + escape_fn.call(code) + "[/code]"

func _copy_code(code: String, btn: Button) -> void:
	DisplayServer.clipboard_set(code)
	btn.text = "  ✅ Copied!  "
	# Reset after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if is_instance_valid(btn):
			btn.text = "  📋 Copy  "
	)

func _apply_code(code: String, btn: Button) -> void:
	apply_code_requested.emit(code)
	btn.text = "  🚀 Applied!  "
	# Reset after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if is_instance_valid(btn):
			btn.text = "  ✨ Apply  "
	)

func append_content(new_text: String):
	_full_text += new_text
	if not _is_streaming:
		_is_streaming = true
		for child in body_container.get_children():
			child.queue_free()
		_stream_label = RichTextLabel.new()
		_stream_label.fit_content = true
		_stream_label.selection_enabled = true
		_stream_label.context_menu_enabled = true
		_stream_label.deselect_on_focus_loss_enabled = true
		_stream_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_stream_label.add_theme_font_size_override("normal_font_size", 12)
		_stream_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
		_stream_label.add_theme_color_override("selection_color", Color(0.23, 0.51, 0.96, 0.35))
		_stream_label.add_theme_color_override("font_selected_color", Color.WHITE)
		body_container.add_child(_stream_label)
	
	_stream_label.text = _full_text

func finalize_streaming():
	if _is_streaming:
		_is_streaming = false
		_stream_label = null
		set_content(_full_text)
