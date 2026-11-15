@tool
extends Node
class_name EditorInit

func _ready() -> void:
	set_process(!Engine.is_editor_hint())

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		init_nodes()
	
func init_nodes():
	pass

# provides a button to re-init() whenever you have changes requiring new preview
func _get_property_list():
	return [{
		"name": "Init Action",
		"type": TYPE_CALLABLE,
		"hint": PROPERTY_HINT_TOOL_BUTTON,
		"hint_string": "Init",
	}]

func _get(property):
	if property == "Init Action":
		return Callable(self, "init_nodes")
	return null
