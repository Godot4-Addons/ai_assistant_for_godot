@tool
extends Node
class_name AIAgentLoop

## Main agentic orchestrator — the plan→act→observe loop engine.
## Replaces the inline tool execution in AIApiManager for code/auto modes.
## Connects all components: memory, context, tools, loop guard, permissions.

const LoopEngine = preload("res://addons/ai_coding_assistant/agent/loop_engine.gd")
const PermManager = preload("res://addons/ai_coding_assistant/agent/permission_manager.gd")
const AgentMemory = preload("res://addons/ai_coding_assistant/agent/agent_memory.gd")
const AgentContext = preload("res://addons/ai_coding_assistant/agent/agent_context.gd")
const ToolRegistry = preload("res://addons/ai_coding_assistant/agent/tool_registry.gd")
const AgentPersona = preload("res://addons/ai_coding_assistant/persona/agent_persona.gd")
const DamageRepair = preload("res://addons/ai_coding_assistant/repair/damage_repair.gd")

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
var _loop_engine: AILoopEngine
var _damage_repair: AIDamageRepair
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
var auto_commit: bool = true  # Commit after every completed task (unless user disabled)
var _git_available: bool = false
var current_mode: String = "auto"  # "assistant", "code", or "auto"

## Co-author for all commits (ALWAYS included)
const CO_AUTHOR = "Co-authored-by: GrandpaEJ <103351465+GrandpaEJ@users.noreply.github.com>"

## Internal guard to prevent re-entrant stop calls
var _is_stopping: bool = false

func _init(api_manager, editor_integration, editor_interface = null, mode: String = "auto") -> void:
	_api_manager = api_manager
	current_mode = mode
	_loop_engine = LoopEngine.new()
	_damage_repair = DamageRepair.new()
	_permissions = PermManager.new()
	_memory = AgentMemory.new()
	_ctx = AgentContext.new(editor_interface)
	_tools = ToolRegistry.new(editor_integration, _ctx)

	# In assistant mode, be more lenient (no hard loop limit pressure, no aggressive planning)
	if current_mode == "assistant":
		max_iterations = 10
		enable_planning = false

	_loop_engine.limit_approached.connect(func(msg): agent_thinking.emit("⚠️ " + msg))
	_loop_engine.limit_reached.connect(func(reason): _force_stop(reason))
	_permissions.permission_requested.connect(_on_permission_requested)
	_tools.tool_executed.connect(_on_tool_complete)
	
	_loop_engine.max_iterations = max_iterations
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
	_loop_engine.max_iterations = max_iterations
	_loop_engine.reset()
	_damage_repair.reset_repair_count()
	_memory.clear_working_memory()

	# Load relevant past context
	var past := _memory.get_relevant_context(task)
	if not past.is_empty():
		_memory.add_agent_thought("Relevant past work found:\n" + past)

	_set_state(State.PLANNING)
	
	if current_mode == "assistant":
		agent_thinking.emit("🧠 Assistant thinking: %s" % task)
	else:
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
	var tool_calls := _tools.parse_tool_calls(response)

	var guard_result := _loop_engine.check(tool_calls, response, _last_results_hash)
	if not guard_result.allowed:
		if guard_result.reason == "natural_finish":
			_finish_with_message(response)
		else:
			_finish_with_message(response + "\n\n" + guard_result.reason)
		return

	if not guard_result.warning.is_empty():
		_memory.add_agent_thought(guard_result.warning)

	var correction: String = guard_result.get("correction", "")

	if tool_calls.is_empty():
		var hallucinated_tool := _detect_hallucinated_tool(response)
		if not hallucinated_tool.is_empty():
			var err_msg := "⚠️ SYSTEM ERROR: Invalid tool format detected. You mentioned '%s' but failed to use the mandatory XML tags. \n\nCRITICAL: You MUST use the format: <%s key=\"value\" />\nExample: <read_file path=\"res://main.gd\" />\n\nPlease retry with the correct format." % [hallucinated_tool, hallucinated_tool]
			_memory.add_agent_thought(err_msg)
			agent_thinking.emit(err_msg)
			_send_to_ai(err_msg, false)
			return

		if not correction.is_empty():
			_memory.add_agent_thought(correction)
			agent_thinking.emit(correction)
			_send_to_ai(correction, false)
			return

		_finish_with_message(response)
		return

	var was_fuzzy := not response.contains("<") or not response.contains(">")

	_set_state(State.EXECUTING)

	var dirty_files := _get_dirty_files(tool_calls)
	if not dirty_files.is_empty():
		if _git_available:
			var msg := "⚠️ The following files have uncommitted changes: %s. Please commit them using <git command=\"commit\" args=\"-m '...'\" /> before modifying them further to ensure you can revert if needed." % ", ".join(dirty_files)
			_memory.add_agent_thought(msg)
			agent_thinking.emit(msg)
		else:
			var backups := []
			for file in dirty_files:
				var backup_path = _damage_repair.get_rollback_manager().create_backup(file)
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

		var perm := _permissions.check(tool_name, args)
		if perm.needs_confirmation:
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

		if not perm.message.is_empty():
			tool_executed.emit(tool_name, args, {}, perm.message)

		step_started.emit(_loop_engine.get_iteration(), "🔧 %s" % tool_name)
		status_changed.emit(state, "Running " + tool_name + "...")

		var result: Dictionary = {}
		if _tools and _permissions:
			# Create backup before destructive operations
			if tool_name in ["write_file", "patch_file", "delete_file"] and not args.get("path", "").is_empty():
				_damage_repair.get_rollback_manager().create_backup(args.path)

			result = _tools.execute_tool(tool_name, args)

			# Damage repair: if error occurred, attempt auto-repair
			if result.has("error"):
				var repair_result: Dictionary = _damage_repair.diagnose_and_repair(tool_name, args, result.error, _tools.get_editor_integration())
				if repair_result.repaired:
					var corrected_args: Dictionary = repair_result.get("corrected_args", {})
					if not corrected_args.is_empty():
						result = _tools.execute_tool(tool_name, corrected_args)
						if not result.has("error"):
							_memory.add_agent_thought("Auto-repair succeeded: " + repair_result.message)
							agent_thinking.emit("🛠️ Auto-repair: %s" % repair_result.message)
					else:
						_memory.add_agent_thought("Repair note: " + repair_result.message)

			# Post-execute syntax validation for GDScript files
			if not result.has("error") and tool_name in ["write_file", "patch_file"]:
				var val_result: Dictionary = _damage_repair.post_execute_validation(tool_name, args, _tools.get_editor_integration())
				if not val_result.valid:
					_memory.add_agent_thought("⚠️ Syntax issues detected in %s:\n%s" % [args.get("path", ""), val_result.issues])
					agent_thinking.emit("⚠️ Syntax warnings in written file")
		else:
			result = {"error": "Tool system unavailable"}

		if _api_manager and _api_manager.is_inside_tree():
			await _api_manager.get_tree().process_frame

		_memory.add_tool_result(tool_name, args, result)
		var result_str := _tools.format_result_for_prompt(tool_name, args, result)

		if was_fuzzy:
			result_str = "⚠️ FORMATTING WARNING: Your last call used a non-XML format. The system recovered it using fuzzy parsing, but you MUST use valid XML <tool_name key=\"value\" /> going forward.\n" + result_str

		tool_results.append(result_str)

		if state == State.IDLE:
			return

	_last_results_hash = str("|".join(tool_results).hash())

	_set_state(State.WAITING_RESPONSE)
	var feedback := "Tool Results:\n" + "\n---\n".join(tool_results)

	# Inject loop engine correction message if present
	if not correction.is_empty():
		feedback = correction + "\n\n" + feedback

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
		if current_mode == "assistant":
			# Lightweight context for the conversational assistant agent
			var AssistantPersonaClass = preload("res://addons/ai_coding_assistant/persona/assistant_persona.gd")
			context = AssistantPersonaClass.get_prompt()
			context += "\n\n" + _tools.get_tool_schemas()
			context += "\n\n" + _ctx.build_quick_context()
		else:
			# Full autonomous agent context
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

	# Auto-commit if git is available and user hasn't disabled it
	if auto_commit and _git_available and not _user_disabled_commit() and not _task.is_empty():
		_auto_commit()

	agent_finished.emit(response)
	_set_state(State.IDLE)

## Check if the user has explicitly disabled auto-commit for this task
func _user_disabled_commit() -> bool:
	var task_lower = _task.to_lower()
	var disable_keywords = ["don't commit", "dont commit", "no git", "no commit",
							"skip commit", "without commit", "no version control"]
	for kw in disable_keywords:
		if task_lower.contains(kw):
			return true
	return false

## Perform the auto-commit after task completion
func _auto_commit() -> void:
	var task_short = _task.strip_edges().left(60).replace("'", "")
	if task_short.is_empty():
		task_short = "agent task"

	# Build commit message with co-author trailer
	var commit_msg = "feat: %s\n\n%s" % [task_short, CO_AUTHOR]

	# Stage all changes
	var add_out: Array[String] = []
	OS.execute("git", ["add", "-A"], add_out, true)

	# Check if there's anything to commit
	var status_out: Array[String] = []
	OS.execute("git", ["status", "--porcelain"], status_out, true)
	var has_changes = not status_out.is_empty() and not status_out[0].strip_edges().is_empty()

	if not has_changes:
		# Nothing to commit — silently skip
		return

	# Commit
	var commit_out: Array[String] = []
	var exit_code = OS.execute("git", ["commit", "-m", commit_msg], commit_out, true)

	if exit_code == 0:
		agent_thinking.emit("✅ Git commit: '%s'" % task_short)
	else:
		agent_thinking.emit("⚠️ Git commit failed (exit %d). Check git config." % exit_code)

func _force_stop(reason: String) -> void:
	if _is_stopping:
		return
	_is_stopping = true
	_loop_engine.force_abort(reason)
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
