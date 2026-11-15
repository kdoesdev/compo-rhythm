extends Resource

class_name BeatEventSpec

# how long after the last event does this one occur
@export var delta : float = 1

# does event need to be held for a duration?
@export var is_hold : bool = false

# how long to hold for, NOTE: adds to the delta of the next event
@export var hold_duration : float = 0
