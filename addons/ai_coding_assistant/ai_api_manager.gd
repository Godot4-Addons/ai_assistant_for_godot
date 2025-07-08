@tool
extends Node
class_name AIApiManager

# API Configuration
var api_key: String = ""
var api_provider: String = "gemini"  # gemini, huggingface, cohere, openai, anthropic, groq, ollama
var current_model_index: int = 0
var gemini_models: Array = []
var provider_models: Dictionary = {}
var base_urls = {
	"gemini": "https://generativelanguage.googleapis.com/v1beta/models/",
	"huggingface": "https://api-inference.huggingface.co/models/",
	"cohere": "https://api.cohere.ai/v1/",
	"openai": "https://api.openai.com/v1/",
	"anthropic": "https://api.anthropic.com/v1/",
	"groq": "https://api.groq.com/openai/v1/",
	"ollama": "http://localhost:11434/api/"
}

signal response_received(response: String)
signal error_occurred(error: String)

var http_request: HTTPRequest
var ollama_handler: AIOllama

func _init():
	# Always initialize arrays to ensure they're never null
	gemini_models = [
		"gemini-2.0-flash",
		"gemini-1.5-flash",
		"gemini-1.5-pro",
		"gemini-1.0-pro",
		"gemini-pro"
	]

	base_urls = {
		"gemini": "https://generativelanguage.googleapis.com/v1beta/models/",
		"huggingface": "https://api-inference.huggingface.co/models/",
		"cohere": "https://api.cohere.ai/v1/",
		"openai": "https://api.openai.com/v1/",
		"anthropic": "https://api.anthropic.com/v1/",
		"groq": "https://api.groq.com/openai/v1/",
		"ollama": "http://localhost:11434/api/"
	}

	# Initialize models for all providers
	_init_provider_models()

	current_model_index = 0
	api_provider = "gemini"
	api_key = ""

func _ready():
	"""Initialize HTTPRequest when node is ready"""
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	# Initialize dedicated Ollama handler
	ollama_handler = preload("res://addons/ai_coding_assistant/ai_ollama.gd").new()
	add_child(ollama_handler)
	ollama_handler.response_received.connect(_on_ollama_response)
	ollama_handler.error_occurred.connect(_on_ollama_error)
	ollama_handler.model_list_updated.connect(_on_ollama_models_updated)

	print("API Manager ready with models: ", gemini_models)

func _init_provider_models():
	"""Initialize model configurations for all providers"""
	provider_models = {
		"gemini": [
			"gemini-2.0-flash",
			"gemini-1.5-flash",
			"gemini-1.5-pro",
			"gemini-1.0-pro",
			"gemini-pro"
		],
		"huggingface": [
			"microsoft/DialoGPT-medium",
			"microsoft/CodeBERT-base",
			"codeparrot/codeparrot-small",
			"Salesforce/codegen-350M-mono",
			"bigcode/starcoder",
			"WizardLM/WizardCoder-15B-V1.0"
		],
		"cohere": [
			"command-r-plus",
			"command-r",
			"command",
			"command-light",
			"command-nightly"
		],
		"openai": [
			"gpt-4o",
			"gpt-4o-mini",
			"gpt-4-turbo",
			"gpt-4",
			"gpt-3.5-turbo"
		],
		"anthropic": [
			"claude-3-5-sonnet-20241022",
			"claude-3-5-haiku-20241022",
			"claude-3-opus-20240229",
			"claude-3-sonnet-20240229",
			"claude-3-haiku-20240307"
		],
		"groq": [
			"llama-3.1-70b-versatile",
			"llama-3.1-8b-instant",
			"mixtral-8x7b-32768",
			"gemma2-9b-it",
			"llama3-70b-8192"
		],
		"ollama": [
			"llama3.2",
			"llama3.2:1b",
			"llama3.2:3b",
			"qwen2.5-coder",
			"qwen2.5-coder:1.5b",
			"codellama:7b",
			"codellama:13b",
			"mistral:7b",
			"phi3:mini",
			"phi3:medium",
			"gemma2:2b",
			"gemma2:9b",
			"deepseek-coder:6.7b",
			"starcoder2:3b"
		]
	}

func set_api_key(key: String):
	api_key = key

func set_provider(provider: String):
	if provider in base_urls:
		api_provider = provider
		current_model_index = 0  # Reset model index when changing provider
		print("Provider set to: ", provider)
	else:
		push_error("Unsupported API provider: " + provider)

func get_available_models() -> Array:
	"""Get available models for current provider"""
	if api_provider in provider_models:
		return provider_models[api_provider]
	return []

func get_current_model() -> String:
	"""Get the currently selected model"""
	var models = get_available_models()
	if models.size() > 0 and current_model_index < models.size():
		return models[current_model_index]
	return ""

func set_model_index(index: int):
	"""Set the current model by index"""
	var models = get_available_models()
	if index >= 0 and index < models.size():
		current_model_index = index
		print("Model set to: ", get_current_model())

func get_provider_list() -> Array:
	"""Get list of available providers"""
	return base_urls.keys()

func send_chat_request(message: String, context: String = ""):
	# Ollama doesn't require an API key
	if api_key.is_empty() and api_provider != "ollama":
		error_occurred.emit("API key not set for " + api_provider)
		return

	match api_provider:
		"gemini":
			_send_gemini_request(message, context)
		"huggingface":
			_send_huggingface_request(message, context)
		"cohere":
			_send_cohere_request(message, context)
		"openai":
			_send_openai_request(message, context)
		"anthropic":
			_send_anthropic_request(message, context)
		"groq":
			_send_groq_request(message, context)
		"ollama":
			_send_ollama_request(message, context)
		_:
			error_occurred.emit("Unsupported provider: " + api_provider)

func _send_gemini_request(message: String, context: String):
	var headers = [
		"Content-Type: application/json"
	]

	var prompt = context + "\n\n" + message if not context.is_empty() else message

	var body = {
		"contents": [{
			"parts": [{
				"text": prompt
			}]
		}]
	}

	var json_body = JSON.stringify(body)

	# Safety checks
	print("Debug: gemini_models = ", gemini_models)
	print("Debug: gemini_models type = ", typeof(gemini_models))
	if gemini_models:
		print("Debug: gemini_models size = ", gemini_models.size())

	if not gemini_models or gemini_models.size() == 0:
		print("Error: gemini_models is null or empty!")
		error_occurred.emit("No Gemini models available")
		return

	if current_model_index >= gemini_models.size():
		current_model_index = 0

	var current_model = gemini_models[current_model_index]
	var full_url = base_urls["gemini"] + current_model + ":generateContent?key=" + api_key
	print("Trying model: ", current_model)
	print("Sending request to: ", full_url)
	print("Request body: ", json_body)
	http_request.request(full_url, headers, HTTPClient.METHOD_POST, json_body)

func _send_huggingface_request(message: String, context: String):
	var current_model = get_current_model()
	if current_model.is_empty():
		current_model = "microsoft/DialoGPT-medium"  # Fallback model

	var url = base_urls["huggingface"] + current_model

	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]

	var prompt = context + "\n\n" + message if not context.is_empty() else message

	# Different request format for different model types
	var body = {}
	if "DialoGPT" in current_model or "CodeBERT" in current_model:
		# Chat/conversation models
		body = {
			"inputs": {
				"past_user_inputs": [],
				"generated_responses": [],
				"text": prompt
			},
			"parameters": {
				"max_length": 512,
				"temperature": 0.7,
				"do_sample": true,
				"top_p": 0.9
			}
		}
	else:
		# Code generation models
		body = {
			"inputs": prompt,
			"parameters": {
				"max_new_tokens": 512,
				"temperature": 0.7,
				"do_sample": true,
				"top_p": 0.9,
				"return_full_text": false
			}
		}

	var json_body = JSON.stringify(body)
	print("Hugging Face request to: ", url)
	print("Using model: ", current_model)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func _send_cohere_request(message: String, context: String):
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]

	var prompt = context + "\n\n" + message if not context.is_empty() else message

	var body = {
		"model": "command",
		"prompt": prompt,
		"max_tokens": 2048,
		"temperature": 0.7
	}

	var json_body = JSON.stringify(body)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func _send_openai_request(message: String, context: String):
	var current_model = get_current_model()
	if current_model.is_empty():
		current_model = "gpt-3.5-turbo"

	var url = base_urls["openai"] + "chat/completions"
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]

	var messages = []
	if not context.is_empty():
		messages.append({"role": "system", "content": context})
	messages.append({"role": "user", "content": message})

	var body = {
		"model": current_model,
		"messages": messages,
		"max_tokens": 2048,
		"temperature": 0.7
	}

	var json_body = JSON.stringify(body)
	print("OpenAI request to: ", url)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func _send_anthropic_request(message: String, context: String):
	var current_model = get_current_model()
	if current_model.is_empty():
		current_model = "claude-3-haiku-20240307"

	var url = base_urls["anthropic"] + "messages"
	var headers = [
		"x-api-key: " + api_key,
		"Content-Type: application/json",
		"anthropic-version: 2023-06-01"
	]

	var messages = []
	if not context.is_empty():
		messages.append({"role": "user", "content": context + "\n\n" + message})
	else:
		messages.append({"role": "user", "content": message})

	var body = {
		"model": current_model,
		"max_tokens": 2048,
		"messages": messages
	}

	var json_body = JSON.stringify(body)
	print("Anthropic request to: ", url)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func _send_groq_request(message: String, context: String):
	var current_model = get_current_model()
	if current_model.is_empty():
		current_model = "llama-3.1-8b-instant"

	var url = base_urls["groq"] + "chat/completions"
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]

	var messages = []
	if not context.is_empty():
		messages.append({"role": "system", "content": context})
	messages.append({"role": "user", "content": message})

	var body = {
		"model": current_model,
		"messages": messages,
		"max_tokens": 2048,
		"temperature": 0.7
	}

	var json_body = JSON.stringify(body)
	print("Groq request to: ", url)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func _send_ollama_request(message: String, context: String):
	"""Send request using dedicated Ollama handler"""
	var current_model = get_current_model()
	if current_model.is_empty():
		current_model = "llama3.2"

	# Set model and context in Ollama handler
	ollama_handler.set_model(current_model)
	if not context.is_empty():
		ollama_handler.set_system_prompt(context)

	# Send message using dedicated handler
	ollama_handler.send_chat_message(message, not context.is_empty())

func _on_ollama_response(response: String):
	"""Handle response from dedicated Ollama handler"""
	print("Ollama response received: ", response.substr(0, 100) + "...")
	response_received.emit(response)

func _on_ollama_error(error: String):
	"""Handle error from dedicated Ollama handler"""
	print("Ollama error: ", error)
	error_occurred.emit(error)

func _on_ollama_models_updated(models: Array):
	"""Handle model list update from Ollama"""
	print("Ollama models updated: ", models.size(), " models available")
	# Update provider_models with actual available models
	var model_names = []
	for model in models:
		model_names.append(model.get("name", "unknown"))
	if model_names.size() > 0:
		provider_models["ollama"] = model_names

func get_ollama_handler() -> AIOllama:
	"""Get direct access to Ollama handler for advanced features"""
	return ollama_handler

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("Request completed - Result: ", result, " Response code: ", response_code)
	print("Response body: ", body.get_string_from_utf8())

	if response_code != 200:
		# If 404 and we're using Gemini, try the next model
		if response_code == 404 and api_provider == "gemini" and gemini_models and current_model_index < gemini_models.size() - 1:
			current_model_index += 1
			print("Model not found, trying next model: ", gemini_models[current_model_index])
			# Retry with the last message (we'll need to store it)
			error_occurred.emit("Model not available, trying " + gemini_models[current_model_index] + "...")
			return

		var error_msg = "HTTP Error: " + str(response_code)
		if response_code == 404:
			error_msg += " - API endpoint not found. All models tried."
		elif response_code == 401:
			error_msg += " - Unauthorized. Check your API key."
		elif response_code == 403:
			error_msg += " - Forbidden. API key may not have proper permissions."
		error_occurred.emit(error_msg)
		return

	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		error_occurred.emit("Failed to parse JSON response")
		return

	var response_data = json.data
	var extracted_text = ""

	match api_provider:
		"gemini":
			if "candidates" in response_data and response_data["candidates"].size() > 0:
				var candidate = response_data["candidates"][0]
				if "content" in candidate and "parts" in candidate["content"]:
					extracted_text = candidate["content"]["parts"][0]["text"]
		"huggingface":
			if response_data is Array and response_data.size() > 0:
				# Handle different HF response formats
				var first_response = response_data[0]
				if "generated_text" in first_response:
					extracted_text = first_response["generated_text"]
				elif "conversation" in first_response:
					extracted_text = first_response["conversation"]["generated_responses"][-1]
				elif typeof(first_response) == TYPE_STRING:
					extracted_text = first_response
			elif "generated_text" in response_data:
				extracted_text = response_data["generated_text"]
		"cohere":
			if "generations" in response_data and response_data["generations"].size() > 0:
				extracted_text = response_data["generations"][0]["text"]
		"openai":
			if "choices" in response_data and response_data["choices"].size() > 0:
				var choice = response_data["choices"][0]
				if "message" in choice and "content" in choice["message"]:
					extracted_text = choice["message"]["content"]
		"anthropic":
			if "content" in response_data and response_data["content"].size() > 0:
				extracted_text = response_data["content"][0]["text"]
		"groq":
			if "choices" in response_data and response_data["choices"].size() > 0:
				var choice = response_data["choices"][0]
				if "message" in choice and "content" in choice["message"]:
					extracted_text = choice["message"]["content"]
		"ollama":
			if "response" in response_data:
				extracted_text = response_data["response"]

	if extracted_text.is_empty():
		error_occurred.emit("No valid response received from API")
	else:
		response_received.emit(extracted_text)

func generate_code(prompt: String, language: String = "gdscript"):
	var context = "You are a helpful coding assistant. Generate clean, well-commented " + language + " code based on the following request. Only return the code without explanations unless specifically asked:"
	send_chat_request(prompt, context)

func explain_code(code: String):
	var context = "You are a helpful coding assistant. Explain the following code in detail, including what it does, how it works, and any potential improvements:"
	send_chat_request(code, context)

func suggest_improvements(code: String):
	var context = "You are a helpful coding assistant. Analyze the following code and suggest improvements for performance, readability, and best practices:"
	send_chat_request(code, context)
