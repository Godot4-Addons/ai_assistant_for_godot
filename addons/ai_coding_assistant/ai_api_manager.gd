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

signal response_received(response: String)
signal error_occurred(error: String)

var http_request: HTTPRequest

func _init():
	_init_providers()
	api_provider = "gemini"
	current_model = GeminiProvider.get_default_model()

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

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
		context
	)

	print(api_provider.capitalize(), " request to: ", request_data.get("url", ""))
	http_request.request(
		request_data.get("url", ""),
		request_data.get("headers", []),
		request_data.get("method", HTTPClient.METHOD_POST),
		request_data.get("body", "")
	)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		var error_msg = "HTTP Error: " + str(response_code)
		if response_code == 401:
			error_msg += " - Unauthorized (API key)"
		elif response_code == 404:
			error_msg += " - Endpoint or Model not found"
		error_occurred.emit(error_msg)
		return

	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		error_occurred.emit("Failed to parse JSON response")
		return

	var extracted_text = provider_handlers[api_provider].parse_response(json.data)
	if extracted_text.is_empty():
		error_occurred.emit("No valid response text received")
	else:
		response_received.emit(extracted_text)

func generate_code(prompt: String, language: String = "gdscript"):
	var context = "Generate clean " + language + " code. Only return code."
	send_chat_request(prompt, context)

func explain_code(code: String):
	var context = "Explain this code:"
	send_chat_request(code, context)

func suggest_improvements(code: String):
	var context = "Suggest improvements for this code:"
	send_chat_request(code, context)
