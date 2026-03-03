@tool
extends Node
class_name AIApiManager

# Provider preloads
const GeminiProvider = preload("res://addons/ai_coding_assistant/ai_provider/gemini.gd")
const GPTProvider = preload("res://addons/ai_coding_assistant/ai_provider/gpt.gd")
const AnthropicProvider = preload("res://addons/ai_coding_assistant/ai_provider/anthropic.gd")
const GroqProvider = preload("res://addons/ai_coding_assistant/ai_provider/groq.gd")
const OpenRouterProvider = preload("res://addons/ai_coding_assistant/ai_provider/openrouter.gd")

# API configuration
var api_key: String = ""
var api_provider: String = "gemini"
var current_model: String = ""
var provider_handlers: Dictionary = {}
var base_urls: Dictionary = {}

signal chunk_received(chunk: String)
signal response_received(response: String)
signal error_occurred(error: String)

var sse_client: SSEClient
var _current_full_response: String = ""
var chat_history: Array = []
var global_context: String = ""
var _last_user_message: String = ""

func _init():
	_init_providers()
	api_provider = "gemini"
	current_model = GeminiProvider.get_default_model()

func _ready():
	pass

func _init_providers():
	var providers = [
		GeminiProvider,
		GPTProvider,
		AnthropicProvider,
		GroqProvider,
		OpenRouterProvider
	]
	
	for provider in providers:
		var pname = provider.get_name()
		provider_handlers[pname] = provider
		base_urls[pname] = provider.get_base_url()

func set_api_key(key: String):
	api_key = key

func set_provider(provider: String):
	if provider in provider_handlers:
		api_provider = provider
		current_model = provider_handlers[provider].get_default_model()
		print("Provider set to: ", provider)
	else:
		push_error("Unsupported API provider: " + provider)

func set_model(model_name: String):
	current_model = model_name
	print("Model set to: ", current_model)

func get_provider_list() -> Array:
	return provider_handlers.keys()

func send_chat_request(message: String, context: String = ""):
	if api_key.is_empty():
		error_occurred.emit("API key not set for " + api_provider)
		return

	_current_full_response = ""

	if not provider_handlers.has(api_provider):
		error_occurred.emit("Unsupported provider: " + api_provider)
		return

	var model_to_use = current_model
	if model_to_use.is_empty():
		model_to_use = provider_handlers[api_provider].get_default_model()

	var request_data: Dictionary = provider_handlers[api_provider].build_request(
		base_urls[api_provider],
		api_key,
		model_to_use,
		message,
		chat_history,
		global_context if context.is_empty() else context
	)

	_last_user_message = message

	# Inject streaming flag if applicable (OpenAI/Anthropic/OpenRouter style)
	if request_data.has("body"):
		var json = JSON.new()
		var parse_res = json.parse(request_data["body"])
		if parse_res == OK and typeof(json.data) == TYPE_DICTIONARY:
			# Not ideal if provider explicitly doesn't support it, but universally true for these
			json.data["stream"] = true
			request_data["body"] = JSON.stringify(json.data)

	print(api_provider.capitalize(), " request to: ", request_data.get("url", ""))
	
	sse_client = SSEClient.new()
	add_child(sse_client)
	sse_client.chunk_received.connect(_on_chunk_received)
	sse_client.request_completed.connect(_on_request_completed)
	sse_client.error_occurred.connect(_on_error_received)
	
	sse_client.request(
		request_data.get("url", ""),
		request_data.get("headers", []),
		request_data.get("method", HTTPClient.METHOD_POST),
		request_data.get("body", "")
	)

func cancel_request():
	if sse_client:
		sse_client.cancel()
		_on_request_completed()

func _on_chunk_received(chunk: String):
	# Basic parse of standard OpenAI-format streaming chunk
	if chunk == "[DONE]": return
	
	var json = JSON.new()
	var err = json.parse(chunk)
	if err == OK and typeof(json.data) == TYPE_DICTIONARY:
		var txt = provider_handlers[api_provider].parse_stream_chunk(json.data)
		if not txt.is_empty():
			_current_full_response += txt
			chunk_received.emit(txt)

func _on_error_received(error_message: String):
	if sse_client:
		sse_client.queue_free()
		sse_client = null
	error_occurred.emit(error_message)

func _on_request_completed():
	var full_res = _current_full_response
	_current_full_response = ""
	
	if not _last_user_message.is_empty() and not full_res.is_empty():
		chat_history.append({"role": "user", "content": _last_user_message})
		chat_history.append({"role": "assistant", "content": full_res})
		_last_user_message = ""
		
	if sse_client:
		sse_client.queue_free()
		sse_client = null
	response_received.emit(full_res) # Signal end of stream with full response

func clear_history():
	chat_history.clear()

func generate_code(prompt: String, language: String = "gdscript"):
	var context = "Generate clean " + language + " code. Only return code."
	send_chat_request(prompt, context)

func explain_code(code: String):
	var context = "Explain this code:"
	send_chat_request(code, context)

func suggest_improvements(code: String):
	var context = "Suggest improvements for this code:"
	send_chat_request(code, context)
