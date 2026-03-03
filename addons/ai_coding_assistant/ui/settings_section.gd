@tool
extends VBoxContainer
class_name AISettingsSection

signal provider_changed(provider: String)
signal model_changed(model: String)
signal api_key_changed(key: String)

var provider_option: OptionButton
var model_field: LineEdit
var api_key_field: LineEdit

func _ready():
	_setup_ui()

func _setup_ui():
	var settings_content = VBoxContainer.new()
	
	# Provider selection
	var provider_hbox = HBoxContainer.new()
	var provider_label = Label.new()
	provider_label.text = "Provider:"
	provider_label.custom_minimum_size = Vector2(80, 0)
	
	provider_option = OptionButton.new()
	provider_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	provider_option.item_selected.connect(_on_provider_selected)
	
	provider_hbox.add_child(provider_label)
	provider_hbox.add_child(provider_option)
	settings_content.add_child(provider_hbox)

	# Model input
	var model_hbox = HBoxContainer.new()
	var model_label = Label.new()
	model_label.text = "Model:"
	model_label.custom_minimum_size = Vector2(80, 0)
	
	model_field = LineEdit.new()
	model_field.placeholder_text = "e.g. gpt-4o, gemini-1.5-pro, etc."
	model_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_field.text_changed.connect(_on_model_changed)
	
	model_hbox.add_child(model_label)
	model_hbox.add_child(model_field)
	settings_content.add_child(model_hbox)

	# API Key
	var api_key_hbox = HBoxContainer.new()
	var api_key_label = Label.new()
	api_key_label.text = "API Key:"
	api_key_label.custom_minimum_size = Vector2(80, 0)
	
	api_key_field = LineEdit.new()
	api_key_field.secret = true
	api_key_field.placeholder_text = "Enter API Key"
	api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	api_key_field.text_changed.connect(_on_api_key_changed)
	
	api_key_hbox.add_child(api_key_label)
	api_key_hbox.add_child(api_key_field)
	settings_content.add_child(api_key_hbox)

	add_child(settings_content)

func setup_providers(providers: Array):
	provider_option.clear()
	for p in providers:
		provider_option.add_item(p.capitalize())

func set_model(model: String):
	model_field.text = model

func set_api_key(key: String):
	api_key_field.text = key

func _on_provider_selected(index: int):
	provider_changed.emit(provider_option.get_item_text(index).to_lower())

func _on_model_changed(text: String):
	model_changed.emit(text)

func _on_api_key_changed(text: String):
	api_key_changed.emit(text)
