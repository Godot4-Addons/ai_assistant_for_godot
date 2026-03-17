@tool
extends Node
class_name AIApiManager

## AI API Manager — handles provider routing and mode delegation.
## In chat mode: direct streaming response.
## In code/auto modes: delegates to AIAgentLoop.

# Provider preloads
const GeminiProvider = preload("res://addons/ai_coding_assistant/ai_provider/gemini.gd")
const GPTProvider = preload("res://addons/ai_coding_assistant/ai_provider/gpt.gd")
const AnthropicProvider = preload("res://addons/ai_coding_assistant/ai_provider/anthropic.gd")
const GroqProvider = preload("res://addons/ai_coding_assistant/ai_provider/groq.gd")
const OpenRouterProvider = preload("res://addons/ai_coding_assistant/ai_provider/openrouter.gd")
const AgentLoopClass = preload("res://addons/ai_coding_assistant/agent/agent_loop.gd")

# API state
var api_key: String = ""
var api_provider: String = "gemini"
var current_model: String = ""
var provider_handlers: Dictionary = {}
var base_urls: Dictionary = {}
var global_context: String = ""
var current_mode: String = "chat"

var available_modes: Dictionary = {
	"chat": {"label": "Chat", "icon": "💬", "type": "chat"},
	"code": {"label": "Code", "icon": "⚙️", "type": "agent"},
	"auto": {"label": "Auto", "icon": "🤖", "type": "agent"}
}

# History (chat mode only; agent loop has its own memory)
var chat_history: Array = []

# Agent loop (created on demand for code/auto modes)
var agent_loop: AIAgentLoop = null

# Internal streaming state
var _sse_client # SSEClient
var _current_full_response: String = ""
var _last_user_message: String = ""
var _is_cancelling: bool = false # Guard against re-entrant cancel calls
var editor_integration # Reference for file access (@ mentions)

const SESSIONS_DIR = "user://ai_sessions/"
var current_session_id: String = "default"


# ─────────────────────────────────────────────────────────────────────────────
# Signals
# ─────────────────────────────────────────────────────────────────────────────

signal chunk_received(chunk: String)
signal response_received(response: String)
signal error_occurred(error: String)

## Agent-specific signals (forwarded from agent_loop)
signal agent_status_changed(state: int, message: String)
signal agent_tool_executed(tool_name: String, args: Dictionary, result: Dictionary, message: String)
signal agent_thinking(message: String)
signal agent_finished(response: String)
signal agent_permission_needed(tool_name: String, args: Dictionary, description: String, callback: Callable)

# ─────────────────────────────────────────────────────────────────────────────
# Init
# ─────────────────────────────────────────────────────────────────────────────

func _init() -> void:
	_init_providers()
	api_provider = "gemini"
	current_model = GeminiProvider.get_default_model()
	
	if not DirAccess.dir_exists_absolute(SESSIONS_DIR):
		DirAccess.make_dir_recursive_absolute(SESSIONS_DIR)
	
	load_history()

func _init_providers() -> void:
	var providers = [GeminiProvider, GPTProvider, AnthropicProvider, GroqProvider, OpenRouterProvider]
	for provider in providers:
		var pname: String = provider.get_name()
		provider_handlers[pname] = provider
		base_urls[pname] = provider.get_base_url()

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

func set_api_key(key: String) -> void:
	api_key = key
	if agent_loop:
		# Re-create agent loop with new key — it uses api_manager methods so no direct key storage
		pass

func set_provider(provider: String) -> void:
	if provider in provider_handlers:
		api_provider = provider
		current_model = provider_handlers[provider].get_default_model()
	else:
		push_error("Unsupported provider: " + provider)

func set_model(model_name: String) -> void:
	current_model = model_name

func get_provider_list() -> Array:
	return provider_handlers.keys()

func add_mode(id: String, label: String, icon: String, type: String) -> void:
	available_modes[id] = {"label": label, "icon": icon, "type": type}

func remove_mode(id: String) -> void:
	if id != "chat": # Keep basic chat
		available_modes.erase(id)

# ─────────────────────────────────────────────────────────────────────────────
# Agent Loop Setup
# ─────────────────────────────────────────────────────────────────────────────

## Call this once from the dock after editor_integration is ready
func setup_agent(p_editor_integration, editor_interface = null) -> void:
	editor_integration = p_editor_integration
	if agent_loop:
		agent_loop.queue_free()
	agent_loop = AgentLoopClass.new(self , editor_integration, editor_interface)
	add_child(agent_loop)

	agent_loop.status_changed.connect(func(s, m): agent_status_changed.emit(s, m))
	agent_loop.tool_executed.connect(func(tn, a, r, m): agent_tool_executed.emit(tn, a, r, m))
	agent_loop.agent_thinking.connect(func(m): agent_thinking.emit(m))
	agent_loop.agent_finished.connect(_on_agent_finished)
	agent_loop.agent_error.connect(func(err): error_occurred.emit(err))
	agent_loop.permission_needed.connect(func(tn, a, d, cb): agent_permission_needed.emit(tn, a, d, cb))

# ─────────────────────────────────────────────────────────────────────────────
# Public Chat API
# ─────────────────────────────────────────────────────────────────────────────

func send_chat_request(message: String, context: String = "") -> void:
	if api_key.is_empty():
		error_occurred.emit("API key not set for " + api_provider)
		return

	var mode_data = available_modes.get(current_mode, {"type": "chat"})
	
	# Process @file mentions
	var processed_message = _process_mentions(message)
	
	# Route to agent if mode type is agent
	if mode_data.type == "agent":
		if not agent_loop:
			error_occurred.emit("Agent loop not initialized. Please restart the dock.")
			return
		agent_loop.run(processed_message)
		return

	# Chat mode — direct streaming
	_send_raw_request(processed_message, context, chat_history)

func _process_mentions(message: String) -> String:
	var pattern = "@(res://[a-zA-Z0-9_\\/.]+|[a-zA-Z0-9_\\/.]+\\.[a-zA-Z]+)"
	var regex = RegEx.new()
	regex.compile(pattern)
	
	var matches = regex.search_all(message)
	if matches.is_empty(): return message
	
	var file_contents := ""
	var processed_paths := []
	
	for m in matches:
		var path = m.get_string(1)
		if path in processed_paths: continue
		processed_paths.append(path)
		
		# Try to read the file
		if editor_integration and editor_integration.reader:
			var content = editor_integration.reader.read_file(path)
			if not content.is_empty() and not content.begins_with("[Binary"):
				var lang = "gdscript" if path.ends_with(".gd") else ("json" if path.ends_with(".json") else "text")
				file_contents += "\n\nFile: `%s`\n```%s\n%s\n```\n" % [path, lang, content]
				
	if not file_contents.is_empty():
		return message + "\n\nContext from referenced files:" + file_contents
	return message

## Send a raw request on behalf of the agent loop (called by agent_loop internally)
func send_agent_request(message: String, system_context: String, history: Array) -> void:
	_send_raw_request(message, system_context, history, true)

func cancel_request() -> void:
	if _is_cancelling:
		return
	_is_cancelling = true
	# Cancel the SSE directly — do NOT call agent_loop.stop() here.
	# The dock's _on_stop_requested calls agent_loop.stop() separately.
	if _sse_client:
		_sse_client.cancel()
		_sse_client.queue_free()
		_sse_client = null
	_current_full_response = ""
	_last_user_message = ""
	_is_cancelling = false


func generate_code(prompt: String, language: String = "gdscript") -> void:
	var ctx := "Generate clean %s code. Only return code." % language
	send_chat_request(prompt, ctx)

# ─────────────────────────────────────────────────────────────────────────────
# Internal Request Handling
# ─────────────────────────────────────────────────────────────────────────────

func _send_raw_request(message: String, context: String, history: Array, is_agent: bool = false) -> void:
	_current_full_response = ""
	_last_user_message = message

	var persona_manager = preload("res://addons/ai_coding_assistant/persona/persona_manager.gd")
	var blueprint := ""
	if current_mode in ["code", "auto"] and not is_agent:
		blueprint = AIProjectBlueprint.get_blueprint()

	var final_context := context
	if not is_agent:
		final_context = persona_manager.get_full_context(current_mode, context if not context.is_empty() else global_context, blueprint)

	var model_to_use := current_model
	if model_to_use.is_empty():
		model_to_use = provider_handlers[api_provider].get_default_model()

	var request_data: Dictionary = provider_handlers[api_provider].build_request(
		base_urls[api_provider], api_key, model_to_use, message, history, final_context
	)

	# Inject streaming flag
	if request_data.has("body"):
		var json := JSON.new()
		if json.parse(request_data["body"]) == OK and typeof(json.data) == TYPE_DICTIONARY:
			json.data["stream"] = true
			request_data["body"] = JSON.stringify(json.data)

	var SSEClientClass = preload("res://addons/ai_coding_assistant/utils/sse_client.gd")
	_sse_client = SSEClientClass.new()
	add_child(_sse_client)
	_sse_client.chunk_received.connect(_on_chunk_received)
	_sse_client.request_completed.connect(_on_request_completed)
	_sse_client.error_occurred.connect(_on_error_received)

	_sse_client.request(
		request_data.get("url", ""),
		request_data.get("headers", []),
		request_data.get("method", HTTPClient.METHOD_POST),
		request_data.get("body", "")
	)

func _on_chunk_received(chunk: String) -> void:
	if chunk == "[DONE]": return
	var json := JSON.new()
	if json.parse(chunk) == OK and typeof(json.data) == TYPE_DICTIONARY:
		var txt: String = provider_handlers[api_provider].parse_stream_chunk(json.data)
		if not txt.is_empty():
			_current_full_response += txt
			chunk_received.emit(txt)
			# Forward to agent loop if it's running
			if agent_loop and agent_loop.state != AIAgentLoop.State.IDLE:
				agent_loop.on_chunk_received(txt)

func _on_error_received(error_message: String) -> void:
	if _sse_client:
		_sse_client.queue_free()
		_sse_client = null
	# Don't forward errors to an already-idle agent
	if agent_loop and is_instance_valid(agent_loop) and agent_loop.state != AIAgentLoop.State.IDLE:
		agent_loop.on_error_received(error_message)
	else:
		error_occurred.emit(error_message)

func _on_request_completed() -> void:
	var full_res := _current_full_response
	_current_full_response = ""

	if _sse_client:
		if is_instance_valid(_sse_client):
			_sse_client.queue_free()
		_sse_client = null

	# If being cancelled or agent already went idle, skip agent callback
	if _is_cancelling:
		return

	# If agent loop is active, hand response to it
	if agent_loop and is_instance_valid(agent_loop) and agent_loop.state != AIAgentLoop.State.IDLE:
		agent_loop.on_response_received(full_res)
		return

	# Chat mode — store history and emit
	if not _last_user_message.is_empty() and not full_res.is_empty():
		chat_history.append({"role": "user", "content": _last_user_message})
		chat_history.append({"role": "assistant", "content": full_res})
		
		# Auto-naming for new sessions
		if chat_history.size() == 2 and current_session_id.begins_with("chat_"):
			var auto_name = _last_user_message.strip_edges().left(30)
			if auto_name.is_empty(): auto_name = "Untitled Chat"
			rename_session(auto_name)
		else:
			save_history()
			
	_last_user_message = ""

	response_received.emit(full_res)

func _on_agent_finished(response: String) -> void:
	response_received.emit(response)
	agent_finished.emit(response)

# ─────────────────────────────────────────────────────────────────────────────
# Persistence & Sessions
# ─────────────────────────────────────────────────────────────────────────────

func save_history():
	var path = SESSIONS_DIR.path_join(current_session_id + ".json")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data = {
			"chat_history": chat_history,
			"current_mode": current_mode,
			"current_model": current_model,
			"api_provider": api_provider
		}
		file.store_string(JSON.stringify(data))
		file.close()

func load_history(session_id: String = ""):
	if not session_id.is_empty():
		current_session_id = session_id
		
	var path = SESSIONS_DIR.path_join(current_session_id + ".json")
	if not FileAccess.file_exists(path):
		chat_history = []
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if data.has("chat_history"): chat_history = data.chat_history
			if data.has("current_mode"): current_mode = data.current_mode
			if data.has("current_model"): current_model = data.current_model
			if data.has("api_provider"): api_provider = data.api_provider
		file.close()

func new_session():
	# Save current first
	save_history()
	# Generate new ID based on timestamp
	current_session_id = "chat_" + str(Time.get_unix_time_from_system())
	chat_history = []
	save_history()

func get_session_list() -> Array:
	var list: Array = []
	var dir = DirAccess.open(SESSIONS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				list.append(file_name.get_basename())
			file_name = dir.get_next()
	return list

func switch_session(session_id: String):
	save_history()
	load_history(session_id)

func delete_session(session_id: String):
	var path = SESSIONS_DIR.path_join(session_id + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
	if session_id == current_session_id:
		var remaining = get_session_list()
		if remaining.size() > 0:
			switch_session(remaining[0])
		else:
			new_session()

func rename_session(new_name: String):
	if new_name.is_empty() or new_name == current_session_id:
		return
		
	# Sanitize name
	var safe_name = ""
	var allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- "
	for i in range(new_name.length()):
		if new_name[i] in allowed:
			safe_name += new_name[i]
	safe_name = safe_name.strip_edges().replace(" ", "_")
	if safe_name.is_empty(): safe_name = "unnamed_session"
	
	var old_path = SESSIONS_DIR.path_join(current_session_id + ".json")
	var new_path = SESSIONS_DIR.path_join(safe_name + ".json")
	
	# Handle collisions
	if FileAccess.file_exists(new_path) and safe_name != current_session_id:
		safe_name += "_" + str(Time.get_unix_time_from_system()).right(4)
		new_path = SESSIONS_DIR.path_join(safe_name + ".json")

	if FileAccess.file_exists(old_path):
		DirAccess.rename_absolute(old_path, new_path)
		
	current_session_id = safe_name
	save_history() # Ensure it's saved with correct ID

func clear_history() -> void:
	chat_history.clear()
	var path = SESSIONS_DIR.path_join(current_session_id + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
