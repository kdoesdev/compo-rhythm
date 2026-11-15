extends Node

@onready var fps_label : Label = $FpsTxt

func _process(delta: float) -> void:
	fps_label.text = "FPS: " + str(1 / delta)
