@tool
class_name MarkdownLabel
extends RichTextLabel
## A control for displaying Markdown-style text.
##
## A custom node that extends [RichTextLabel] to use Markdown instead of BBCode.
## Delegated to AIMarkdownParser for actual conversion.

# ─────────────────────────────────────────────────────────────────────────────
# Signals
# ─────────────────────────────────────────────────────────────────────────────

## Emitted when the node does not handle a click on a link.
signal unhandled_link_clicked(meta: Variant)
## Emitted when a task list checkbox is clicked.
signal task_checkbox_clicked(id: int, line: int, checked: bool, task_string: String)

# ─────────────────────────────────────────────────────────────────────────────
# Exports
# ─────────────────────────────────────────────────────────────────────────────

## The text to be displayed in Markdown format.
@export_multiline var markdown_text: String: set = _set_markdown_text

## If enabled, links will be automatically handled by this node.
@export var automatic_links := true
## If enabled, unrecognized links will be opened as HTTPS URLs.
@export var assume_https_links := true

@export_group("Header formats")
@export var h1 := H1Format.new(): set = _set_h1_format
@export var h2 := H2Format.new(): set = _set_h2_format
@export var h3 := H3Format.new(): set = _set_h3_format
@export var h4 := H4Format.new(): set = _set_h4_format
@export var h5 := H5Format.new(): set = _set_h5_format
@export var h6 := H6Format.new(): set = _set_h6_format

@export_group("Task lists")
@export var enable_checkbox_clicks := true: set = _set_enable_checkbox_clicks
@export var unchecked_item_character := "☐": set = _set_unchecked_item_character
@export var checked_item_character := "☑": set = _set_checked_item_character

@export_group("Horizontal rules", "hr_")
@export_range(0, 99, 1, "suffix:px") var hr_height: int = 2: set = _set_hr_height
@export_range(0, 100, 1, "suffix:%") var hr_width: float = 90: set = _set_hr_width
@export_enum("left", "center", "right") var hr_alignment: String = "center": set = _set_hr_alignment
@export var hr_color: Color = Color.WHITE: set = _set_hr_color

# ─────────────────────────────────────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────────────────────────────────────

var _dirty: bool = false
var _frontmatter := ""
var _parser: AIMarkdownParser = AIMarkdownParser.new()

const _FRONTMATTER_REGEX := r"^(?:(?:---|\+\+\+)\r?\n([\s\S]*?)\r?\n(?:---|\+\+\+)\r?\n)?(?:\r?\n)?([\s\S]*)$"
const _CHECKBOX_KEY := "markdownlabel-checkbox"

# ─────────────────────────────────────────────────────────────────────────────
# Built-in methods
# ─────────────────────────────────────────────────────────────────────────────

func _init(p_markdown_text: String = "") -> void:
	bbcode_enabled = true
	selection_enabled = true
	context_menu_enabled = true
	deselect_on_focus_loss_enabled = true
	# Smooth selection colors
	add_theme_color_override("selection_color", Color(0.23, 0.51, 0.96, 0.35)) # Soft blue highlight
	add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0, 1.0)) # White selected text
	markdown_text = p_markdown_text
	meta_clicked.connect(_on_meta_clicked)

func _ready() -> void:
	h1.changed.connect(queue_update)
	h2.changed.connect(queue_update)
	h3.changed.connect(queue_update)
	h4.changed.connect(queue_update)
	h5.changed.connect(queue_update)
	h6.changed.connect(queue_update)
	if Engine.is_editor_hint():
		bbcode_enabled = true

func _process(_delta: float) -> void:
	if _dirty:
		_update()

func _validate_property(property: Dictionary) -> void:
	if property.name == "bbcode_enabled":
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "text":
		property.usage = PROPERTY_USAGE_NONE

func _set(property: StringName, value: Variant) -> bool:
	if property == "text":
		_set_text(value)
		return true
	return false

func _get(property: StringName) -> Variant:
	if property == "text":
		return markdown_text
	return null

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_update()

# ─────────────────────────────────────────────────────────────────────────────
# Public methods
# ─────────────────────────────────────────────────────────────────────────────

func display_file(file_path: String, handle_frontmatter: bool = true) -> Error:
	var content: String = FileAccess.get_file_as_string(file_path)
	if not content:
		return FileAccess.get_open_error()
	
	if handle_frontmatter:
		var regex := RegEx.create_from_string(_FRONTMATTER_REGEX)
		var regex_match := regex.search(content)
		if regex_match:
			_frontmatter = regex_match.get_string(1).strip_edges()
			markdown_text = regex_match.get_string(2)
			return OK
	
	_frontmatter = ""
	markdown_text = content
	return OK

func get_frontmatter() -> String:
	return _frontmatter

func queue_update() -> void:
	_dirty = true
	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
# Private methods
# ─────────────────────────────────────────────────────────────────────────────

func _set_text(new_text: String) -> void:
	markdown_text = new_text
	queue_update()

func _set_markdown_text(new_text: String) -> void:
	markdown_text = new_text
	queue_update()

func _update() -> void:
	_dirty = false
	super.clear()
	
	# Sync parser configuration
	_parser.h1 = h1
	_parser.h2 = h2
	_parser.h3 = h3
	_parser.h4 = h4
	_parser.h5 = h5
	_parser.h6 = h6
	_parser.base_font_size = get_theme_font_size("normal_font_size")
	_parser.unchecked_item_character = unchecked_item_character
	_parser.checked_item_character = checked_item_character
	_parser.enable_checkbox_clicks = enable_checkbox_clicks
	_parser.hr_height = hr_height
	_parser.hr_width = hr_width
	_parser.hr_alignment = hr_alignment
	_parser.hr_color = hr_color
	
	var source = markdown_text
	if _can_auto_translate():
		source = TranslationServer.translate(source)
	
	var bbcode_text: String = _parser.parse(source)
	super.parse_bbcode(bbcode_text)

func _can_auto_translate() -> bool:
	var version := Engine.get_version_info()
	if version.hex >= 0x040300 and has_method("can_auto_translate"):
		return call("can_auto_translate")
	return auto_translate

# Helpers for synced exports
func _set_h1_format(v): h1 = v; queue_update()
func _set_h2_format(v): h2 = v; queue_update()
func _set_h3_format(v): h3 = v; queue_update()
func _set_h4_format(v): h4 = v; queue_update()
func _set_h5_format(v): h5 = v; queue_update()
func _set_h6_format(v): h6 = v; queue_update()
func _set_enable_checkbox_clicks(v): enable_checkbox_clicks = v; queue_update()
func _set_unchecked_item_character(v): unchecked_item_character = v; queue_update()
func _set_checked_item_character(v): checked_item_character = v; queue_update()
func _set_hr_height(v): hr_height = v; queue_update()
func _set_hr_width(v): hr_width = v; queue_update()
func _set_hr_alignment(v): hr_alignment = v; queue_update()
func _set_hr_color(v): hr_color = v; queue_update()

func _on_meta_clicked(meta: Variant) -> void:
	if typeof(meta) != TYPE_STRING:
		unhandled_link_clicked.emit(meta)
		return
	
	if meta.begins_with("{") and _CHECKBOX_KEY in meta:
		var parsed: Dictionary = JSON.parse_string(meta)
		if parsed[_CHECKBOX_KEY] and _parser.checkbox_record.has(int(parsed.id)):
			_on_checkbox_clicked(int(parsed.id), parsed.checked)
		return
	
	if not automatic_links:
		unhandled_link_clicked.emit(meta)
		return
		
	# Internal anchors (TODO: parser should expose anchors if we want this to work)
	# For now, handle URLs:
	if meta.begins_with("http") or meta.begins_with("ftp") or meta.contains("@"):
		OS.shell_open(meta)
	elif assume_https_links:
		OS.shell_open("https://" + meta)
	else:
		unhandled_link_clicked.emit(meta)

func _on_checkbox_clicked(id: int, was_checked: bool) -> void:
	var iline: int = _parser.checkbox_record[id]
	var lines := markdown_text.split("\n")
	var old_string := "[x]" if was_checked else "[ ]"
	var new_string := "[ ]" if was_checked else "[x]"
	var i := lines[iline].find(old_string)
	if i == -1: return
	
	lines[iline] = lines[iline].erase(i, old_string.length()).insert(i, new_string)
	markdown_text = "\n".join(lines)
	task_checkbox_clicked.emit(id, iline, !was_checked, lines[iline].substr(i + 4))
