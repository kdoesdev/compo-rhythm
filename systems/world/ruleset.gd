extends Node

enum EventResult {PERFECT, GOOD, MISSED, MAX}
enum WindowStatus {APPROACHING, OPEN, CLOSED}

const window_approaching_ms : float = 500
const window_open_ms : float = 150

@export var telegraph_curve : Curve = null
@export var telegraph_gradient : Gradient = null

var timing_windows_ms : Dictionary[float, EventResult] = {	
	35: EventResult.PERFECT,
	75: EventResult.GOOD,
	window_open_ms: EventResult.MISSED
}

var timing_feedback_color : Dictionary [WindowStatus, Color] = {
	WindowStatus.APPROACHING : Color.ORANGE,
	WindowStatus.OPEN : Color.GREEN,
	WindowStatus.CLOSED : Color.BLACK
}
