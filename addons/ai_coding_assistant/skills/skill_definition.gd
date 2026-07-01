@tool
extends RefCounted
class_name SkillDefinition

var name: String
var description: String
var params: Dictionary
var template: String
var tags: Array[String]
var suggested_path_template: String = ""

func generate(user_params: Dictionary) -> String:
	var code := template
	var final_params := {}
	for p_name in params:
		final_params[p_name] = params[p_name].get("default", "")
	for p_name in user_params:
		final_params[p_name] = user_params[p_name]

	# Handle special params: STATES_ENUM, ENTER_CASES, EXIT_CASES, UPDATE_CASES
	if final_params.has("states") and typeof(final_params["states"]) == TYPE_ARRAY:
		var states: Array = final_params["states"]
		var enum_str := " ".join(states)
		var default_state := states[0].to_lower() if states.size() > 0 else "idle"
		var enter_cases: Array[String] = []
		var exit_cases: Array[String] = []
		var update_cases: Array[String] = []
		for s in states:
			var state_lower := s.to_lower()
			enter_cases.append("\t\tState.%s:\n\t\t\tpass" % state_lower)
			exit_cases.append("\t\tState.%s:\n\t\t\tpass" % state_lower)
			update_cases.append("\t\tState.%s:\n\t\t\tpass" % state_lower)
		final_params["STATES_ENUM"] = enum_str
		final_params["DEFAULT_STATE"] = default_state
		final_params["ENTER_CASES"] = "\n".join(enter_cases)
		final_params["EXIT_CASES"] = "\n".join(exit_cases)
		final_params["UPDATE_CASES"] = "\n".join(update_cases)

	# Handle tags param: join array into space-separated string
	if final_params.has("tags") and typeof(final_params["tags"]) == TYPE_ARRAY:
		final_params["TAGS"] = " ".join(final_params["tags"])

	for p_name in final_params:
		code = code.replace("{{%s}}" % p_name, str(final_params[p_name]))

	return code

func get_suggested_path(params: Dictionary) -> String:
	if not suggested_path_template.is_empty():
		var path := suggested_path_template
		for p_name in params:
			path = path.replace("{{%s}}" % p_name, str(params[p_name]))
		return path
	var class_n: String = params.get("class_name", name)
	return "res://scripts/%s.gd" % class_n
