@tool
extends PanelContainer
class_name AISelectionToolbar

signal add_to_chat_requested(text: String)
signal clear_requested

const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")

var label: Label
var add_btn: Button
var clear_btn: Button

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = AppTheme.COLOR_BG_DARK
	style.border_color = AppTheme.COLOR_ACCENT
	style.border_width_bottom = 1
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)

	var icon := Label.new()
	icon.text = "📝"
	hbox.add_child(icon)

	label = Label.new()
	label.text = "No selection"
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", AppTheme.COLOR_TEXT_DIM)
	hbox.add_child(label)

	add_btn = Button.new()
	add_btn.text = "Add to Chat"
	add_btn.flat = true
	add_btn.add_theme_font_size_override("font_size", 11)
	add_btn.pressed.connect(_on_add_pressed)
	hbox.add_child(add_btn)

	clear_btn = Button.new()
	clear_btn.text = "✕"
	clear_btn.flat = true
	clear_btn.add_theme_font_size_override("font_size", 11)
	clear_btn.pressed.connect(_on_clear_pressed)
	hbox.add_child(clear_btn)
	
	visible = false

func update_selection(text: String) -> void:
	if text.strip_edges().is_empty():
		visible = false
		return
	
	visible = true
	var preview = text.strip_edges().replace("\n", " ")
	if preview.length() > 40:
		preview = preview.left(37) + "..."
	label.text = "Selection: " + preview
	label.remove_theme_color_override("font_color")

func _on_add_pressed() -> void:
	add_to_chat_requested.emit(label.get_meta("full_text", ""))

func _on_clear_pressed() -> void:
	clear_requested.emit()

func set_full_text(text: String) -> void:
	label.set_meta("full_text", text)
	update_selection(text)
