@tool
extends RefCounted

const BaseProvider = preload("res://addons/ai_coding_assistant/ai_provider/base_provider.gd")

static func get_name() -> String:
	return "anthropic"

static func get_base_url() -> String:
	return "https://api.anthropic.com/v1/"

static func get_default_model() -> String:
	return "claude-3-5-sonnet-20241022"

static func build_request(base_url: String, api_key: String, model: String, message: String, history: Array, system_prompt: String) -> Dictionary:
	var body = {
		"model": model,
		"max_tokens": 2048,
		"system": system_prompt,
		"messages": BaseProvider.build_chat_messages(message, history, "") # don't include system in messages
	}
	return {
		"url": base_url + "messages",
		"headers": [
			"x-api-key: " + api_key,
			"Content-Type: application/json",
			"anthropic-version: 2023-06-01"
		],
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body)
	}

static func parse_response(response_data: Variant) -> String:
	if response_data is Dictionary and response_data.has("content") and response_data["content"].size() > 0:
		return str(response_data["content"][0].get("text", ""))
	return ""
