extends EventSource

@export var wait_time : float = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(wait_time).timeout
	if Conductor.get_state() == 0:
		queue_events()
	else: Conductor.song_started.connect(queue_events)
	
func process_beat_event(event : BeatEvent, result : RuleSet.EventResult):
	super(event, result)
	if events.is_empty():
		queue_free()
