extends Control

class_name BeatEventVisual

@onready var visual := $TextureRect

var status_color : Dictionary[RuleSet.WindowStatus, Color] = {
	RuleSet.WindowStatus.APPROACHING : Color.BLACK,
	RuleSet.WindowStatus.OPEN : Color.ORANGE,
	RuleSet.WindowStatus.CLOSED : Color.BLACK # should show result color instead
}

var result_color : Dictionary[RuleSet.EventResult, Color] =  {
	RuleSet.EventResult.PERFECT : Color.GREEN,
	RuleSet.EventResult.GOOD : Color.DARK_GREEN,
	RuleSet.EventResult.MISSED : Color.RED
	}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func show_status(status : RuleSet.WindowStatus):
	modulate = status_color.get(status)

func show_result(result : RuleSet.EventResult):
	modulate = result_color.get(result)
