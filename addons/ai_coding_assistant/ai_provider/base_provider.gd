@tool
extends RefCounted

static func get_name() -> String:
	return ""

static func get_base_url() -> String:
	return ""

static func combine_prompt(message: String, context: String) -> String:
	return context + "\n\n" + message if not context.is_empty() else message

static func build_chat_messages(message: String, history: Array = [], system_prompt: String = "") -> Array:
	var messages: Array = []
	if not system_prompt.is_empty():
		messages.append({"role": "system", "content": system_prompt})
	
	for entry in history:
		messages.append(entry)
		
	messages.append({"role": "user", "content": message})
	return messages
