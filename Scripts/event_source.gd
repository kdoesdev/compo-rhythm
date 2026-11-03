extends Node

class_name EventSource

#TODO is this the best approach?

# an event source will send out BeatEvent(s) to be responded to by the player or world

# How long ahead a single entity can look ahead to source notes for their combo
@export var max_combo_duration : float = 4

var events : Dictionary[float, BeatEvent]

var status : RuleSet.WindowStatus

var is_active : bool = false

@export var mesh : MeshInstance3D

# the beats that are queued up
@export var beat_combo : int = 1
	
func process_beat_event(event : BeatEvent, result : RuleSet.EventResult):
	print("processing beat event, result: ",  RuleSet.EventResult.keys()[result])
	events.erase(event.time)
	
func process_status_update(_event : BeatEvent, new_status: RuleSet.WindowStatus):
	var color := RuleSet.timing_feedback_color[new_status]
	var material := mesh.get_active_material(0)
	if material is StandardMaterial3D:
		material.albedo_color = color

func queue_events():
	var current_beat : float = Conductor.get_current_time() * Conductor.bpm / 60
	var next_beat : float = Conductor.get_current_time() + (4 - fmod(current_beat, 4)) * 60 / Conductor.bpm
	
	var notes : Array[Variant] = Conductor.get_notes_in_range(next_beat, next_beat + 20)
	notes = notes.filter(func(variant): return variant['track'] == 1)

	var found_combo_start : bool = false
	var time : float = -1
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
		
		time = note['time']
		var event : BeatEvent = Conductor.add_event_to_track(time, note)
		if !event:
			#TODO: don't let this fail silently
			continue
		event.result.connect(process_beat_event)
		event.update.connect(process_status_update)
		events.get_or_add(event.time, event)
		
		is_active = true
