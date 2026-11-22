extends Control

@export var visual_template : PackedScene = null

@onready var track : Control = $Track/Beats

var events : Dictionary[BeatEvent, BeatEventVisual]
var finished_events : Dictionary[BeatEvent, BeatEventVisual]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Conductor.event_added.connect(visulise_event)
	Conductor.time_changed.connect(update_time)
	
	# in case there are already events
	for timing in Conductor.get_queued_events().values():
		for event in timing.events:
			visulise_event(event)
		
func _process(delta: float) -> void:
	for event in events:
		var visual := events.get(event) as BeatEventVisual
		update_position(event, visual)
	
	for finished_event in finished_events:
		var visual := finished_events.get(finished_event) as BeatEventVisual
		update_position(finished_event, visual)

func visulise_event(event : BeatEvent):
	event.result.connect(show_result)
	event.update.connect(show_status)
	var event_visual : BeatEventVisual = visual_template.instantiate()
	track.add_child(event_visual)
	event_visual.anchor_left = 0.5
	event_visual.anchor_right = 0.5
	event_visual.anchor_top = 0.5
	event_visual.anchor_bottom = 0.5
	event_visual.offset_left = 0
	event_visual.offset_top = 0
	event_visual.offset_right = 0
	event_visual.offset_bottom = 0
	events.get_or_add(event, event_visual)
	pass

func update_position(event : BeatEvent, visual : BeatEventVisual):
	var time_diff : float = Conductor.get_time_diff_ms(event.time)
	visual.set_position(Vector2(time_diff/10, visual.position.y))

func show_status(event : BeatEvent, status : RuleSet.WindowStatus):
	var event_visual : BeatEventVisual = events.get(event)
	event_visual.show_status(status)

func show_result(event : BeatEvent, result : RuleSet.EventResult):
	var event_visual : BeatEventVisual = events.get(event)
	event_visual.show_result(result)
	events.erase(event)
	finished_events.get_or_add(event, event_visual)
	await get_tree().create_timer(2).timeout
	finished_events.erase(event)
	event_visual.queue_free()

func update_time(new_time : float, delta : float):
	for event in finished_events:
		event.time += delta
