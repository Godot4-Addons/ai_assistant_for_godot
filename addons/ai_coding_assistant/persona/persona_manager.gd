@tool
extends RefCounted
class_name AIPersonaManager

const DefaultPersona = preload("res://addons/ai_coding_assistant/persona/default_persona.gd")
const AgentPersona = preload("res://addons/ai_coding_assistant/persona/agent_persona.gd")
const PlanPersona = preload("res://addons/ai_coding_assistant/persona/plan_persona.gd")

## Build full system prompt for the given mode.
## In code/auto modes, the agent loop now handles context injection directly,
## so this is used only for the first message and for the chat mode.
static func get_full_context(current_mode: String, user_context: String, blueprint: String = "") -> String:
	var prompt := DefaultPersona.get_prompt()

	if current_mode in ["code", "auto"]:
		# The agent loop injects tool schemas + project context separately.
		# This provides the core persona + planning instructions.
		prompt += "\n" + AgentPersona.get_prompt()
		prompt += "\n" + PlanPersona.get_prompt()
		if not blueprint.is_empty():
			prompt += "\n\n### PROJECT BLUEPRINT\n" + blueprint

	if not user_context.is_empty():
		prompt += "\n\n### USER CONTEXT\n" + user_context

	return prompt

## Build a complete agent system prompt including tool schemas and project info.
## Called by AgentLoop directly.
static func get_agent_system_prompt(tool_schemas: String, project_context: String, blueprint: String, user_context: String) -> String:
	var prompt := DefaultPersona.get_prompt()
	prompt += "\n\n" + AgentPersona.get_prompt()
	prompt += "\n\n" + PlanPersona.get_prompt()

	if not tool_schemas.is_empty():
		prompt += "\n\n" + tool_schemas

	if not project_context.is_empty():
		prompt += "\n\n" + project_context

	if not blueprint.is_empty():
		prompt += "\n\n### PROJECT BLUEPRINT\n" + blueprint

	if not user_context.is_empty():
		prompt += "\n\n### USER CONTEXT\n" + user_context

	return prompt
