extends ColorRect
class_name CardVisual

@export var valueLabels: Array[Label] = []

func _ready() -> void:
	material = material.duplicate()
	for label in valueLabels:
		label.label_settings = valueLabels[0].label_settings.duplicate()
