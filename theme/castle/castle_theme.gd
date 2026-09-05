class_name CastleTheme
extends RefCounted

const INK := Color("261a15")
const PANEL := Color("fff4df")
const BORDER := Color("382418")
const GOLD := Color("eba400")
const PAPER := Color("fff4df")
const MUTED := Color("745a40")
const MINT := Color("8db455")
const DANGER := Color("ca6046")
const DISPLAY_FONT := preload("res://assets/fonts/MedievalSharp-Regular.ttf")
const PLATE := preload("res://assets/static/plate.png")
const BASE_THEME := preload("res://theme/theme.tres")

static func create() -> Theme:
	var result := BASE_THEME.duplicate(true) as Theme
	result.default_font = DISPLAY_FONT
	result.default_font_size = 24
	result.set_color("font_color", "Label", INK)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		result.set_color(color_name, "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("433628"))
	result.set_constant("outline_size", "Button", 0)
	result.set_stylebox("normal", "Button", button_style(GOLD))
	result.set_stylebox("hover", "Button", button_style(Color("f4bc39")))
	result.set_stylebox("pressed", "Button", button_style(Color("bd801c"), true))
	result.set_stylebox("disabled", "Button", button_style(Color("877153")))
	result.set_stylebox("focus", "Button", panel(Color.TRANSPARENT, PAPER, 0, 0, 2))
	result.set_stylebox("panel", "PanelContainer", parchment())
	result.set_stylebox("normal", "LineEdit", panel(Color("fffaf0"), MUTED, 14, 10, 2))
	result.set_stylebox("focus", "LineEdit", panel(Color("fffaf0"), GOLD, 14, 10, 3))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", INK)
	result.set_color("font_color", "CheckButton", INK)
	result.set_color("font_hover_color", "CheckButton", INK)
	result.set_stylebox("background", "ProgressBar", panel(Color("6d4e33"), INK, 0, 0, 2))
	result.set_stylebox("fill", "ProgressBar", panel(MINT, INK, 0, 0, 2))
	result.set_stylebox("slider", "HSlider", panel(Color("ae8c5d"), INK, 0, 4, 2))
	result.set_stylebox("grabber_area", "HSlider", panel(GOLD, INK, 0, 4, 2))
	result.set_stylebox("grabber_area_highlight", "HSlider", panel(GOLD.lightened(0.15), INK, 0, 4, 2))
	result.set_constant("separation", "VBoxContainer", 14)
	result.set_constant("separation", "HBoxContainer", 14)
	return result

static func panel(fill: Color, outline: Color, horizontal: int = 18, vertical: int = 12, border: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(border)
	style.set_corner_radius_all(8)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

static func button_style(fill: Color, pressed: bool = false) -> StyleBoxFlat:
	var style := panel(fill, INK, 20, 12)
	style.border_width_bottom = 3 if pressed else 7
	style.content_margin_top = 15 if pressed else 11
	style.content_margin_bottom = 9 if pressed else 13
	return style

static func parchment(horizontal: int = 30, vertical: int = 24) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PLATE
	style.texture_margin_left = 28
	style.texture_margin_right = 36
	style.texture_margin_top = 22
	style.texture_margin_bottom = 16
	style.content_margin_left = maxi(horizontal + 8, 38)
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

static func label(value: String, font_size: int = 24, color: Color = INK, display: bool = false) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_override("font", DISPLAY_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if display:
		result.add_theme_color_override("font_outline_color", INK)
		result.add_theme_constant_override("outline_size", 5)
	return result

static func button(value: String, callback: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 58
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	if primary:
		result.custom_minimum_size.y = 66
		result.add_theme_font_size_override("font_size", 30)
	return result

static func full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func paragraph(value: String, font_size: int = 22, color: Color = MUTED) -> Label:
	var result := label(value, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result
