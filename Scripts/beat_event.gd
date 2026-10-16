extends Resource

class_name BeatEvent

signal result(event : BeatEvent, result : RuleSet.EventResult)
signal update(event : BeatEvent, status : RuleSet.WindowStatus)

# The when of this events validity, in practice it is this +- the timing window
var time : float = -1
var spec : BeatEventSpec = null
var note : Variant

static func create(time : float, note : Variant) -> BeatEvent:
	var instance : BeatEvent = BeatEvent.new()
	instance.time = time
	instance.note = note
	return instance
	
class event_spec:
	var is_vulnerable : bool = false
