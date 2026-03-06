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
func setup_agent(editor_integration, editor_interface = null) -> void:
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
	
	# Route to agent if mode type is agent
	if mode_data.type == "agent":
		if not agent_loop:
			error_occurred.emit("Agent loop not initialized. Please restart the dock.")
			return
		agent_loop.run(message)
		return

	# Chat mode — direct streaming
	_send_raw_request(message, context, chat_history)

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

func clear_history() -> void:
	chat_history.clear()

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
	_last_user_message = ""

	response_received.emit(full_res)

func _on_agent_finished(response: String) -> void:
	response_received.emit(response)
	agent_finished.emit(response)
