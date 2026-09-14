extends Control

var title_opacity := 0.0
var fade_opacity := 0.0
var show_controls := true
var cinematic := true
var title_font := preload("res://assets/fonts/MedievalSharp-Regular.ttf")
var detail_font := ThemeDB.fallback_font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var scale_factor := size.x / 1920.0
	if cinematic:
		var bar := size.y * 0.128
		draw_rect(Rect2(0, 0, size.x, bar), Color.BLACK)
		draw_rect(Rect2(0, size.y - bar, size.x, bar), Color.BLACK)
	if title_opacity > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.026, 0.035, title_opacity * 0.53))
		_centered("G Ö M S T Ä L L E", 98, size.y * 0.49, Color(0.93, 0.85, 0.63, title_opacity), title_font)
		_centered(tr("M I D N I G H T   I N   T H E   L I B R A R Y"), 22, size.y * 0.56, Color(0.69, 0.83, 0.81, title_opacity), detail_font)
		_centered(tr("A castle chase for 4–6 players."), 27, size.y * 0.64, Color(0.94, 0.89, 0.77, title_opacity), detail_font)
		var rule_y := size.y * 0.38
		draw_line(Vector2(size.x * 0.36, rule_y), Vector2(size.x * 0.64, rule_y), Color(0.7, 0.54, 0.26, title_opacity), scale_factor)
	if show_controls and cinematic:
		_centered(tr("TAB  ·  Step inside     /     R  ·  Replay     /     ESC  ·  Menu"), 19, size.y * 0.956, Color("84999e"), detail_font)
	if fade_opacity > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fade_opacity))

func _centered(text: String, font_size: int, baseline: float, color: Color, font: Font) -> void:
	var scaled_size := roundi(float(font_size) * size.x / 1920.0)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, color)
