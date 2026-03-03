@tool
extends RefCounted
class_name AIUITheme

# Colors - Modern Slate & Azure palette
const COLOR_BG_DARK = Color("#111827") # Slate 900
const COLOR_BG_MED = Color("#1f2937") # Slate 800
const COLOR_ACCENT = Color("#3b82f6") # Blue 500
const COLOR_ACCENT_SOFT = Color("#60a5fa") # Blue 400
const COLOR_SUCCESS = Color("#10b981") # Emerald 500
const COLOR_ERROR = Color("#ef4444") # Red 500
const COLOR_TEXT_DIM = Color("#9ca3af") # Slate 400
const COLOR_TEXT_BOLD = Color("#f3f4f6") # Slate 100
const COLOR_BG_MUTED = Color("#334155") # Slate 700
const COLOR_CODE_BG = Color("#0f172a") # Slate 950 (Darker for code)
const COLOR_QUOTE_BAR = Color("#475569") # Slate 600

# Syntax Highlighting
const COLOR_SYNTAX_KEYWORD = Color("#3b82f6") # Blue 500
const COLOR_SYNTAX_FUNCTION = Color("#60a5fa") # Blue 400
const COLOR_SYNTAX_STRING = Color("#eab308") # Yellow 500
const COLOR_SYNTAX_COMMENT = Color("#9ca3af") # Slate 400
const COLOR_SYNTAX_NUMBER = Color("#a855f7") # Purple 500
const COLOR_SYNTAX_MEMBER = Color("#10b981") # Emerald 500

# Spacing & Radii
const SPACING_MAIN = 12
const SPACING_SMALL = 6
const RADIUS_L = 8
const RADIUS_S = 4

# Icons (Godot Built-ins)
static func get_icon(name: String, control: Control) -> Texture2D:
	return control.get_theme_icon(name, "EditorIcons")

static func apply_card_style(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_MED
	style.corner_radius_top_left = RADIUS_L
	style.corner_radius_top_right = RADIUS_L
	style.corner_radius_bottom_left = RADIUS_L
	style.corner_radius_bottom_right = RADIUS_L
	style.content_margin_left = SPACING_MAIN
	style.content_margin_right = SPACING_MAIN
	style.content_margin_top = SPACING_MAIN
	style.content_margin_bottom = SPACING_MAIN
	panel.add_theme_stylebox_override("panel", style)

static func apply_code_panel_style(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_CODE_BG
	style.corner_radius_top_left = RADIUS_S
	style.corner_radius_top_right = RADIUS_S
	style.corner_radius_bottom_left = RADIUS_S
	style.corner_radius_bottom_right = RADIUS_S
	style.content_margin_left = SPACING_MAIN
	style.content_margin_right = SPACING_MAIN
	style.content_margin_top = SPACING_SMALL
	style.content_margin_bottom = SPACING_SMALL
	panel.add_theme_stylebox_override("panel", style)
