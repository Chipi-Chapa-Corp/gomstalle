extends CharacterBody3D

var inventory_wood_label: Label = Label.new()

func _init() -> void:
	add_child(inventory_wood_label)

func is_multiplayer_authority() -> bool:
	return true
