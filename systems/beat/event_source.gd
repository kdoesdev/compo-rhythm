extends Node3D

class_name EventSource

# an event source will send out BeatEvent(s) to be responded to by the player or world

var events : Array[BeatEvent]

var status : RuleSet.WindowStatus

var is_active : bool = false

var is_ready : bool = false

@export var combo : BeatCombo

@export var mesh : MeshInstance3D

signal finished

func _ready() -> void:
	process_mode = PROCESS_MODE_DISABLED

func init(spec : EventEntitySpec):
	combo = spec.combo
	is_ready = true
	process_mode = PROCESS_MODE_INHERIT

func process_beat_event(event : BeatEvent, result : RuleSet.EventResult):
	print("processing beat event, result: ",  RuleSet.EventResult.keys()[result])
	events.erase(event)
	if events.is_empty() && result != RuleSet.EventResult.MISSED:
		finished.emit()
	
func process_status_update(_event : BeatEvent, new_status: RuleSet.WindowStatus):
	var color := RuleSet.timing_feedback_color[new_status]
	var material := mesh.get_active_material(0)
	if material is StandardMaterial3D:
		material.albedo_color = color
		
func queue_events():

	if !is_ready:
		return

	var notes : Array[Variant]
	var time : float = -1
	
	if combo:
		notes = _get_notes_from_combo()
		time = _get_next_beat()
		
		# in case of bad starting delta
		notes[0]['delta'] = 0
	else:
		notes = _get_notes_from_midi()
	
	for note in notes:
		time = note["time"] if note.has('time') else time + (note['delta'] / 1000)
		var event : BeatEvent = Conductor.add_event_to_track(time, note)
		assert(event)
		
		event.result.connect(process_beat_event)
		event.update.connect(process_status_update)
		events.append(event)
	is_active = true

func _get_notes_from_combo():
		return combo.get_notes()

func _get_notes_from_midi() -> Array[Variant]:
	var next_beat : float = _get_next_beat()
	
	var notes : Array[Variant] = Conductor.get_notes_in_range(next_beat, next_beat + 20)
	notes = get_combo_from_main_midi(notes)
	return notes

func get_combo_from_main_midi(notes : Array[Variant]) -> Array[Variant]:
	var found_combo_start : bool = false
	var found_combo : Array[Variant]
	for note in notes:
		if note['subtype'] != MIDI_MESSAGE_NOTE_ON:
			if found_combo_start && note['note'] == 0:
				break # end of combo reached
			continue
		
		if !found_combo_start:
			if note['note'] != 0:
				continue
			found_combo_start = true
			continue
			
		if note['note'] == 0:
			continue
		
		found_combo.append(note)
	return found_combo
	
func _get_next_beat() -> float:
	var current_beat : float = Conductor.get_current_time() * Conductor.bpm / 60
	var next_beat : float = Conductor.get_current_time() + (4 - fmod(current_beat, 4)) * 60 / Conductor.bpm
	return next_beat
