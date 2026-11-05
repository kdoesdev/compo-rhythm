@tool
extends Node3D

@export var nodes : Array[Node3D]

@export var speed : float = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for node in nodes:
		
		node.global_position = node.global_position.lerp(global_position, delta * speed)
	pass
