extends Node3D

class_name EntitySpawner

@export var section_cached : int

# [section, entities]
@export var spawn_spec : Dictionary[int, EntitySpawnSpec]

var spawned_entities : Array[EventSource]

var SPAWNED_INDEX_START : int = -1
var spawned_index : int = SPAWNED_INDEX_START


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	section_cached = Conductor.get_section_idx()
	Conductor.section_changed.connect(new_section)

	await get_tree().create_timer(1.0).timeout

	assert(!spawn_spec.is_empty())

	if spawn_spec.is_empty():
		return

	_spawn_next()


func _spawn_next():

	if !spawn_spec.has(section_cached):
		return
	
	var section_entities : EntitySpawnSpec = spawn_spec[section_cached]

	if section_entities.entity_specs.size() <= spawned_index + 1:
		return

	spawned_index += 1
	var entity_specs : Array[EventEntitySpec] = section_entities.entity_specs
	var entity_spec : EventEntitySpec = entity_specs[spawned_index]
	var instance : EventSource = entity_spec.entity.instantiate()
	add_child(instance)
	instance.init(entity_spec)
	instance.global_position = global_position

	spawned_entities.append(instance)
	instance.finished.connect(_spawn_next)

func on_entity_finished(entity : EventSource):
	spawned_entities.erase(entity)

func new_section(section : String, index : int):
	spawned_entities.clear()
	section_cached = index
	spawned_index = SPAWNED_INDEX_START
	_spawn_next()
