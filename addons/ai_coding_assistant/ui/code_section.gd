@tool
extends VBoxContainer
class_name AICodeSection

signal apply_code(code: String)
signal explain_code(code: String)
signal improve_code(code: String)

var code_output: TextEdit
var code_copy_button: Button
var code_save_button: Button

func _ready():
	_setup_ui()

func _setup_ui():
	# Header
	var code_header = HBoxContainer.new()
	var code_label = Label.new()
	code_label.text = "💻 Generated Code"
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_header.add_child(code_label)
	
	code_copy_button = Button.new()
	code_copy_button.text = "📋"
	code_copy_button.tooltip_text = "Copy Code"
	code_copy_button.flat = true
	code_copy_button.pressed.connect(_on_copy_code)
	code_header.add_child(code_copy_button)
	
	add_child(code_header)

	# Code output
	code_output = TextEdit.new()
	code_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_output.editable = true
	code_output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code_output.add_theme_font_override("font", ThemeDB.fallback_font)
	add_child(code_output)

	# Action buttons
	var button_hbox = HBoxContainer.new()
	var apply_btn = Button.new()
	apply_btn.text = "✨ Apply to Editor"
	apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_btn.pressed.connect(func(): apply_code.emit(code_output.text))
	
	var explain_btn = Button.new()
	explain_btn.text = "🔍 Explain"
	explain_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explain_btn.pressed.connect(func(): explain_code.emit(code_output.text))

	var improve_btn = Button.new()
	improve_btn.text = "🚀 Improve"
	improve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	improve_btn.pressed.connect(func(): improve_code.emit(code_output.text))

	button_hbox.add_child(apply_btn)
	button_hbox.add_child(explain_btn)
	button_hbox.add_child(improve_btn)
	add_child(button_hbox)

func set_code(code: String):
	if code_output:
		code_output.text = code

func get_code() -> String:
	return code_output.text if code_output else ""

func _on_copy_code():
	DisplayServer.clipboard_set(code_output.text)
