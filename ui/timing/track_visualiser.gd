extends Control

@export var visual_template : PackedScene = null

@onready var track : Control = $Track/Beats

var events : Dictionary[BeatEvent, BeatEventVisual]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Conductor.event_added.connect(visulise_event)
	
	# in case there are already events
	for event in Conductor.get_queued_events().keys():
		visulise_event(event)
		
func _process(delta: float) -> void:
	for event in events:
		var time_diff : float = Conductor.get_time_diff_ms(event.time)
		var visual := events.get(event) as BeatEventVisual

		visual.set_position(Vector2(time_diff/10, visual.position.y))

func visulise_event(event : BeatEvent):
	event.result.connect(show_result)
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
	
func show_result(event : BeatEvent, result : RuleSet.EventResult):
	var event_visual : BeatEventVisual = events.get(event)
	event_visual.show_result(result)
	await get_tree().create_timer(2).timeout
	events.erase(event)
	event_visual.queue_free()
	pass
