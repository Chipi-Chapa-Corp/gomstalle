extends Sprite3D

@export var scale_to: float = 1.0
@export var duration_in: float = 0.2
@export var duration_out: float = 0.2
@export var duration_out_delay: float = 0.3
@export var offset_max: float = 1.5

var random := RandomNumberGenerator.new()

var textures = [
	preload("res://assets/effects/boom.png"),
	preload("res://assets/effects/crack.png"),
	preload("res://assets/effects/pow.png")
]

func _ready():
	random.randomize()
	reset()

func play():
	texture = textures[random.randi_range(0, textures.size() - 1)]

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * scale_to, duration_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, duration_in)
	tween.tween_property(self, "modulate:a", 0.0, duration_out).set_delay(duration_out_delay)
	tween.finished.connect(reset)

func reset():
	scale = Vector3.ZERO
	modulate.a = 0.0
