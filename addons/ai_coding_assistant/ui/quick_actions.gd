@tool
extends VBoxContainer
class_name AIQuickActions

signal action_triggered(type: String)

func _ready():
	_setup_ui()

func _setup_ui():
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_add_action_button(grid, "🖥️ UI Controller", "generate_ui")
	_add_action_button(grid, "💾 Save System", "generate_save")
	_add_action_button(grid, "🔊 Audio Manager", "generate_audio")
	_add_action_button(grid, "🎮 Player Controller", "generate_player")
	_add_action_button(grid, "👾 Enemy AI", "generate_enemy")
	_add_action_button(grid, "📝 Unit Tests", "generate_tests")
	
	add_child(grid)

func _add_action_button(parent: Container, text: String, action_id: String):
	var btn = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): action_triggered.emit(action_id))
	parent.add_child(btn)
