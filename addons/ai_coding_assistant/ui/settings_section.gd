@tool
extends VBoxContainer
class_name AISettingsSection

signal provider_changed(provider: String)
signal model_changed(model: String)
signal api_key_changed(key: String)
signal context_changed(text: String)
signal new_session_requested()
signal session_switched(session_id: String)
signal session_renamed(new_name: String)
signal session_deleted(session_id: String)

var provider_option: OptionButton
var model_field: LineEdit
var api_key_field: LineEdit
var context_field: TextEdit
var session_option: OptionButton
var rename_edit: LineEdit
var rename_confirm_btn: Button
var new_session_button: Button

func _ready():
	_setup_ui()

func _setup_ui():
	if get_child_count() > 0: return # Already setup
	var settings_content = VBoxContainer.new()
	
	# Provider selection
	var provider_hbox = HBoxContainer.new()
	var provider_label = Label.new()
	provider_label.text = "Provider:"
	provider_label.custom_minimum_size = Vector2(80, 0)
	
	provider_option = OptionButton.new()
	provider_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	provider_option.item_selected.connect(_on_provider_selected)
	
	provider_hbox.add_child(provider_label)
	provider_hbox.add_child(provider_option)
	settings_content.add_child(provider_hbox)

	# Model input
	var model_hbox = HBoxContainer.new()
	var model_label = Label.new()
	model_label.text = "Model:"
	model_label.custom_minimum_size = Vector2(80, 0)
	
	model_field = LineEdit.new()
	model_field.placeholder_text = "e.g. gpt-4o, gemini-1.5-pro, etc."
	model_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_field.text_changed.connect(_on_model_changed)
	
	model_hbox.add_child(model_label)
	model_hbox.add_child(model_field)
	settings_content.add_child(model_hbox)

	# API Key
	var api_key_hbox = HBoxContainer.new()
	var api_key_label = Label.new()
	api_key_label.text = "API Key:"
	api_key_label.custom_minimum_size = Vector2(80, 0)
	
	api_key_field = LineEdit.new()
	api_key_field.secret = true
	api_key_field.placeholder_text = "Enter API Key"
	api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	api_key_field.text_changed.connect(_on_api_key_changed)
	
	api_key_hbox.add_child(api_key_label)
	api_key_hbox.add_child(api_key_field)
	settings_content.add_child(api_key_hbox)

	# Global Context
	var context_vbox = VBoxContainer.new()
	var context_label = Label.new()
	context_label.text = "Global Context (System Prompt):"
	
	context_field = TextEdit.new()
	context_field.custom_minimum_size = Vector2(0, 80)
	context_field.placeholder_text = "e.g. Always answer in French, or Act as a Godot expert..."
	context_field.text_changed.connect(func(): context_changed.emit(context_field.text))
	
	context_vbox.add_child(context_label)
	context_vbox.add_child(context_field)
	settings_content.add_child(context_vbox)

	# Session Management
	var session_vbox = VBoxContainer.new()
	var session_label = Label.new()
	session_label.text = "Session Management:"
	session_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
	
	var session_hbox = HBoxContainer.new()
	
	session_option = OptionButton.new()
	session_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session_option.item_selected.connect(func(idx):
		var sid = session_option.get_item_metadata(idx)
		if sid: session_switched.emit(sid)
	)
	
	var rename_btn = Button.new()
	rename_btn.text = "✏️"
	rename_btn.flat = true
	rename_btn.tooltip_text = "Rename Session"
	rename_btn.pressed.connect(_on_rename_pressed)
	
	var delete_btn = Button.new()
	delete_btn.text = "🗑️"
	delete_btn.flat = true
	delete_btn.tooltip_text = "Delete Session"
	delete_btn.pressed.connect(_on_delete_pressed)
	
	new_session_button = Button.new()
	new_session_button.text = "➕ New Chat"
	new_session_button.pressed.connect(func(): new_session_requested.emit())
	
	session_hbox.add_child(session_option)
	session_hbox.add_child(rename_btn)
	session_hbox.add_child(delete_btn)
	session_hbox.add_child(new_session_button)
	
	# Inline rename field (hidden by default)
	rename_edit = LineEdit.new()
	rename_edit.visible = false
	rename_edit.placeholder_text = "Enter new name..."
	rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_edit.text_submitted.connect(_on_rename_confirmed)
	
	session_vbox.add_child(session_label)
	session_vbox.add_child(session_hbox)
	session_vbox.add_child(rename_edit)
	settings_content.add_child(HSeparator.new())
	settings_content.add_child(session_vbox)

	add_child(settings_content)

func setup_providers(providers: Array):
	_setup_ui()
	provider_option.clear()
	for p in providers:
		provider_option.add_item(p.capitalize())

func set_model(model: String):
	_setup_ui()
	model_field.text = model

func set_api_key(key: String):
	_setup_ui()
	api_key_field.text = key

func _on_provider_selected(index: int):
	provider_changed.emit(provider_option.get_item_text(index).to_lower())

func _on_model_changed(text: String):
	model_changed.emit(text)

func _on_api_key_changed(text: String):
	api_key_changed.emit(text)

func set_global_context(text: String):
	_setup_ui()
	context_field.text = text

func set_session_list(sessions: Array, current_id: String):
	_setup_ui()
	session_option.clear()
	for sid in sessions:
		var idx = session_option.get_item_count()
		session_option.add_item(sid.replace("chat_", " ").replace("_", " "))
		session_option.set_item_metadata(idx, sid)
		if sid == current_id:
			session_option.selected = idx
			rename_edit.text = sid.replace("chat_", "").replace("_", " ")

func _on_rename_pressed():
	rename_edit.visible = !rename_edit.visible
	if rename_edit.visible:
		rename_edit.grab_focus()

func _on_rename_confirmed(new_text: String):
	if not new_text.is_empty():
		session_renamed.emit(new_text)
	rename_edit.visible = false

func _on_delete_pressed():
	var sid = session_option.get_item_metadata(session_option.selected)
	if sid:
		session_deleted.emit(sid)
