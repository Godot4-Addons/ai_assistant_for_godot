@tool
extends EditorPlugin

var dock

func _enter_tree():
	# Load and create the dock
	var dock_script = load("res://addons/ai_coding_assistant/ai_assistant_dock.gd")
	dock = dock_script.new()

	# Pass the EditorInterface to the dock
	dock.set_editor_interface(get_editor_interface())

	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

	print("AI Coding Assistant plugin enabled")

func _exit_tree():
	# Clean up
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()

	print("AI Coding Assistant plugin disabled")

func get_plugin_name():
	return "AI Coding Assistant"
