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

## Configuration
var max_iterations: int = 15
var enable_planning: bool = true
var auto_save_memory: bool = true

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

## Stop the agent mid-loop — safe to call from any context
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
	var guard_result := _loop_guard.check(tool_calls, response)
	if not guard_result.allowed:
		_finish_with_message(response + "\n\n" + guard_result.reason)
		return

	# Inject guard warning if any
	if not guard_result.warning.is_empty():
		_memory.add_agent_thought(guard_result.warning)

	# No tool calls = agent is done
	if tool_calls.is_empty():
		_finish_with_message(response)
		return

	# Execute tools
	_set_state(State.EXECUTING)
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
				Callable(self , "_on_confirmation_result"))
			return

		if not perm.allowed:
			var err_result := {"error": perm.message}
			_memory.add_tool_result(tool_name, args, err_result)
			tool_results.append(_tools.format_result_for_prompt(tool_name, args, err_result))
			continue

		# Show progress
		if not perm.message.is_empty():
			tool_executed.emit(tool_name, args, {}, perm.message)

		step_started.emit(_loop_guard.get_iteration(), "🔧 %s" % tool_name)

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
		tool_results.append(result_str)

		# Safety check — if stopped while executing tools, abort
		if state == State.IDLE:
			return

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

func _set_state(new_state: State) -> void:
	state = new_state
	var labels := ["💤 Idle", "🧠 Planning", "⚙️ Executing", "⏳ Waiting AI", "👁️ Observing", "✅ Done", "❌ Error"]
	status_changed.emit(new_state, labels[new_state])
