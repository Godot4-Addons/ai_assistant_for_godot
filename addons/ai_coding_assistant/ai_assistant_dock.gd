@tool
extends Control

# Components
const ChatSection = preload("res://addons/ai_coding_assistant/ui/chat_section.gd")
const CodeSection = preload("res://addons/ai_coding_assistant/ui/code_section.gd")
const SettingsSection = preload("res://addons/ai_coding_assistant/ui/settings_section.gd")
const QuickActions = preload("res://addons/ai_coding_assistant/ui/quick_actions.gd")

var api_manager: AIApiManager
var editor_integration
var plugin_editor_interface: EditorInterface

# UI Components
var chat_ui: AIChatSection
var code_ui: AICodeSection
var settings_ui: AISettingsSection
var quick_actions_ui: AIQuickActions

func _init():
	name = "AI Assistant"

func set_editor_interface(editor_interface: EditorInterface):
	plugin_editor_interface = editor_interface

func _ready():
	custom_minimum_size = Vector2(250, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Initialize Manager
	api_manager = AIApiManager.new()
	add_child(api_manager)
	api_manager.response_received.connect(_on_response_received)
	api_manager.error_occurred.connect(_on_error_received)

	if plugin_editor_interface:
		editor_integration = preload("res://addons/ai_coding_assistant/editor_integration.gd").new(plugin_editor_interface)

	_setup_ui()
	_load_settings()

func _setup_ui():
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# Settings
	settings_ui = SettingsSection.new()
	settings_ui.provider_changed.connect(_on_provider_changed)
	settings_ui.model_changed.connect(api_manager.set_model_index)
	settings_ui.api_key_changed.connect(api_manager.set_api_key)
	main_vbox.add_child(settings_ui)
	
	settings_ui.setup_providers(api_manager.get_provider_list())

	var splitter = VSplitContainer.new()
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(splitter)

	# Chat
	chat_ui = ChatSection.new()
	chat_ui.message_sent.connect(_on_chat_sent)
	splitter.add_child(chat_ui)

	# Code
	code_ui = CodeSection.new()
	code_ui.apply_code.connect(_on_apply_code)
	code_ui.explain_code.connect(api_manager.explain_code)
	code_ui.improve_code.connect(api_manager.suggest_improvements)
	splitter.add_child(code_ui)

	# Quick Actions
	quick_actions_ui = QuickActions.new()
	quick_actions_ui.action_triggered.connect(_on_action_triggered)
	main_vbox.add_child(quick_actions_ui)

func _on_chat_sent(msg: String):
	chat_ui.add_message("You", msg, Color.CYAN)
	api_manager.send_chat_request(msg)

func _on_response_received(response: String):
	chat_ui.add_message("AI", response, Color.GREEN)
	# Extract code if present
	var code = _extract_code(response)
	if not code.is_empty():
		code_ui.set_code(code)

func _on_error_received(err: String):
	chat_ui.add_message("Error", err, Color.RED)

func _on_provider_changed(provider: String):
	api_manager.set_provider(provider)
	settings_ui.update_models(api_manager.get_available_models())

func _on_apply_code(code: String):
	if editor_integration:
		editor_integration.insert_code_at_cursor(code)

func _on_action_triggered(type: String):
	match type:
		"generate_ui":
			api_manager.generate_code("Create a responsive UI system with a main menu and settings panel.")
		"generate_save":
			api_manager.generate_code("Create a robust persistent save system using JSON.")
		"generate_audio":
			api_manager.generate_code("Create a global audio manager for music and SFX.")
		"generate_player":
			api_manager.generate_code("Create a 2D/3D player controller with movement and interaction logic.")
		"generate_enemy":
			api_manager.generate_code("Create a basic Finite State Machine for an enemy AI.")
		"generate_tests":
			api_manager.generate_code("Generate unit tests for the current script.")

func _extract_code(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("```(?:gdscript)?\n([\\s\\S]*?)\n```")
	var result = regex.search(text)
	if result:
		return result.get_string(1)
	return ""

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
		if not model.is_empty():
			api_manager.set_model(model)
		
		settings_ui.set_api_key(key)
		settings_ui.set_model(api_manager.current_model)
		
		# Update UI provider selection
		var providers = api_manager.get_provider_list()
		var p_idx = providers.find(prov)
		if p_idx >= 0:
			settings_ui.provider_option.selected = p_idx
