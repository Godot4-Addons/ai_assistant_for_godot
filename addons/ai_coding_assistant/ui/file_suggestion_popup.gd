@tool
extends PanelContainer

signal file_selected(path: String)

var item_list: ItemList
var _all_files: Array = []
var _filtered_files: Array = []

func _init() -> void:
	custom_minimum_size = Vector2(300, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.3, 0.5, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)
	
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("v_separation", 4)
	item_list.item_activated.connect(_on_item_activated)
	add_child(item_list)

func _ready() -> void:
	hide()

func set_files(files: Array) -> void:
	_all_files = files
	_filter_files("")

func _filter_files(filter: String) -> void:
	item_list.clear()
	_filtered_files = []
	
	for file_path in _all_files:
		if filter.is_empty() or file_path.to_lower().contains(filter.to_lower()):
			_filtered_files.append(file_path)
			var icon_name = "GDScript" if file_path.ends_with(".gd") else "File"
			item_list.add_item(file_path.get_file())
			var idx = item_list.get_item_count() - 1
			item_list.set_item_tooltip(idx, file_path)
	
	if item_list.get_item_count() > 0:
		item_list.select(0)

func update_filter(filter: String) -> void:
	_filter_files(filter)

func _on_item_activated(idx: int) -> void:
	file_selected.emit(_filtered_files[idx])
	hide()

func select_current() -> void:
	var selected = item_list.get_selected_items()
	if selected.size() > 0:
		_on_item_activated(selected[0])

func move_selection(dir: int) -> void:
	var selected = item_list.get_selected_items()
	var current = selected[0] if selected.size() > 0 else -1
	var next = posmod(current + dir, item_list.get_item_count())
	item_list.select(next)
	item_list.ensure_current_is_visible()
