extends Node3D

class_name EntitySpawner

@export var section : int

@export var entity_specs : Array[EventEntitySpec]

var spawned_entities : EventSource

var spawned_index : int = -1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	await get_tree().create_timer(1.0).timeout

	assert(!entity_specs.is_empty())

	if entity_specs.is_empty():
		return

	_spawn_next()


func _spawn_next():

	if entity_specs.size() <= spawned_index + 1:
		return

	spawned_index += 1

	var entity_spec = entity_specs[spawned_index]
	var instance : EventSource = entity_spec.entity.instantiate()
	add_child(instance)
	instance.init(entity_spec)
	instance.global_position = global_position

	instance.finished.connect(_spawn_next)

	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
