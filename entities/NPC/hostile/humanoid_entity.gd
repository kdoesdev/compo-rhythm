extends EventSource

@onready var move_speed : float = 3.8

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D

@export var path_update_rate : float = 0.5
@onready var time_since_last_path : float = path_update_rate

@onready var body : CharacterBody3D = $"."

## the time spent locked onto a target before an attack can occur
@export var lock_on_time : float = 1
var time_locked_on : float = 0

var is_alive : bool = true

var target : Node3D = null
var poi : Vector3

func _ready() -> void:
	poi = body.global_position
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 4

func _physics_process(delta: float) -> void:
	
	if !is_alive:
		return
	
	DebugDraw3D.draw_sphere(poi, 0.5, Color.YELLOW)
	
	look_at_target()
	if target:
		time_locked_on += delta
		if time_locked_on >= lock_on_time && events.is_empty():
			queue_events()
	else:
		time_locked_on = 0
	
	# unscale the time here so we still get responsive path updates
	time_since_last_path += delta
	if time_since_last_path >= path_update_rate:
		set_movement_target()
		time_since_last_path -= path_update_rate
	
	if !nav_agent.is_navigation_finished():
		var next_path_position: Vector3 = nav_agent.get_next_path_position()
		var new_velocity =  body.global_position.direction_to(next_path_position) * move_speed * delta * 60
		if nav_agent.avoidance_enabled:
			nav_agent.velocity = new_velocity
		else:
			on_velocity_computed(new_velocity)
	
	body.move_and_slide()

func set_movement_target():
	if target:
		poi = target.global_position
		nav_agent.set_target_position(poi)

func look_at_target():
	var pos : Vector3 = target.global_position if target else poi
	pos.y = body.global_position.y
	if pos == body.global_position:
		return
	body.look_at(pos)

func entity_sight_updated(entity: Node3D, can_see: bool):
	if !can_see:
		poi = entity.global_position
		nav_agent.target_desired_distance = 0.1
		target = null
		return
	target = entity
	nav_agent.target_desired_distance = 4
	time_since_last_path = path_update_rate

func on_velocity_computed(safe_velocity: Vector3) -> void:
	body.velocity = safe_velocity

func hit():
	if !is_alive:
		return
	is_alive = false
	mesh.dissolve_finished.connect(destroy)
	mesh.dissolve(body.global_position)

func destroy():
	queue_free()

func process_beat_event(event : BeatEvent, result : RuleSet.EventResult):
	super(event, result)
	if events.is_empty() && result != RuleSet.EventResult.MISSED:
		hit()
