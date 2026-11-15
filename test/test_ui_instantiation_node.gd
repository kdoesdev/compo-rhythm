@tool
extends EditorInit

@export var start_node : Control = null
@export var node_count : int = 5
@export var size_range : Vector2 = Vector2(0, 150)

var prev_size : Vector2 = Vector2(0,0)
var current_offset : Vector2 = Vector2(0,0)

func init_nodes():

	current_offset = Vector2()
	prev_size = Vector2()
	
	# while transient, these nodes will linger while the scene is open, this is cosmetic cleanup
	if Engine.is_editor_hint():
		for child_node in start_node.get_children():
			child_node.name = "Empty"
			child_node.owner = null
			child_node.queue_free()
			pass
	
	# randomised ColorRects to visualise test
	for i in range(0, node_count ):
		var node := ColorRect.new()
		
		node.name = str(i)
		
		node.custom_minimum_size = Vector2(randf_range(size_range.x, size_range.y), randf_range(size_range.x, size_range.y))
		
		current_offset += prev_size
		node.position = current_offset

		node.color = Color(randf(), randf(), randf())
		
		prev_size = node.custom_minimum_size
		start_node.add_child(node)

		node.owner = EditorInterface.get_edited_scene_root()
