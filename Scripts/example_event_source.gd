extends EventSource

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(2).timeout
	if Conductor.get_state() == 0:
		queue_events()
	else: Conductor.song_started.connect(queue_events)
	
func process_beat_event(event : BeatEvent, result : RuleSet.EventResult):
	super(event, result)
	if events.is_empty():
		queue_free()
