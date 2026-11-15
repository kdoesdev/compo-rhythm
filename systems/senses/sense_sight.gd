extends Area3D
class_name Sense_Sight

# Sees perceivalble entities.
# Has an inner radius to start perceving, and an outer radius for retaining perception

signal entity_sight_updated(entity : Node3D, can_see : bool)

class VisionStatus:
	var entity : Node3D = null
	var seen : bool = false
	static func create(new_entity : Node3D) -> VisionStatus:
		var vision_status := VisionStatus.new()
		vision_status.entity = new_entity
		return vision_status

@onready var inner : CollisionShape3D = $InnerRadius
@onready var outer : CollisionShape3D = $OuterRadius

@onready var visual_cone : VisualCone = $VisualCone

@onready var inner_shape : SphereShape3D = inner.shape as SphereShape3D
@onready var outer_shape : SphereShape3D = outer.shape as SphereShape3D

@export var fov : float = 60
@export var inner_radius : float = 5
@export var outer_radius : float = 10

@export var can_lose_sight : bool = true
@export var render : bool = true


@export_flags_3d_physics var sight_mask : int = 0

# entities in range that aren't necessarily detected
var detectable_entities : Dictionary[int, VisionStatus]

func _ready() -> void:
	visual_cone.construct_vision_field(fov, inner_radius)

func _process(_delta: float) -> void:
	if render:
		visual_cone.visible = true
		visual_cone.update_vision_field(fov, inner_radius)
		var cone_mesh : ShaderMaterial = visual_cone.material_override
		cone_mesh.set_shader_parameter("origin", Vector2(-global_position.x, global_position.z))
	else:
		visual_cone.visible = false
	
func _physics_process(_delta: float) -> void:
	for status in detectable_entities.values():
		var entity : Node3D = status.entity
		
		var forward := -global_transform.basis.z.normalized()
		var dir := (entity.global_transform.origin - global_transform.origin).normalized()
		var angle := acos(clamp(forward.dot(dir), -1.0, 1.0))
		
		var rad := deg_to_rad(fov/2)
		if angle >=  rad:
			if status.seen == true:
				status.seen = false
				entity_sight_updated.emit(entity, status.seen)
			continue
		
		
		var space := get_world_3d().direct_space_state
		
		var start = Vector3(global_position.x, entity.global_position.y, global_position.z)
		var end = entity.global_position
		var query = PhysicsRayQueryParameters3D.create(start, end, sight_mask, [self])
		
		var result := space.intersect_ray(query)
		
		if !result:
			DebugDraw3D.draw_arrow(start, end, Color.BLUE, 0.5, true)
			DebugDraw3D.draw_sphere(end, 0.5, Color.RED)
			if status.seen == true:
				status.seen = false
				entity_sight_updated.emit(entity, status.seen)
			continue
		
		if result.collider == entity:
			DebugDraw3D.draw_sphere(result.position, 0.5, Color.GREEN)
			if status.seen == false:
				status.seen = true
				entity_sight_updated.emit(entity, status.seen)
		else:
			if status.seen == true:
				status.seen = false
				entity_sight_updated.emit(entity, status.seen)
			DebugDraw3D.draw_sphere(result.position, 0.5, Color.RED)
		DebugDraw3D.draw_arrow(start, result.position, Color.BLUE, 0.5, true)

func body_entered(body: Node3D) -> void:
	detectable_entities[body.get_instance_id()] = VisionStatus.create(body)

func _on_body_shape_entered(_body_rid: RID, body: Node3D, _body_shape_index: int, local_shape_index: int) -> void:
	var local_shape_owner = shape_find_owner(local_shape_index)
	var local_shape_node : Node3D = shape_owner_get_owner(local_shape_owner)
	if local_shape_node == inner:
		detectable_entities[body.get_instance_id()] = VisionStatus.create(body)

func _on_body_shape_exited(_body_rid: RID, body: Node3D, _body_shape_index: int, local_shape_index: int) -> void:
	var local_shape_owner = shape_find_owner(local_shape_index)
	var local_shape_node : Node3D = shape_owner_get_owner(local_shape_owner)
	
	if !body:
		return
	
	var entity : VisionStatus = detectable_entities.get(body.get_instance_id())
	
	if !entity:
		assert(local_shape_node != inner, "entity left inner radius without having been a detectable entity!")
		return
		
	if local_shape_node == outer:
		entity_sight_updated.emit(entity.entity, false)
		detectable_entities.erase(body.get_instance_id())
