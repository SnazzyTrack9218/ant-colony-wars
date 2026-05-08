extends RefCounted
class_name ColonyUITheme

const BG_DARK: Color = Color(0.043, 0.043, 0.059, 1.0)
const PANEL_SURFACE: Color = Color(0.071, 0.071, 0.110, 0.94)
const PANEL_SURFACE_HOVER: Color = Color(0.110, 0.110, 0.160, 1.0)
const PANEL_SURFACE_PRESSED: Color = Color(0.180, 0.125, 0.070, 1.0)
const PANEL_EDGE: Color = Color(0.165, 0.165, 0.247, 1.0)
const TEXT_PRIMARY: Color = Color(0.910, 0.910, 0.960, 1.0)
const TEXT_MUTED: Color = Color(0.353, 0.353, 0.447, 1.0)
const ACCENT_AMBER: Color = Color(1.000, 0.584, 0.125, 1.0)
const ACCENT_BLUE: Color = Color(0.290, 0.624, 1.000, 1.0)
const ACCENT_RED: Color = Color(1.000, 0.251, 0.251, 1.0)
const ACCENT_PURPLE: Color = Color(0.627, 0.439, 1.000, 1.0)
const SHADE: Color = Color(0.0, 0.0, 0.0, 0.78)

const FONT_MUTED: int = 11
const FONT_PRIMARY: int = 13
const FONT_HEADER: int = 16
const FONT_TITLE: int = 32


static func priority_color(level: String) -> Color:
	match level:
		"low":
			return TEXT_MUTED
		"normal":
			return TEXT_PRIMARY
		"high":
			return ACCENT_AMBER
		"emergency":
			return ACCENT_RED
	return TEXT_MUTED


static func panel_style(radius: int = 4, shadow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_SURFACE
	style.border_color = PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	if shadow:
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 18
	return style


static func button_style(fill: Color = PANEL_SURFACE, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


static func marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ACCENT_AMBER.r, ACCENT_AMBER.g, ACCENT_AMBER.b, 0.04)
	style.border_color = Color(ACCENT_AMBER.r, ACCENT_AMBER.g, ACCENT_AMBER.b, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	return style


static func style_button(button: BaseButton) -> void:
	button.add_theme_stylebox_override("normal", button_style(PANEL_SURFACE))
	button.add_theme_stylebox_override("hover", button_style(PANEL_SURFACE_HOVER))
	button.add_theme_stylebox_override("pressed", button_style(PANEL_SURFACE_PRESSED))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", ACCENT_AMBER)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_font_size_override("font_size", FONT_PRIMARY)


static func style_label(label: Label, color: Color = TEXT_PRIMARY, size: int = FONT_PRIMARY) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
