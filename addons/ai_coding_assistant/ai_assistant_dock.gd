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
	api_manager.agent_context_status.connect(_on_context_status)
	api_manager.agent_step_started.connect(_on_agent_step_started)
	api_manager.agent_finished.connect(func(_r): chat_ui.clear_agent_progress())
	api_manager.agent_health_check.connect(_on_health_check_result)

	_setup_ui()
	_load_settings()
	chat_ui.set_model_label(api_manager.current_model)

func _setup_ui() -> void:
	var bg_panel := PanelContainer.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = AppTheme.COLOR_BG_DARK
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	bg_panel.add_child(main_vbox)

	# Header
	var header := PanelContainer.new()
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = AppTheme.COLOR_BG_DARK
	h_style.border_color = AppTheme.COLOR_BG_MUTED
	h_style.border_width_bottom = 1
	h_style.content_margin_left = 12
	h_style.content_margin_right = 12
	h_style.content_margin_top = 8
	h_style.content_margin_bottom = 8
	header.add_theme_stylebox_override("panel", h_style)
	main_vbox.add_child(header)

	var header_hbox := HBoxContainer.new()
	header.add_child(header_hbox)

	var title := Label.new()
	title.text = "Chat"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", AppTheme.COLOR_TEXT_BOLD)
	header_hbox.add_child(title)

	var health_badge := Label.new()
	health_badge.name = "HealthBadge"
	health_badge.text = ""
	health_badge.tooltip_text = "Project health"
	health_badge.add_theme_font_size_override("font_size", 11)
	health_badge.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	header_hbox.add_child(health_badge)

	var token_label := Label.new()
	token_label.name = "TokenLabel"
	token_label.text = ""
	token_label.tooltip_text = "Context usage"
	token_label.add_theme_font_size_override("font_size", 10)
	token_label.add_theme_color_override("font_color", AppTheme.COLOR_TEXT_DIM)
	header_hbox.add_child(token_label)

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
	settings_ui.base_url_changed.connect(_on_base_url_changed)
	settings_ui.api_key_changed.connect(_on_api_key_changed)
	settings_ui.context_changed.connect(_on_context_changed)
	settings_ui.new_session_requested.connect(_on_new_session_requested)
	settings_ui.session_switched.connect(_on_session_switched)
	settings_ui.session_renamed.connect(_on_session_renamed)
	settings_ui.session_deleted.connect(_on_session_deleted)
	settings_ui.auto_commit_toggled.connect(func(enabled): api_manager.set_auto_commit(enabled))
	settings_ui.memory_browse_requested.connect(_show_memory_browser)
	settings_ui.skill_use_requested.connect(_on_skill_use_requested)
	settings_ui.skill_gallery_requested.connect(_show_skill_gallery)
	settings_ui.memory_refresh_requested.connect(_refresh_memory_browser)
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
	var sender: String
	match api_manager.current_mode:
		"chat", "venice":
			sender = "Assistant"
		"assistant":
			sender = "🧠 Assistant"
		"code":
			sender = "⚙️ Agent"
		_:
			sender = "🤖 Agent"
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

func _on_context_status(tier: int, pct: float, tier_label: String) -> void:
	var token_label: Label = find_child("TokenLabel", true, false)
	if token_label:
		var pct_str: String = "%.0f" % pct
		var color := Color(0.5, 0.9, 0.5) if pct < 70 else (Color(0.9, 0.9, 0.3) if pct < 85 else Color(0.9, 0.3, 0.3))
		token_label.text = "T: %s%%" % pct_str
		token_label.add_theme_color_override("font_color", color)
		token_label.tooltip_text = "Context: %s tier" % tier_label

var _memory_browser_panel: PanelContainer = null
var _memory_browser_label: RichTextLabel = null
var _skill_browser_panel: PanelContainer = null
var _skill_browser_list: VBoxContainer = null
var _skill_browser_scroll: ScrollContainer = null


func _show_memory_browser() -> void:
	if not _memory_browser_panel:
		_memory_browser_panel = PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.12)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		_memory_browser_panel.add_theme_stylebox_override("panel", style)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		_memory_browser_panel.add_child(vbox)
		var header := HBoxContainer.new()
		var title := Label.new()
		title.text = "🧠 Stored Knowledge"
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		header.add_child(title)
		header.add_spacer(false)
		var close_btn := Button.new()
		close_btn.text = "✕"
		close_btn.flat = true
		close_btn.pressed.connect(func():
			if _memory_browser_panel:
				_memory_browser_panel.visible = false
		)
		header.add_child(close_btn)
		vbox.add_child(header)
		_memory_browser_label = RichTextLabel.new()
		_memory_browser_label.fit_content = true
		_memory_browser_label.bbcode_enabled = true
		_memory_browser_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_memory_browser_label.custom_minimum_size = Vector2(0, 60)
		vbox.add_child(_memory_browser_label)
		settings_panel.add_child(_memory_browser_panel)

	_refresh_memory_browser()
	_memory_browser_panel.visible = true

func _refresh_memory_browser() -> void:
	if not _memory_browser_label:
		return
	if not api_manager.agent_loop or not is_instance_valid(api_manager.agent_loop):
		_memory_browser_label.text = "[i]Agent not initialized.[/i]"
		return

	var memory = api_manager.agent_loop._memory
	if not memory:
		_memory_browser_label.text = "[i]Memory system not available.[/i]"
		return

	var keys := memory.list_knowledge()
	if keys.is_empty():
		_memory_browser_label.text = "[i]No stored knowledge yet. The agent will auto-populate from the blueprint.[/i]"
		return

	var lines: Array[String] = []
	for key in keys:
		var val: String = memory.recall(key)
		var short_val := val.substr(0, 80)
		if val.length() > 80:
			short_val += "..."
		lines.append("[b]%s:[/b] %s" % [key, short_val])
	_memory_browser_label.text = "\n".join(lines)

func _show_skill_gallery() -> void:
	if not _skill_browser_panel:
		_skill_browser_panel = PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.12)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		_skill_browser_panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		_skill_browser_panel.add_child(vbox)

		var header := HBoxContainer.new()
		var title := Label.new()
		title.text = "📦 Skills"
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		header.add_child(title)
		header.add_spacer(false)
		var close_btn := Button.new()
		close_btn.text = "✕"
		close_btn.flat = true
		close_btn.pressed.connect(func():
			if _skill_browser_panel:
				_skill_browser_panel.visible = false
		)
		header.add_child(close_btn)
		vbox.add_child(header)

		_skill_browser_scroll = ScrollContainer.new()
		_skill_browser_scroll.custom_minimum_size = Vector2(0, 100)
		vbox.add_child(_skill_browser_scroll)

		_skill_browser_list = VBoxContainer.new()
		_skill_browser_list.add_theme_constant_override("separation", 4)
		_skill_browser_scroll.add_child(_skill_browser_list)

		settings_panel.add_child(_skill_browser_panel)

	_refresh_skill_gallery()
	_skill_browser_panel.visible = true

func _refresh_skill_gallery() -> void:
	if not _skill_browser_list:
		return
	for child in _skill_browser_list.get_children():
		child.queue_free()

	if not api_manager.agent_loop or not is_instance_valid(api_manager.agent_loop):
		return

	var sm = api_manager.agent_loop._skill_manager
	if not sm:
		return

	var skill_names := sm.get_skill_names()
	skill_names.sort()

	var col_idx := 0
	var row_hbox: HBoxContainer = null

	for sname in skill_names:
		var skill = sm._skills.get(sname)
		if not skill:
			continue

		if col_idx == 0:
			row_hbox = HBoxContainer.new()
			row_hbox.add_theme_constant_override("separation", 4)
			_skill_browser_list.add_child(row_hbox)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(120, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cstyle := StyleBoxFlat.new()
		cstyle.bg_color = Color(0.12, 0.14, 0.18)
		cstyle.corner_radius_top_left = 4
		cstyle.corner_radius_top_right = 4
		cstyle.corner_radius_bottom_left = 4
		cstyle.corner_radius_bottom_right = 4
		cstyle.content_margin_left = 6
		cstyle.content_margin_right = 6
		cstyle.content_margin_top = 4
		cstyle.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", cstyle)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 2)
		card.add_child(card_vbox)

		var name_label := Label.new()
		name_label.text = sname
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = skill.description.substr(0, 50)
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(desc_label)

		var use_btn := Button.new()
		use_btn.text = "Use"
		use_btn.flat = true
		use_btn.add_theme_font_size_override("font_size", 9)
		use_btn.pressed.connect(func(name = sname):
			_on_skill_use_requested(name)
			if _skill_browser_panel:
				_skill_browser_panel.visible = false
		)
		card_vbox.add_child(use_btn)

		row_hbox.add_child(card)
		col_idx += 1
		if col_idx >= 2:
			col_idx = 0

func _on_skill_use_requested(skill_name: String) -> void:
	chat_ui.append_to_input("<use_skill name=\"%s\" params='{}' />" % skill_name)

func _on_agent_step_started(step_num: int, description: String) -> void:
	chat_ui.set_agent_progress(step_num, api_manager.agent_loop.max_iterations if api_manager.agent_loop else 25, description)

func _on_health_check_result(result: Dictionary) -> void:
	var badge: Label = find_child("HealthBadge", true, false)
	if not badge:
		return
	var issues: Array = result.get("issues", [])
	var warnings: Array = result.get("warnings", [])
	if issues.is_empty() and warnings.is_empty():
		badge.text = "✅"
		badge.tooltip_text = "Project healthy"
		badge.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	else:
		badge.text = "⚠️"
		var tooltip: String = ""
		if not issues.is_empty():
			tooltip += "%d issues" % issues.size()
		if not warnings.is_empty():
			if not tooltip.is_empty(): tooltip += ", "
			tooltip += "%d warnings" % warnings.size()
		badge.tooltip_text = tooltip
		badge.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))

func _on_permission_needed(tool_name: String, args: Dictionary, description: String, callback: Callable) -> void:
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

func _on_base_url_changed(url: String) -> void:
	api_manager.api_base_url = url
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
	config.set_value("ai_assistant", "api_base_url", api_manager.api_base_url)
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
		settings_ui.set_base_url(api_manager.api_base_url)
		settings_ui.set_global_context(context)
		chat_ui.set_model_label(api_manager.current_model)


		var providers: Array = api_manager.get_provider_list()
		settings_ui.set_provider(prov)
