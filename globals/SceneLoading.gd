extends CanvasLayer

func _ready() -> void:
	layer = 100
	visible = false
	var background := ColorRect.new()
	background.color = Color("211a15")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(CastleTheme.label(tr("Loading…"), 42, CastleTheme.GOLD, true))
