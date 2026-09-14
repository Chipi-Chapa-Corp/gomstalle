extends Sprite3D

@export var scale_to: float = 1.0
@export var duration_in: float = 0.2
@export var duration_out: float = 0.2
@export var duration_out_delay: float = 0.3

func _ready():
	texture = preload("res://assets/static/stun_sparks.svg")
	position.y = 2.5
	reset()

func play():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * scale_to, duration_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, duration_in)
	tween.tween_property(self, "modulate:a", 0.0, duration_out).set_delay(duration_out_delay)
	tween.finished.connect(reset)

func reset():
	scale = Vector3.ZERO
	modulate.a = 0.0
