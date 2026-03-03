@tool
extends RefCounted
class_name AIPersonaManager

const DefaultPersona = preload("res://addons/ai_coding_assistant/persona/default_persona.gd")
const AgentPersona = preload("res://addons/ai_coding_assistant/persona/agent_persona.gd")
const PlanPersona = preload("res://addons/ai_coding_assistant/persona/plan_persona.gd")

static func get_full_context(current_mode: String, user_context: String, blueprint: String = "") -> String:
	var prompt = DefaultPersona.get_prompt()
	
	if current_mode in ["code", "auto"]:
		prompt += "\n" + AgentPersona.get_prompt()
		prompt += "\n" + PlanPersona.get_prompt()
		if not blueprint.is_empty():
			prompt += "\n### PROJECT BLUEPRINT ###\n" + blueprint
	
	if not user_context.is_empty():
		prompt += "\n### USER SPECIFIC CONTEXT ###\n" + user_context
		
	return prompt
