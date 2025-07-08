@tool
extends Node
class_name AIOllama

# Dedicated Ollama API handler with 2025 latest features
# Supports local models, streaming, embeddings, and advanced features

signal response_received(response: String)
signal stream_chunk_received(chunk: String)
signal error_occurred(error: String)
signal model_loaded(model_name: String)
signal model_list_updated(models: Array)

# Configuration
var base_url: String = "http://localhost:11434"
var current_model: String = "llama3.2"
var stream_enabled: bool = false
var temperature: float = 0.7
var max_tokens: int = 2048
var context_window: int = 4096
var keep_alive: String = "5m"

# HTTP requests
var http_request: HTTPRequest
var stream_request: HTTPRequest
var model_request: HTTPRequest

# Available models with metadata
var available_models: Array[Dictionary] = []
var model_info: Dictionary = {}

# Conversation context
var conversation_history: Array[Dictionary] = []
var system_prompt: String = ""

func _ready():
	"""Initialize Ollama handler with latest 2025 API features"""
	_setup_http_requests()
	_load_default_models()
	call_deferred("check_ollama_status")
	call_deferred("refresh_model_list")

func _setup_http_requests():
	"""Setup HTTP request nodes for different operations"""
	# Main request handler
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# Streaming request handler
	stream_request = HTTPRequest.new()
	add_child(stream_request)
	stream_request.request_completed.connect(_on_stream_completed)
	
	# Model management request handler
	model_request = HTTPRequest.new()
	add_child(model_request)
	model_request.request_completed.connect(_on_model_request_completed)

func _load_default_models():
	"""Load default model configurations for 2025"""
	available_models = [
		{
			"name": "llama3.2",
			"description": "Meta's latest Llama 3.2 model - excellent for general tasks",
			"size": "3.2B",
			"type": "chat",
			"recommended": true,
			"context_length": 128000
		},
		{
			"name": "llama3.2:1b",
			"description": "Lightweight Llama 3.2 1B - fast and efficient",
			"size": "1B",
			"type": "chat",
			"recommended": false,
			"context_length": 128000
		},
		{
			"name": "llama3.2:3b",
			"description": "Balanced Llama 3.2 3B - good performance/speed ratio",
			"size": "3B",
			"type": "chat",
			"recommended": true,
			"context_length": 128000
		},
		{
			"name": "qwen2.5-coder",
			"description": "Alibaba's Qwen2.5 Coder - specialized for programming",
			"size": "7B",
			"type": "code",
			"recommended": true,
			"context_length": 32768
		},
		{
			"name": "qwen2.5-coder:1.5b",
			"description": "Lightweight Qwen2.5 Coder - fast coding assistant",
			"size": "1.5B",
			"type": "code",
			"recommended": false,
			"context_length": 32768
		},
		{
			"name": "codellama:7b",
			"description": "Meta's CodeLlama - excellent for code generation",
			"size": "7B",
			"type": "code",
			"recommended": true,
			"context_length": 16384
		},
		{
			"name": "codellama:13b",
			"description": "Larger CodeLlama - better code understanding",
			"size": "13B",
			"type": "code",
			"recommended": false,
			"context_length": 16384
		},
		{
			"name": "mistral:7b",
			"description": "Mistral 7B - fast and capable general model",
			"size": "7B",
			"type": "chat",
			"recommended": true,
			"context_length": 32768
		},
		{
			"name": "phi3:mini",
			"description": "Microsoft Phi-3 Mini - compact but powerful",
			"size": "3.8B",
			"type": "chat",
			"recommended": true,
			"context_length": 128000
		},
		{
			"name": "phi3:medium",
			"description": "Microsoft Phi-3 Medium - balanced performance",
			"size": "14B",
			"type": "chat",
			"recommended": false,
			"context_length": 128000
		},
		{
			"name": "gemma2:2b",
			"description": "Google Gemma 2 2B - efficient and capable",
			"size": "2B",
			"type": "chat",
			"recommended": true,
			"context_length": 8192
		},
		{
			"name": "gemma2:9b",
			"description": "Google Gemma 2 9B - high performance",
			"size": "9B",
			"type": "chat",
			"recommended": false,
			"context_length": 8192
		},
		{
			"name": "deepseek-coder:6.7b",
			"description": "DeepSeek Coder - specialized programming model",
			"size": "6.7B",
			"type": "code",
			"recommended": true,
			"context_length": 16384
		},
		{
			"name": "starcoder2:3b",
			"description": "StarCoder2 3B - code generation and completion",
			"size": "3B",
			"type": "code",
			"recommended": true,
			"context_length": 16384
		},
		{
			"name": "nomic-embed-text",
			"description": "Nomic Embed - text embeddings model",
			"size": "137M",
			"type": "embedding",
			"recommended": false,
			"context_length": 8192
		}
	]

func check_ollama_status() -> bool:
	"""Check if Ollama is running and accessible"""
	var url = base_url + "/api/tags"
	var headers = ["Content-Type: application/json"]
	
	print("Checking Ollama status at: ", url)
	model_request.request(url, headers, HTTPClient.METHOD_GET)
	return true

func refresh_model_list():
	"""Refresh the list of available models from Ollama"""
	var url = base_url + "/api/tags"
	var headers = ["Content-Type: application/json"]
	
	model_request.request(url, headers, HTTPClient.METHOD_GET)

func get_available_models() -> Array[Dictionary]:
	"""Get list of available models with metadata"""
	return available_models

func get_recommended_models() -> Array[Dictionary]:
	"""Get only recommended models for easier selection"""
	var recommended = []
	for model in available_models:
		if model.get("recommended", false):
			recommended.append(model)
	return recommended

func get_code_models() -> Array[Dictionary]:
	"""Get models specialized for coding"""
	var code_models = []
	for model in available_models:
		if model.get("type", "") == "code":
			code_models.append(model)
	return code_models

func set_model(model_name: String):
	"""Set the current model"""
	current_model = model_name
	print("Ollama model set to: ", model_name)
	
	# Update context window based on model
	for model in available_models:
		if model["name"] == model_name:
			context_window = model.get("context_length", 4096)
			break
	
	model_loaded.emit(model_name)

func set_base_url(url: String):
	"""Set custom Ollama server URL"""
	base_url = url.rstrip("/")
	print("Ollama base URL set to: ", base_url)

func set_system_prompt(prompt: String):
	"""Set system prompt for conversation context"""
	system_prompt = prompt
	print("System prompt set for Ollama")

func clear_conversation():
	"""Clear conversation history"""
	conversation_history.clear()
	print("Ollama conversation history cleared")

func send_chat_message(message: String, use_context: bool = true) -> void:
	"""Send chat message with 2025 Ollama API features"""
	var url = base_url + "/api/chat"
	var headers = ["Content-Type: application/json"]
	
	# Build messages array
	var messages = []
	
	# Add system prompt if set
	if not system_prompt.is_empty():
		messages.append({
			"role": "system",
			"content": system_prompt
		})
	
	# Add conversation history if using context
	if use_context:
		messages.append_array(conversation_history)
	
	# Add current message
	messages.append({
		"role": "user",
		"content": message
	})
	
	# Build request body with 2025 features
	var body = {
		"model": current_model,
		"messages": messages,
		"stream": stream_enabled,
		"options": {
			"temperature": temperature,
			"num_predict": max_tokens,
			"num_ctx": context_window
		},
		"keep_alive": keep_alive
	}
	
	var json_body = JSON.stringify(body)
	print("Sending Ollama chat request to: ", url)
	print("Using model: ", current_model)
	print("Stream enabled: ", stream_enabled)
	
	if stream_enabled:
		stream_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	else:
		http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	
	# Add to conversation history
	if use_context:
		conversation_history.append({
			"role": "user",
			"content": message
		})

func generate_code(prompt: String, language: String = "gdscript") -> void:
	"""Generate code with specialized prompt"""
	var code_prompt = "You are an expert " + language + " programmer. Generate clean, well-commented, and efficient code based on this request. Only return the code without explanations unless specifically asked:\n\n" + prompt
	
	# Use a code-specialized model if available
	var original_model = current_model
	var code_models = get_code_models()
	if code_models.size() > 0:
		set_model(code_models[0]["name"])
	
	send_chat_message(code_prompt, false)
	
	# Restore original model after request
	if original_model != current_model:
		call_deferred("set_model", original_model)

func explain_code(code: String) -> void:
	"""Explain code with detailed analysis"""
	var explain_prompt = "You are a code analysis expert. Explain this code in detail, including:\n1. What it does\n2. How it works\n3. Key concepts used\n4. Potential improvements\n5. Best practices\n\nCode to analyze:\n```\n" + code + "\n```"
	send_chat_message(explain_prompt, false)

func improve_code(code: String) -> void:
	"""Suggest code improvements"""
	var improve_prompt = "You are a code optimization expert. Analyze this code and suggest improvements for:\n1. Performance\n2. Readability\n3. Best practices\n4. Error handling\n5. Maintainability\n\nProvide the improved code with explanations:\n```\n" + code + "\n```"
	send_chat_message(improve_prompt, false)

func pull_model(model_name: String) -> void:
	"""Pull/download a model from Ollama registry"""
	var url = base_url + "/api/pull"
	var headers = ["Content-Type: application/json"]

	var body = {
		"name": model_name,
		"stream": false
	}

	var json_body = JSON.stringify(body)
	print("Pulling Ollama model: ", model_name)
	model_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func delete_model(model_name: String) -> void:
	"""Delete a model from local storage"""
	var url = base_url + "/api/delete"
	var headers = ["Content-Type: application/json"]

	var body = {
		"name": model_name
	}

	var json_body = JSON.stringify(body)
	print("Deleting Ollama model: ", model_name)
	model_request.request(url, headers, HTTPClient.METHOD_DELETE, json_body)

func get_model_info(model_name: String) -> void:
	"""Get detailed information about a model"""
	var url = base_url + "/api/show"
	var headers = ["Content-Type: application/json"]

	var body = {
		"name": model_name
	}

	var json_body = JSON.stringify(body)
	model_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func generate_embeddings(text: String, model_name: String = "nomic-embed-text") -> void:
	"""Generate text embeddings using Ollama"""
	var url = base_url + "/api/embeddings"
	var headers = ["Content-Type: application/json"]

	var body = {
		"model": model_name,
		"prompt": text
	}

	var json_body = JSON.stringify(body)
	print("Generating embeddings with model: ", model_name)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle non-streaming responses"""
	print("Ollama request completed - Result: ", result, " Response code: ", response_code)

	if response_code != 200:
		var error_msg = "Ollama request failed with code: " + str(response_code)
		if response_code == 404:
			error_msg += " - Model not found or Ollama not running"
		elif response_code == 500:
			error_msg += " - Internal server error"
		error_occurred.emit(error_msg)
		return

	var response_text = body.get_string_from_utf8()
	print("Ollama response: ", response_text)

	var json = JSON.new()
	var parse_result = json.parse(response_text)
	if parse_result != OK:
		error_occurred.emit("Failed to parse Ollama response")
		return

	var response_data = json.data

	# Handle different response types
	if "message" in response_data:
		# Chat response
		var message_content = response_data["message"].get("content", "")
		if not message_content.is_empty():
			# Add assistant response to conversation history
			conversation_history.append({
				"role": "assistant",
				"content": message_content
			})
			response_received.emit(message_content)
		else:
			error_occurred.emit("Empty response from Ollama")
	elif "embedding" in response_data:
		# Embeddings response
		var embeddings = response_data["embedding"]
		response_received.emit("Embeddings generated: " + str(embeddings.size()) + " dimensions")
	else:
		error_occurred.emit("Unknown response format from Ollama")

func _on_stream_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle streaming responses"""
	print("Ollama stream completed - Result: ", result, " Response code: ", response_code)

	if response_code != 200:
		error_occurred.emit("Ollama stream failed with code: " + str(response_code))
		return

	var response_text = body.get_string_from_utf8()
	var lines = response_text.split("\n")
	var full_response = ""

	for line in lines:
		if line.strip_edges().is_empty():
			continue

		var json = JSON.new()
		var parse_result = json.parse(line)
		if parse_result != OK:
			continue

		var chunk_data = json.data
		if "message" in chunk_data:
			var content = chunk_data["message"].get("content", "")
			if not content.is_empty():
				full_response += content
				stream_chunk_received.emit(content)

		# Check if stream is done
		if chunk_data.get("done", false):
			if not full_response.is_empty():
				conversation_history.append({
					"role": "assistant",
					"content": full_response
				})
				response_received.emit(full_response)
			break

func _on_model_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle model management responses"""
	print("Ollama model request completed - Result: ", result, " Response code: ", response_code)

	if response_code != 200:
		if response_code == 404:
			error_occurred.emit("Ollama server not found - is it running on " + base_url + "?")
		else:
			error_occurred.emit("Model request failed with code: " + str(response_code))
		return

	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(response_text)
	if parse_result != OK:
		error_occurred.emit("Failed to parse model response")
		return

	var response_data = json.data

	# Handle model list response
	if "models" in response_data:
		var models = response_data["models"]
		var model_names = []
		for model in models:
			model_names.append(model.get("name", "unknown"))
		print("Available Ollama models: ", model_names)
		model_list_updated.emit(models)

	# Handle model info response
	elif "modelfile" in response_data:
		model_info = response_data
		print("Model info received for: ", response_data.get("name", "unknown"))

func enable_streaming(enabled: bool = true):
	"""Enable or disable streaming responses"""
	stream_enabled = enabled
	print("Ollama streaming ", "enabled" if enabled else "disabled")

func set_temperature(temp: float):
	"""Set response temperature (0.0 to 1.0)"""
	temperature = clamp(temp, 0.0, 1.0)
	print("Ollama temperature set to: ", temperature)

func set_max_tokens(tokens: int):
	"""Set maximum tokens for response"""
	max_tokens = max(1, tokens)
	print("Ollama max tokens set to: ", max_tokens)

func set_context_window(size: int):
	"""Set context window size"""
	context_window = max(512, size)
	print("Ollama context window set to: ", context_window)

func set_keep_alive(duration: String):
	"""Set how long to keep model in memory (e.g., '5m', '1h', '0' for immediate unload)"""
	keep_alive = duration
	print("Ollama keep alive set to: ", duration)

func is_ollama_available() -> bool:
	"""Check if Ollama is available and responsive"""
	# This would be set by the status check
	return available_models.size() > 0

func get_model_by_type(type: String) -> Dictionary:
	"""Get the best model for a specific type (chat, code, embedding)"""
	for model in available_models:
		if model.get("type", "") == type and model.get("recommended", false):
			return model

	# Fallback to first model of type
	for model in available_models:
		if model.get("type", "") == type:
			return model

	return {}

func get_fastest_model() -> Dictionary:
	"""Get the fastest (smallest) available model"""
	var fastest = {}
	var smallest_size = 999999

	for model in available_models:
		var size_str = model.get("size", "999B")
		var size_num = _parse_model_size(size_str)
		if size_num < smallest_size:
			smallest_size = size_num
			fastest = model

	return fastest

func _parse_model_size(size_str: String) -> float:
	"""Parse model size string to number for comparison"""
	var size_lower = size_str.to_lower()
	var num_str = size_lower.rstrip("bmk")
	var multiplier = 1.0

	if "k" in size_lower:
		multiplier = 0.001
	elif "m" in size_lower:
		multiplier = 1.0
	elif "b" in size_lower:
		multiplier = 1000.0

	return num_str.to_float() * multiplier
