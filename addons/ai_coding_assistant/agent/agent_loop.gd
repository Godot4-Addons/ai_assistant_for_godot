@tool
extends Node
class_name AIAgentLoop

## Main agentic orchestrator — the plan→act→observe loop engine.
## Replaces the inline tool execution in AIApiManager for code/auto modes.
## Connects all components: memory, context, tools, loop guard, permissions.

const LoopGuard = preload("res://addons/ai_coding_assistant/agent/loop_guard.gd")
const PermManager = preload("res://addons/ai_coding_assistant/agent/permission_manager.gd")
const AgentMemory = preload("res://addons/ai_coding_assistant/agent/agent_memory.gd")
const AgentContext = preload("res://addons/ai_coding_assistant/agent/agent_context.gd")
const ToolRegistry = preload("res://addons/ai_coding_assistant/agent/tool_registry.gd")
const AgentPersona = preload("res://addons/ai_coding_assistant/persona/agent_persona.gd")

enum State {IDLE, PLANNING, EXECUTING, WAITING_RESPONSE, OBSERVING, COMPLETED, ERROR}

signal step_started(step_num: int, description: String)
signal tool_executed(tool_name: String, args: Dictionary, result: Dictionary, message: String)
signal agent_thinking(message: String)
signal status_changed(state: State, message: String)
signal permission_needed(tool_name: String, args: Dictionary, description: String, confirm_callable: Callable)
signal agent_finished(final_response: String)
signal agent_error(error_message: String)

var state: State = State.IDLE
var _task: String = ""
var _api_manager ## AIApiManager reference
var _loop_guard: AILoopGuard
var _permissions: AIPermissionManager
var _memory: AIAgentMemory
var _ctx: AIAgentContext
var _tools: AIToolRegistry
var _current_response: String = ""
var _pending_tool_calls: Array[Dictionary] = []
var _pending_confirm: Dictionary = {} # { confirm_callable }
var _last_results_hash: String = ""

## Configuration
var max_iterations: int = 25
var enable_planning: bool = true
var auto_save_memory: bool = true
var _git_available: bool = false

## Internal guard to prevent re-entrant stop calls
var _is_stopping: bool = false

func _init(api_manager, editor_integration, editor_interface = null) -> void:
	_api_manager = api_manager
	_loop_guard = LoopGuard.new()
	_permissions = PermManager.new()
	_memory = AgentMemory.new()
	_ctx = AgentContext.new(editor_interface)
	_tools = ToolRegistry.new(editor_integration, _ctx)

	_loop_guard.limit_approached.connect(func(msg): agent_thinking.emit("⚠️ " + msg))
	_loop_guard.limit_reached.connect(func(reason): _force_stop(reason))
	_permissions.permission_requested.connect(_on_permission_requested)
	_tools.tool_executed.connect(_on_tool_complete)
	
	_loop_guard.max_iterations = max_iterations
	_check_git_availability()

func _check_git_availability() -> void:
	# Check for git presence
	var version_out: Array[String] = []
	var res: int = OS.execute("git", ["--version"], version_out, true)
	_git_available = (res == 0)
	if not _git_available:
		agent_thinking.emit("⚠️ Git is not installed or not in PATH. Fallback backup system is enabled.")

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Entry point — start an agentic task
func run(task: String) -> void:
	if state != State.IDLE:
		agent_error.emit("Agent is already running. Stop it first.")
		return

	_task = task
	_loop_guard.max_iterations = max_iterations
	_loop_guard.reset()
	_memory.clear_working_memory()

	# Load relevant past context
	var past := _memory.get_relevant_context(task)
	if not past.is_empty():
		_memory.add_agent_thought("Relevant past work found:\n" + past)

	_set_state(State.PLANNING)
	agent_thinking.emit("🧠 Starting agent for: %s" % task)

	_send_to_ai(task)

func stop() -> void:
	if _is_stopping:
		return
	_is_stopping = true
	# Cancel the SSE client directly — do NOT call api_manager.cancel_request()
	# to avoid the circular call: cancel_request → stop → cancel_request → ∞
	if _api_manager and _api_manager._sse_client:
		_api_manager._sse_client.cancel()
	_finish_with_message("[Agent stopped by user.]")
	_is_stopping = false

## Called by api_manager when a streaming chunk arrives
func on_chunk_received(chunk: String) -> void:
	_current_response += chunk

## Called by api_manager when the full response is ready
func on_response_received(response: String) -> void:
	_current_response = response
	_set_state(State.OBSERVING)
	_process_response(response)

## Called by api_manager when an error occurs
func on_error_received(error: String) -> void:
	if state == State.IDLE:
		return
	_set_state(State.ERROR)
	agent_error.emit("API Error: " + error)
	_set_state(State.IDLE)

# ─────────────────────────────────────────────────────────────────────────────
# Loop Processing
# ─────────────────────────────────────────────────────────────────────────────

func _process_response(response: String) -> void:
	# Parse tool calls from response
	var tool_calls := _tools.parse_tool_calls(response)

	# Check loop guard
	var guard_result := _loop_guard.check(tool_calls, response, _last_results_hash)
	if not guard_result.allowed:
		_finish_with_message(response + "\n\n" + guard_result.reason)
		return

	# Inject guard warning if any
	if not guard_result.warning.is_empty():
		_memory.add_agent_thought(guard_result.warning)

	# No tool calls = agent is done (or failed to use XML)
	if tool_calls.is_empty():
		var hallucinated_tool := _detect_hallucinated_tool(response)
		if not hallucinated_tool.is_empty():
			var err_msg := "⚠️ SYSTEM ERROR: Invalid tool format detected. You mentioned '%s' but failed to use the mandatory XML tags. \n\nCRITICAL: You MUST use the format: <%s key=\"value\" />\nExample: <read_file path=\"res://main.gd\" />\n\nPlease retry with the correct format." % [hallucinated_tool, hallucinated_tool]
			_memory.add_agent_thought(err_msg)
			agent_thinking.emit(err_msg)
			_send_to_ai(err_msg, false) # Request correction
			return

		_finish_with_message(response)
		return

	# Detect if any calls were "fuzzy" (not XML) to warn the AI
	var was_fuzzy := not response.contains("<") or not response.contains(">")

	# Execute tools
	_set_state(State.EXECUTING)
	
	# Git Safety Check
	var dirty_files := _get_dirty_files(tool_calls)
	if not dirty_files.is_empty():
		if _git_available:
			var msg := "⚠️ The following files have uncommitted changes: %s. Please commit them using <git command=\"commit\" args=\"-m '...'\" /> before modifying them further to ensure you can revert if needed." % ", ".join(dirty_files)
			_memory.add_agent_thought(msg)
			agent_thinking.emit(msg)
		else:
			# Fallback: Create backups automatically
			var backups := []
			for file in dirty_files:
				var backup_path = _tools._editor_integration.writer.create_backup(file)
				if not backup_path.is_empty():
					backups.append(backup_path.get_file())
			if not backups.is_empty():
				var msg := "🛡️ Git not found. Created emergency backups for dirty files: %s" % ", ".join(backups)
				_memory.add_agent_thought(msg)
				agent_thinking.emit(msg)
	
	var tool_results: Array[String] = []
	
	for call in tool_calls:
		var tool_name: String = call.get("tool", "")
		var args: Dictionary = call.get("args", {})

		# Check permission
		var perm := _permissions.check(tool_name, args)
		if perm.needs_confirmation:
			# Queue for user confirmation — pause loop until resolved
			_pending_tool_calls = tool_calls
			_pending_confirm = {"tool": tool_name, "args": args, "remaining_calls": tool_calls}
			permission_needed.emit(tool_name, args, perm.message,
				Callable(self, "_on_confirmation_result"))
			return

		if not perm.allowed:
			var err_result := {"error": perm.message}
			_memory.add_tool_result(tool_name, args, err_result)
			var formatted := _tools.format_result_for_prompt(tool_name, args, err_result)
			if was_fuzzy:
				formatted = "⚠️ FORMATTING WARNING: Your last call used a non-XML format. The system recovered it using fuzzy parsing, but you MUST use valid XML <tool_name key=\"value\" /> going forward.\n" + formatted
			tool_results.append(formatted)
			continue

		# Show progress
		if not perm.message.is_empty():
			tool_executed.emit(tool_name, args, {}, perm.message)

		step_started.emit(_loop_guard.get_iteration(), "🔧 %s" % tool_name)
		agent_status_changed.emit(state, "Running " + tool_name + "...")

		# Execute with error wrapping
		var result: Dictionary = {}
		if _tools and _permissions:
			result = _tools.execute_tool(tool_name, args)
		else:
			result = {"error": "Tool system unavailable"}
			
		# Let Godot's main thread breathe (prevents freeze during heavy multi-tool ops)
		if _api_manager and _api_manager.is_inside_tree():
			await _api_manager.get_tree().process_frame
			
		_memory.add_tool_result(tool_name, args, result)
		var result_str := _tools.format_result_for_prompt(tool_name, args, result)
		
		# Add fuzzy warning if needed
		if was_fuzzy:
			result_str = "⚠️ FORMATTING WARNING: Your last call used a non-XML format. The system recovered it using fuzzy parsing, but you MUST use valid XML <tool_name key=\"value\" /> going forward.\n" + result_str
			
		tool_results.append(result_str)

		# Safety check — if stopped while executing tools, abort
		if state == State.IDLE:
			return
	
	# Update results hash for the loop guard (to detect if we're actually making progress)
	_last_results_hash = str("\n".join(tool_results).hash())

	# Feed results back as the next message
	_set_state(State.WAITING_RESPONSE)
	var feedback := "Tool Results:\n" + "\n---\n".join(tool_results)
	feedback += "\n\n" + _memory.get_working_memory_prompt()
	feedback += "\n\nContinue the task. If all goals are achieved, provide a clear final summary without using any tool tags."

	_send_to_ai(feedback, false)

func _on_confirmation_result(confirmed: bool) -> void:
	if not confirmed:
		_memory.add_agent_thought("User denied the operation.")
		_finish_with_message("Operation cancelled by user. " + _current_response)
		return
	# Re-trigger processing (permission granted)
	_process_response(_current_response)

func _on_permission_requested(tool_name: String, args: Dictionary, description: String) -> void:
	permission_needed.emit(tool_name, args, description, Callable(self , "_on_confirmation_result"))

func _on_tool_complete(tool_name: String, args: Dictionary, result: Dictionary) -> void:
	var msg := _tools.format_result_for_prompt(tool_name, args, result)
	tool_executed.emit(tool_name, args, result, msg)

# ─────────────────────────────────────────────────────────────────────────────
# AI Communication
# ─────────────────────────────────────────────────────────────────────────────

func _send_to_ai(message: String, include_system_context: bool = true) -> void:
	_current_response = ""
	_set_state(State.WAITING_RESPONSE)

	var context := ""
	if include_system_context:
		context = AgentPersona.get_prompt()
		context += "\n\n" + _tools.get_tool_schemas()
		context += "\n\n" + _ctx.build_quick_context()
		context += "\n\n" + AIProjectBlueprint.get_blueprint()
		var mem_ctx := _memory.get_working_memory_prompt()
		if not mem_ctx.is_empty():
			context += "\n\n" + mem_ctx

	# Delegate to api_manager's raw send method
	_api_manager.send_agent_request(message, context, _memory.get_api_history())

func _finish_with_message(response: String) -> void:
	_set_state(State.COMPLETED)

	# Save to memory
	if auto_save_memory and not _task.is_empty():
		_memory.add_exchange(_task, response.substr(0, 500))
		_memory.save_session(_task.substr(0, 100))

	agent_finished.emit(response)
	_set_state(State.IDLE)

func _force_stop(reason: String) -> void:
	if _is_stopping:
		return
	_is_stopping = true
	# Cancel SSE directly — never call cancel_request() here (causes circular call)
	if _api_manager and _api_manager._sse_client:
		_api_manager._sse_client.cancel()
	_finish_with_message("[Agent stopped: %s]\n\n%s" % [reason, _current_response])
	_is_stopping = false

func _get_dirty_files(tool_calls: Array) -> Array[String]:
	var dirty: Array[String] = []
	for call in tool_calls:
		var tool: String = call.get("tool", "")
		if tool in ["write_file", "patch_file", "delete_file"]:
			var path: String = call.get("args", {}).get("path", "")
			if not path.is_empty():
				if _git_available:
					if _is_file_dirty(path):
						dirty.append(path)
				else:
					# If git is missing, treat all modified files as dirty to ensure backups
					dirty.append(path)
	return dirty

func _is_file_dirty(path: String) -> bool:
	var output: Array[String] = []
	var res: int = OS.execute("git", ["status", "--porcelain", ProjectSettings.globalize_path(path)], output, true)
	if res == 0 and not output.is_empty() and not output[0].strip_edges().is_empty():
		return true
	return false

func _detect_hallucinated_tool(response: String) -> String:
	if not _tools: return ""
	var tool_names := _tools._tools.keys()
	# Look for tool names followed by common non-XML markers or just mentioned as an action
	for t_name in tool_names:
		var patterns = [
			t_name + "(", # Python style
			t_name + " (",
			t_name + "{", # JSON style
			"use " + t_name,
			"call " + t_name,
			"run " + t_name,
			"tool_code", # Generic block
			"tool =>", # Dictionary style
			"=> '" + t_name + "'",
			"=> \"" + t_name + "\""
		]
		for p in patterns:
			if response.to_lower().contains(p.to_lower()):
				return t_name
	return ""

func _set_state(new_state: State) -> void:
	state = new_state
	var labels := ["💤 Idle", "🧠 Planning", "⚙️ Executing", "⏳ Waiting AI", "👁️ Observing", "✅ Done", "❌ Error"]
	status_changed.emit(new_state, labels[new_state])
