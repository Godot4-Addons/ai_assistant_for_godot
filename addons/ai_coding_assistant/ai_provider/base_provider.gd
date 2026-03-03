@tool
extends RefCounted

static func get_name() -> String:
	return ""

static func get_base_url() -> String:
	return ""

static func combine_prompt(message: String, context: String) -> String:
	return context + "\n\n" + message if not context.is_empty() else message

static func build_chat_messages(message: String, context: String) -> Array:
	var messages: Array = []
	if not context.is_empty():
		messages.append({"role": "system", "content": context})
	messages.append({"role": "user", "content": message})
	return messages
