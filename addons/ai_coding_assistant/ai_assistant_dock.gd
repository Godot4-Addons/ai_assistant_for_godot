@tool
extends Control

# Components
const ChatSection = preload("res://addons/ai_coding_assistant/ui/chat_section.gd")
const SettingsSection = preload("res://addons/ai_coding_assistant/ui/settings_section.gd")
const AppTheme = preload("res://addons/ai_coding_assistant/ui/ui_theme.gd")
const SelectionManager = preload("res://addons/ai_coding_assistant/editor/selection_manager.gd")
const SelectionToolbar = preload("res://addons/ai_coding_assistant/ui/selection_toolbar.gd")

var api_manager: AIApiManager
var editor_integration
var plugin_editor_interface: EditorInterface
var selection_manager: AISelectionManager

# UI Components
var chat_ui: AIChatSection
var settings_ui: AISettingsSection
var settings_panel: PanelContainer
var selection_toolbar: AISelectionToolbar

var plugin_instance: EditorPlugin

func _init() -> void:
	name = "AI Assistant"

func set_plugin_instance(plugin: EditorPlugin) -> void:
	plugin_instance = plugin

func set_editor_interface(editor_interface: EditorInterface) -> void:
	plugin_editor_interface = editor_interface

func _ready() -> void:
	custom_minimum_size = Vector2(250, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	api_manager = AIApiManager.new()
	add_child(api_manager)

	# Standard streaming signals (chat mode)
	api_manager.chunk_received.connect(_on_chunk_received)
	api_manager.response_received.connect(_on_response_received)
	api_manager.error_occurred.connect(_on_error_received)

	# Set up editor integration
	if plugin_editor_interface:
		editor_integration = preload("res://addons/ai_coding_assistant/editor_integration.gd").new(plugin_editor_interface, plugin_instance)
		api_manager.setup_agent(editor_integration, plugin_editor_interface)
		selection_manager = SelectionManager.new(editor_integration.reader)
		selection_manager.selection_updated.connect(_on_selection_updated)

	# Agent signals
	api_manager.agent_status_changed.connect(_on_agent_status_changed)
	api_manager.agent_tool_executed.connect(_on_agent_tool_executed)
	api_manager.agent_thinking.connect(_on_agent_thinking)
	api_manager.agent_permission_needed.connect(_on_permission_needed)

	_setup_ui()
	_load_settings()
	chat_ui.set_model_label(api_manager.current_model)

func _setup_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Header
	var header := PanelContainer.new()
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = AppTheme.COLOR_BG_DARK
	h_style.content_margin_left = 8
	h_style.content_margin_right = 8
	h_style.content_margin_top = 4
	h_style.content_margin_bottom = 4
	header.add_theme_stylebox_override("panel", h_style)
	main_vbox.add_child(header)

	var header_hbox := HBoxContainer.new()
	header.add_child(header_hbox)

	var title := Label.new()
	title.text = "Godot AI ASSISTANT"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", AppTheme.COLOR_ACCENT_SOFT)
	header_hbox.add_child(title)

	header_hbox.add_spacer(false)

	var settings_btn := Button.new()
	settings_btn.text = "⚙️"
	settings_btn.flat = true
	settings_btn.pressed.connect(_toggle_settings)
	header_hbox.add_child(settings_btn)

	# Collapsible settings
	settings_panel = PanelContainer.new()
	AppTheme.apply_card_style(settings_panel)
	settings_panel.visible = false
	main_vbox.add_child(settings_panel)

	# Selection Toolbar
	selection_toolbar = SelectionToolbar.new()
	selection_toolbar.add_to_chat_requested.connect(_on_add_to_chat_requested)
	selection_toolbar.clear_requested.connect(_on_clear_selection_requested)
	main_vbox.add_child(selection_toolbar)

	settings_ui = SettingsSection.new()
	settings_ui.provider_changed.connect(_on_provider_changed)
	settings_ui.model_changed.connect(_on_model_changed)
	settings_ui.api_key_changed.connect(_on_api_key_changed)
	settings_ui.context_changed.connect(_on_context_changed)
	settings_ui.new_session_requested.connect(_on_new_session_requested)
	settings_ui.session_switched.connect(_on_session_switched)
	settings_ui.session_renamed.connect(_on_session_renamed)
	settings_ui.session_deleted.connect(_on_session_deleted)
	settings_panel.add_child(settings_ui)
	settings_ui.setup_providers(api_manager.get_provider_list())

	# Chat
	var chat_container := VBoxContainer.new()
	chat_container.add_theme_constant_override("separation", 8)
	chat_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(chat_container)

	chat_ui = ChatSection.new()
	chat_ui.set_available_modes(api_manager.available_modes)
	chat_ui.set_editor_integration(editor_integration)
	chat_ui.message_sent.connect(_on_chat_sent)
	chat_ui.stop_requested.connect(_on_stop_requested)
	chat_ui.clear_requested.connect(_on_clear_requested)
	chat_ui.mode_requested.connect(func(mode): api_manager.current_mode = mode)
	chat_ui.apply_code_requested.connect(_on_apply_code_requested)
	chat_ui.undo_requested.connect(func(): editor_integration.writer.perform_undo())
	chat_container.add_child(chat_ui)
	
	_refresh_session_ui()

# ─────────────────────────────────────────────────────────────────────────────
# Chat Events
# ─────────────────────────────────────────────────────────────────────────────

func _on_chat_sent(msg: String) -> void:
	chat_ui.add_message("User", msg, AppTheme.COLOR_ACCENT_SOFT)
	chat_ui.show_thinking()
	chat_ui.set_streaming_state(true)
	api_manager.send_chat_request(msg)

func _on_stop_requested() -> void:
	# Stop agent first (handles its own SSE cancel internally)
	if api_manager.agent_loop and is_instance_valid(api_manager.agent_loop):
		api_manager.agent_loop.stop()
	# Then clean up any remaining SSE (safe: api_manager.cancel_request does NOT call agent_loop.stop)
	api_manager.cancel_request()
	chat_ui.set_streaming_state(false)
	chat_ui.clear_agent_status()

func _on_selection_updated(text: String) -> void:
	if selection_toolbar:
		selection_toolbar.set_full_text(text)

func _on_add_to_chat_requested(text: String) -> void:
	if text.strip_edges().is_empty(): return
	chat_ui.append_to_input(text)

func _on_clear_selection_requested() -> void:
	if selection_manager:
		selection_manager.clear_selection()

func _on_apply_code_requested(code: String) -> void:
	if not editor_integration: return
	
	var processed_code = _filter_code_from_json(code)
	
	# Safety Check: Validate syntax before applying
	if editor_integration.writer.has_method("validate_syntax"):
		if not editor_integration.writer.validate_syntax(processed_code):
			_on_error_received("Warning: AI generated code may have syntax errors (unmatched brackets).")
	
	# Detect Smart Apply type
	var apply_info = editor_integration.writer.detect_apply_type(processed_code)
	print("AI Assistant: Apply Type detected: ", apply_info.type)
	
	if apply_info.type == "full_replace":
		chat_ui.show_confirmation(
			"This looks like a full script. Do you want to REPLACE the entire current file?",
			func(confirmed):
				if confirmed:
					editor_integration.writer.create_backup(editor_integration.get_current_file_path())
					editor_integration.writer.replace_all_text(processed_code)
				else:
					# Default to insert at cursor
					editor_integration.writer.insert_text_at_cursor(processed_code)
		)
	elif apply_info.type == "function_replace":
		var f_name = apply_info.get("func_name", "unknown")
		chat_ui.show_confirmation(
			"This matches function '%s'. Do you want to REPLACE the existing function?" % f_name,
			func(confirmed):
				if confirmed:
					editor_integration.writer.create_backup(editor_integration.get_current_file_path())
					editor_integration.writer.replace_function(f_name, processed_code)
				else:
					editor_integration.writer.insert_text_at_cursor(processed_code)
		)
	else:
		# Standard insert
		var current_path = editor_integration.get_current_file_path()
		if not current_path.is_empty():
			editor_integration.writer.create_backup(current_path)
		editor_integration.insert_text_at_cursor(processed_code)

func _filter_code_from_json(text: String) -> String:
	# If the AI accidentally returned a JSON object with a 'code' field
	var json := JSON.new()
	if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
		if json.data.has("code"):
			return json.data["code"]
		elif json.data.has("content"):
			return json.data["content"]
	return text

func _notification(what: int) -> void:
	if what == NOTIFICATION_PROCESS:
		if selection_manager:
			selection_manager.refresh_selection()

func _enter_tree() -> void:
	set_process(true)


func _on_chunk_received(chunk: String) -> void:
	var sender := "Assistant" if api_manager.current_mode == "chat" else "🤖 Agent"
	chat_ui.update_streaming_message(sender, chunk, AppTheme.COLOR_SUCCESS)

func _on_response_received(response: String) -> void:
	chat_ui.finish_streaming()
	chat_ui.set_streaming_state(false)
	chat_ui.clear_agent_status()
	# In agent mode the agent_finished path is taken; in chat mode this shows the response normally

func _on_error_received(err: String) -> void:
	chat_ui.add_message("Error", err, AppTheme.COLOR_ERROR)
	chat_ui.set_streaming_state(false)
	chat_ui.clear_agent_status()

# ─────────────────────────────────────────────────────────────────────────────
# Agent Events
# ─────────────────────────────────────────────────────────────────────────────

func _on_agent_status_changed(state: int, message: String) -> void:
	chat_ui.set_agent_status(message)

func _on_agent_thinking(message: String) -> void:
	chat_ui.add_agent_note(message)

func _on_agent_tool_executed(tool_name: String, args: Dictionary, result: Dictionary, message: String) -> void:
	# Cap the streaming AI response card before inserting the tool result card
	chat_ui.finish_streaming()
	if not message.is_empty():
		chat_ui.add_tool_card(tool_name, message, result.has("error"))

func _on_permission_needed(tool_name: String, args: Dictionary, description: String, callback: Callable) -> void:
	# Show confirmation in chat
	chat_ui.show_confirmation(description, callback)

# ─────────────────────────────────────────────────────────────────────────────
# Settings
# ─────────────────────────────────────────────────────────────────────────────

func _toggle_settings() -> void:
	settings_panel.visible = !settings_panel.visible

func _on_provider_changed(provider: String) -> void:
	api_manager.set_provider(provider)
	chat_ui.set_model_label(api_manager.current_model)
	_save_settings()

func _on_model_changed(model: String) -> void:
	api_manager.set_model(model)
	_save_settings()

func _on_api_key_changed(key: String) -> void:
	api_manager.set_api_key(key)
	_save_settings()

func _on_context_changed(context: String) -> void:
	api_manager.global_context = context
	_save_settings()

func _on_clear_requested() -> void:
	api_manager.clear_history()
	_refresh_session_ui()

func _on_new_session_requested() -> void:
	api_manager.new_session()
	_refresh_session_ui()

func _on_session_switched(session_id: String) -> void:
	api_manager.switch_session(session_id)
	_refresh_session_ui()

func _on_session_renamed(new_name: String) -> void:
	api_manager.rename_session(new_name)
	_refresh_session_ui()
	_save_settings() # Save updated ID to config

func _on_session_deleted(session_id: String) -> void:
	chat_ui.show_confirmation(
		"Are you sure you want to PERMANENTLY delete this session history?",
		func(confirmed):
			if confirmed:
				api_manager.delete_session(session_id)
				_refresh_session_ui()
				_save_settings()
	)

func _refresh_session_ui():
	# Clear UI
	chat_ui.clear_chat_display()
	
	# Reload messages
	for msg in api_manager.chat_history:
		var sender = "User" if msg.role == "user" else "Assistant"
		var color = AppTheme.COLOR_ACCENT_SOFT if msg.role == "user" else Color(0.9, 0.9, 0.9)
		chat_ui.add_message(sender, msg.content, color)
	
	# Update session list dropdown in settings
	settings_ui.set_session_list(api_manager.get_session_list(), api_manager.current_session_id)
	
	# Ensure model/mode labels are correct for the loaded session
	chat_ui.set_model_label(api_manager.current_model)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("ai_assistant", "api_key", api_manager.api_key)
	config.set_value("ai_assistant", "provider", api_manager.api_provider)
	config.set_value("ai_assistant", "model", api_manager.current_model)
	config.set_value("ai_assistant", "global_context", api_manager.global_context)
	config.set_value("ai_assistant", "current_session_id", api_manager.current_session_id)
	config.save("user://ai_assistant_settings.cfg")

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://ai_assistant_settings.cfg") == OK:
		var key: String = config.get_value("ai_assistant", "api_key", "")
		var prov: String = config.get_value("ai_assistant", "provider", "gemini")
		var model: String = config.get_value("ai_assistant", "model", "")
		var context: String = config.get_value("ai_assistant", "global_context", "")
		var session_id: String = config.get_value("ai_assistant", "current_session_id", "default")

		api_manager.set_api_key(key)
		api_manager.set_provider(prov)
		if not model.is_empty(): api_manager.set_model(model)
		api_manager.global_context = context
		api_manager.current_session_id = session_id
		api_manager.load_history() # Reload correct session

		settings_ui.set_api_key(key)
		settings_ui.set_model(api_manager.current_model)
		settings_ui.set_global_context(context)
		chat_ui.set_model_label(api_manager.current_model)


		var providers: Array = api_manager.get_provider_list()
		var p_idx: int = providers.find(prov)
		if p_idx >= 0: settings_ui.provider_option.selected = p_idx
