@tool
extends RefCounted

const BaseProvider = preload("res://addons/ai_coding_assistant/ai_provider/base_provider.gd")

static func get_name() -> String:
	return "opencode_zen"

static func get_base_url() -> String:
	return "https://opencode.ai/zen/v1/"

static func get_default_model() -> String:
	return "opencode/gemini-3.1-pro"

static func build_request(base_url: String, api_key: String, model: String, message: String, history: Array, system_prompt: String) -> Dictionary:
	var body = {
		"model": model,
		"messages": BaseProvider.build_chat_messages(message, history, system_prompt),
		"max_tokens": 4096,
		"temperature": 0.7
	}
	return {
		"url": base_url + "chat/completions",
		"headers": [
			"Authorization: Bearer " + api_key,
			"Content-Type: application/json",
			"HTTP-Referer: AI_assistant_for_GODOT",
			"X-Title: AI_assistant_for_GODOT"
		],
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body)
	}

static func parse_response(response_data: Variant) -> String:
	if response_data is Dictionary and response_data.has("choices") and response_data["choices"].size() > 0:
		var choice = response_data["choices"][0]
		if choice is Dictionary and choice.has("message"):
			var content = choice["message"].get("content")
			if content == null: return ""
			return str(content)
	return ""

static func parse_stream_chunk(response_data: Variant) -> String:
	if response_data is Dictionary and response_data.has("choices") and response_data["choices"].size() > 0:
		var choice = response_data["choices"][0]
		if choice is Dictionary and choice.has("delta"):
			var content = choice["delta"].get("content")
			if content == null:
				return ""
			return str(content)
	return ""
