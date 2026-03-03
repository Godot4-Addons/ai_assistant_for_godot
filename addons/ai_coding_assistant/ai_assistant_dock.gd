@tool
extends Control

# Components
const ChatSection = preload("res://addons/ai_coding_assistant/ui/chat_section.gd")
const CodeSection = preload("res://addons/ai_coding_assistant/ui/code_section.gd")
const SettingsSection = preload("res://addons/ai_coding_assistant/ui/settings_section.gd")
const Formatter = preload("res://addons/ai_coding_assistant/utils/code_formatter.gd")
const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")

var api_manager: AIApiManager
var editor_integration
var plugin_editor_interface: EditorInterface

# UI Components
var chat_ui: AIChatSection
var code_ui: AICodeSection
var settings_ui: AISettingsSection
var settings_panel: PanelContainer

func _init():
	name = "AI Assistant"

func set_editor_interface(editor_interface: EditorInterface):
	plugin_editor_interface = editor_interface

func _ready():
	custom_minimum_size = Vector2(250, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	api_manager = AIApiManager.new()
	add_child(api_manager)
	api_manager.chunk_received.connect(_on_chunk_received)
	api_manager.response_received.connect(_on_response_received)
	api_manager.error_occurred.connect(_on_error_received)

	if plugin_editor_interface:
		editor_integration = preload("res://addons/ai_coding_assistant/editor_integration.gd").new(plugin_editor_interface)

	_setup_ui()
	_load_settings()
	chat_ui.set_model_label(api_manager.current_model)

func _setup_ui():
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Header with settings toggle
	var header = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = AppTheme.COLOR_BG_DARK
	h_style.content_margin_left = 8
	h_style.content_margin_right = 8
	h_style.content_margin_top = 4
	h_style.content_margin_bottom = 4
	header.add_theme_stylebox_override("panel", h_style)
	main_vbox.add_child(header)
	
	var header_hbox = HBoxContainer.new()
	header.add_child(header_hbox)
	
	var title = Label.new()
	title.text = "Godot AI ASSISTANT"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", AppTheme.COLOR_ACCENT_SOFT)
	header_hbox.add_child(title)
	
	header_hbox.add_spacer(false)
	
	var settings_btn = Button.new()
	settings_btn.text = "⚙️"
	settings_btn.flat = true
	settings_btn.pressed.connect(_toggle_settings)
	header_hbox.add_child(settings_btn)

	# Collapsible Settings
	settings_panel = PanelContainer.new()
	AppTheme.apply_card_style(settings_panel)
	settings_panel.visible = false
	main_vbox.add_child(settings_panel)
	
	settings_ui = SettingsSection.new()
	settings_ui.provider_changed.connect(_on_provider_changed)
	settings_ui.model_changed.connect(_on_model_changed)
	settings_ui.api_key_changed.connect(_on_api_key_changed)
	settings_panel.add_child(settings_ui)
	
	settings_ui.setup_providers(api_manager.get_provider_list())

	var splitter = VSplitContainer.new()
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	splitter.split_offset = 200
	main_vbox.add_child(splitter)

	# Chat
	var chat_container = VBoxContainer.new()
	chat_container.add_theme_constant_override("separation", 8)
	chat_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	splitter.add_child(chat_container)
	
	chat_ui = ChatSection.new()
	chat_ui.message_sent.connect(_on_chat_sent)
	chat_ui.stop_requested.connect(_on_stop_requested)
	chat_container.add_child(chat_ui)

	# Code Output
	code_ui = CodeSection.new()
	code_ui.apply_code.connect(_on_apply_code)
	code_ui.explain_code.connect(api_manager.explain_code)
	code_ui.improve_code.connect(api_manager.suggest_improvements)
	splitter.add_child(code_ui)

func _toggle_settings():
	settings_panel.visible = !settings_panel.visible

func _on_chat_sent(msg: String):
	chat_ui.add_message("User", msg, AppTheme.COLOR_ACCENT_SOFT)
	chat_ui.show_thinking()
	chat_ui.set_streaming_state(true)
	api_manager.send_chat_request(msg)

func _on_stop_requested():
	api_manager.cancel_request()
	chat_ui.set_streaming_state(false)

func _on_chunk_received(chunk: String):
	chat_ui.update_streaming_message("Assistant", chunk, AppTheme.COLOR_SUCCESS)

func _on_response_received(response: String):
	chat_ui.finish_streaming()
	chat_ui.set_streaming_state(false)
	var code = Formatter.extract_code(response)
	if not code.is_empty():
		code_ui.set_code(code)

func _on_error_received(err: String):
	chat_ui.add_message("Error", err, AppTheme.COLOR_ERROR)
	chat_ui.set_streaming_state(false)

func _on_provider_changed(provider: String):
	api_manager.set_provider(provider)
	chat_ui.set_model_label(api_manager.current_model)
	_save_settings()

func _on_model_changed(model: String):
	api_manager.set_model(model)
	_save_settings()

func _on_api_key_changed(key: String):
	api_manager.set_api_key(key)
	_save_settings()

func _on_apply_code(code: String):
	if editor_integration:
		editor_integration.insert_code_at_cursor(code)

func _on_action_triggered(type: String):
	match type:
		"generate_ui": api_manager.generate_code("Create a responsive UI system with a main menu.")
		"generate_save": api_manager.generate_code("Create a robust save system using JSON.")
		"generate_audio": api_manager.generate_code("Create a global audio manager.")
		"generate_player": api_manager.generate_code("Create a 2D/3D player controller.")
		"generate_enemy": api_manager.generate_code("Create a basic Finite State Machine for an enemy.")
		"generate_tests": api_manager.generate_code("Generate unit tests for the current script.")

func _save_settings():
	var config = ConfigFile.new()
	config.set_value("ai_assistant", "api_key", api_manager.api_key)
	config.set_value("ai_assistant", "provider", api_manager.api_provider)
	config.set_value("ai_assistant", "model", api_manager.current_model)
	config.save("user://ai_assistant_settings.cfg")

func _load_settings():
	var config = ConfigFile.new()
	if config.load("user://ai_assistant_settings.cfg") == OK:
		var key = config.get_value("ai_assistant", "api_key", "")
		var prov = config.get_value("ai_assistant", "provider", "gemini")
		var model = config.get_value("ai_assistant", "model", "")
		
		api_manager.set_api_key(key)
		api_manager.set_provider(prov)
		if not model.is_empty(): api_manager.set_model(model)
		
		settings_ui.set_api_key(key)
		settings_ui.set_model(api_manager.current_model)
		chat_ui.set_model_label(api_manager.current_model)
		
		var providers = api_manager.get_provider_list()
		var p_idx = providers.find(prov)
		if p_idx >= 0: settings_ui.provider_option.selected = p_idx
