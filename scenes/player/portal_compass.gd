class_name PortalCompass
extends Control

class Placement:
	var position: Vector2
	var direction: Vector2
	var on_screen: bool

var marker := Placement.new()
var distance_metres := 0
var font := ThemeDB.fallback_font
var plate := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.bg_color = Color(0.02, 0.055, 0.07, 0.86)
	plate.set_corner_radius_all(9)
	plate.set_border_width_all(1)
	plate.border_color = Color(0.48, 0.76, 0.68, 0.6)

static func place_projection(projection: Vector2, viewport: Vector2, behind: bool) -> Placement:
	var result := Placement.new()
	var center := viewport * 0.5
	var safe_area := Rect2(Vector2(82, 160), viewport - Vector2(164, 360))
	var desired_position := projection + Vector2(0, -48)
	var offset := projection - center
	if behind:
		offset = -offset
	if offset.is_zero_approx():
		offset = Vector2.DOWN if behind else Vector2.UP
	result.direction = offset.normalized()
	result.on_screen = not behind and safe_area.has_point(desired_position)
	if result.on_screen:
		result.position = desired_position
	else:
		var bounds := Vector2(center.x - safe_area.position.x, safe_area.end.y - center.y if offset.y > 0 else center.y - safe_area.position.y)
		var edge_scale := minf(bounds.x / maxf(absf(offset.x), 0.001), bounds.y / maxf(absf(offset.y), 0.001))
		result.position = center + offset * edge_scale
	return result

func update_guidance(portal: Vector3, player: Vector3, camera: Camera3D) -> void:
	marker = place_projection(camera.unproject_position(portal + Vector3.UP * 0.8), get_viewport().get_visible_rect().size, camera.is_position_behind(portal))
	distance_metres = ceili(Vector2(portal.x - player.x, portal.z - player.z).length())
	visible = distance_metres > 2
	queue_redraw()

func _draw() -> void:
	var location := marker.position
	var mint := Color("a3f3d7")
	draw_circle(location, 22, Color(0.025, 0.075, 0.085, 0.9))
	draw_arc(location, 18, 0, TAU, 48, Color("748e85"), 1.5, true)
	var diamond := PackedVector2Array([location + Vector2(0, -11), location + Vector2(8, 0), location + Vector2(0, 11), location + Vector2(-8, 0), location + Vector2(0, -11)])
	draw_polyline(diamond, mint, 2.0, true)
	draw_circle(location, 2.0, Color("e9ddb2"))
	if not marker.on_screen:
		var tangent := marker.direction.orthogonal()
		var tip := location + marker.direction * 33
		var back := location + marker.direction * 25
		draw_polyline(PackedVector2Array([back + tangent * 6, tip, back - tangent * 6]), mint, 2.5, true)
	var text := tr("ESCAPE") + "  ·  %d m" % distance_metres
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	var text_rect := Rect2(location + Vector2(-text_size.x * 0.5 - 10, 42), Vector2(text_size.x + 20, 30))
	draw_style_box(plate, text_rect)
	draw_string(font, text_rect.position + Vector2(10, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("daece0"))
