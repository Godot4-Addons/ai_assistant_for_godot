@tool
extends RefCounted

const BaseProvider = preload("res://addons/ai_coding_assistant/ai_provider/base_provider.gd")

static func get_name() -> String:
	return "gemini"

static func get_base_url() -> String:
	return "https://generativelanguage.googleapis.com/v1beta/models/"

static func get_default_model() -> String:
	return "gemini-2.5-flash"

static func build_request(base_url: String, api_key: String, model: String, message: String, history: Array, system_prompt: String) -> Dictionary:
	var contents: Array = []
	for entry in history:
		var gemini_role = "model" if entry["role"] == "assistant" else "user"
		contents.append({
			"role": gemini_role,
			"parts": [ {"text": entry["content"]}]
		})
	
	if not system_prompt.is_empty():
		# Gemini handles system prompts separately in some versions, but 
		# for simplicity we'll prepend it if history is empty or as a user message
		contents.insert(0, {
			"role": "user",
			"parts": [ {"text": "System instructions: " + system_prompt}]
		})
		
	contents.append({
		"role": "user",
		"parts": [ {"text": message}]
	})

	var body = {
		"contents": contents
	}
	return {
		"url": base_url + model + ":generateContent?key=" + api_key,
		"headers": ["Content-Type: application/json"],
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body)
	}

static func parse_response(response_data: Variant) -> String:
	if response_data is Dictionary and response_data.has("candidates") and response_data["candidates"].size() > 0:
		var candidate = response_data["candidates"][0]
		if candidate is Dictionary and candidate.has("content") and candidate["content"].has("parts") and candidate["content"]["parts"].size() > 0:
			return str(candidate["content"]["parts"][0].get("text", ""))
	return ""
