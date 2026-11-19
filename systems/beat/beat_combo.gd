extends Resource

class_name BeatCombo

@export var midi : MidiResource

func get_notes() -> Array[Variant]:

	assert(midi)

	var notes : Array[Variant]

	if !midi:
		return notes

	for event in midi.tracks[0]['events']:
		if event['type'] == 'note' && event['subtype'] == 8:
			notes.append(event)
	return notes
